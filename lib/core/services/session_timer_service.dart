import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../app.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'package:pms_app/core/theme/app_theme.dart';

// ── Public snapshot for external consumers ────────────────────────────────────

class TimerLogEntry {
  final int setForMinutes;       // original duration
  final DateTime startedAt;       // when timer was started
  final DateTime? stoppedAt;      // when it was stopped/paused/finished
  final int elapsedSeconds;       // how many seconds ran before stop
  final String outcome;           // 'running', 'completed', 'paused', 'reset', 'cancelled'

  TimerLogEntry({
    required this.setForMinutes,
    required this.startedAt,
    this.stoppedAt,
    required this.elapsedSeconds,
    required this.outcome,
  });

  Map<String, dynamic> toJson() => {
    'setForMinutes': setForMinutes,
    'startedAt': startedAt.toIso8601String(),
    'stoppedAt': stoppedAt?.toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
    'outcome': outcome,
  };

  factory TimerLogEntry.fromJson(Map<String, dynamic> json) => TimerLogEntry(
    setForMinutes: json['setForMinutes'] as int,
    startedAt: DateTime.parse(json['startedAt'] as String),
    stoppedAt: json['stoppedAt'] != null ? DateTime.parse(json['stoppedAt'] as String) : null,
    elapsedSeconds: json['elapsedSeconds'] as int,
    outcome: json['outcome'] as String,
  );
}

/// Read-only snapshot of a timer's state, safe to use from other files.
class TimerSnapshot {
  final String sessionId;
  final String patientName;
  final int remainingSeconds;
  final int totalSeconds;
  final bool isPaused;
  final bool isActive;
  final bool isRunning;
  final List<TimerLogEntry> timerHistory;
  const TimerSnapshot({
    required this.sessionId,
    required this.patientName,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.isPaused,
    required this.isActive,
    required this.isRunning,
    required this.timerHistory,
  });
}

// ── Per-session timer entry ────────────────────────────────────────────────────

class _TimerEntry {
  final String sessionId;
  final String patientName;
  /// Stored so notification tap can navigate directly back to the session.
  final Map<String, dynamic>? routeArgs;
  final int notificationId;

  int remainingSeconds;
  int totalSeconds;
  bool isPaused;
  Timer? ticker;
  final List<TimerLogEntry> timerHistory;

  final List<VoidCallback> _listeners = [];

  _TimerEntry({
    required this.sessionId,
    required this.patientName,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.notificationId,
    this.routeArgs,
    this.isPaused = false,
    List<TimerLogEntry>? timerHistory,
  }) : this.timerHistory = timerHistory ?? [];

  bool get isRunning => ticker != null && ticker!.isActive && !isPaused;
  bool get isActive  => isRunning || (isPaused && remainingSeconds > 0);
  bool get isFinished => remainingSeconds == 0 && !isRunning && !isPaused;

  double get progress =>
      totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

  int get minutesRemaining => (remainingSeconds / 60).ceil();

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  void _notify() {
    for (final cb in List<VoidCallback>.from(_listeners)) {
      cb();
    }
    // Also notify global listeners so schedule cards update
    for (final cb in List<VoidCallback>.from(SessionTimerService.instance._globalListeners)) {
      cb();
    }
  }

  Map<String, dynamic> toJson(int savedAtEpoch) {
    return {
      'sessionId': sessionId,
      'patientName': patientName,
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'notificationId': notificationId,
      'isPaused': isPaused,
      'routeArgs': routeArgs,
      'savedAtEpoch': savedAtEpoch,
      'timerHistory': timerHistory.map((e) => e.toJson()).toList(),
    };
  }

  static _TimerEntry? fromJson(Map<String, dynamic> json, int currentEpoch) {
    final sessionId = json['sessionId'] as String?;
    final patientName = json['patientName'] as String?;
    final remainingSecondsVal = json['remainingSeconds'] as int?;
    final totalSeconds = json['totalSeconds'] as int?;
    final notificationId = json['notificationId'] as int?;
    final isPaused = json['isPaused'] as bool? ?? false;
    final savedAtEpoch = json['savedAtEpoch'] as int?;
    final routeArgs = json['routeArgs'] as Map<String, dynamic>?;
    final historyList = json['timerHistory'] as List?;
    final history = historyList != null
        ? historyList.map((e) => TimerLogEntry.fromJson(e as Map<String, dynamic>)).toList()
        : <TimerLogEntry>[];

    if (sessionId == null || patientName == null || remainingSecondsVal == null || totalSeconds == null || notificationId == null || savedAtEpoch == null) {
      return null;
    }

    int remainingSeconds = remainingSecondsVal;
    if (!isPaused) {
      final elapsedSeconds = ((currentEpoch - savedAtEpoch) / 1000).floor();
      remainingSeconds = remainingSecondsVal - elapsedSeconds;
      if (remainingSeconds < 0) {
        remainingSeconds = 0;
      }
    }

    return _TimerEntry(
      sessionId: sessionId,
      patientName: patientName,
      remainingSeconds: remainingSeconds,
      totalSeconds: totalSeconds,
      notificationId: notificationId,
      routeArgs: routeArgs,
      isPaused: isPaused,
      timerHistory: history,
    );
  }
}

// ── Multi-session timer service ───────────────────────────────────────────────

/// Manages multiple independent session countdowns simultaneously.
/// Each session identified by [sessionId] gets its own:
///   - Dart [Timer] (survives page navigation)
///   - Persistent OS notification with live minutes-remaining count
///   - On finish: 5-second vibration alarm + alarm notification + in-app dialog
class SessionTimerService {
  SessionTimerService._();
  static final SessionTimerService instance = SessionTimerService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  final Map<String, _TimerEntry> _timers = {};
  /// Listeners registered before a timer entry exists.
  final Map<String, List<VoidCallback>> _pendingListeners = {};
  /// Global listeners — fire on ANY timer change (for schedule card countdown).
  final List<VoidCallback> _globalListeners = [];
  int _nextNotifId = 200;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> initNotifications(InitializationSettings settings) async {
    if (!kIsWeb) {
      try {
        await _fln.initialize(
          settings,
          onDidReceiveNotificationResponse: _onNotificationTap,
        );
        await _fln
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
    }

    // Restore persistent timers from disk
    await loadTimersFromPrefs();
  }

  void _onNotificationTap(NotificationResponse response) {
    final sessionId = response.payload;
    if (sessionId == null) return;
    final entry = _timers[sessionId];
    if (entry == null) return;
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    if (entry.routeArgs != null) {
      Navigator.of(ctx).pushNamed('/sessions/record', arguments: entry.routeArgs);
    }
  }

  // ── Persistence Helpers ─────────────────────────────────────────────────────

  Future<void> _saveTimersToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentEpoch = DateTime.now().millisecondsSinceEpoch;
      final list = _timers.values.map((t) => t.toJson(currentEpoch)).toList();
      await prefs.setString('active_session_timers', jsonEncode(list));
    } catch (_) {}
  }

  Future<void> loadTimersFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timersJsonStr = prefs.getString('active_session_timers');
      if (timersJsonStr == null || timersJsonStr.isEmpty) return;

      final List<dynamic> list = jsonDecode(timersJsonStr);
      final currentEpoch = DateTime.now().millisecondsSinceEpoch;

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final entry = _TimerEntry.fromJson(item, currentEpoch);
        if (entry == null) continue;

        // Restore pending listeners
        if (_pendingListeners.containsKey(entry.sessionId)) {
          for (final cb in _pendingListeners[entry.sessionId]!) {
            entry.addListener(cb);
          }
          _pendingListeners.remove(entry.sessionId);
        }

        // Skip completed timers — they already fired their alarm
        if (entry.remainingSeconds == 0) continue;

        _timers[entry.sessionId] = entry;

        if (!entry.isPaused) {
          _startTick(entry);
          _postCountdownNotification(entry);
        } else {
          _postCountdownNotification(entry);
        }
      }
    } catch (_) {}
  }

  // ── Public controls ─────────────────────────────────────────────────────────

  /// Start (or restart) a countdown for [sessionId].
  void start({
    required String sessionId,
    required String patientName,
    required int minutes,
    Map<String, dynamic>? routeArgs,
  }) {
    // Save existing listeners + history before cancelling
    final oldListeners = <VoidCallback>[];
    final oldHistory = <TimerLogEntry>[];
    if (_timers.containsKey(sessionId)) {
      oldListeners.addAll(_timers[sessionId]!._listeners);
      oldHistory.addAll(_timers[sessionId]!.timerHistory);
    }

    _cancelEntry(sessionId, removeFromMap: false);

    final notifId = _nextNotifId++;
    final entry = _TimerEntry(
      sessionId: sessionId,
      patientName: patientName,
      remainingSeconds: minutes * 60,
      totalSeconds: minutes * 60,
      notificationId: notifId,
      routeArgs: routeArgs,
      timerHistory: oldHistory,
    );

    // Restore old listeners + pending listeners
    for (final cb in oldListeners) {
      entry.addListener(cb);
    }
    if (_pendingListeners.containsKey(sessionId)) {
      for (final cb in _pendingListeners[sessionId]!) {
        entry.addListener(cb);
      }
      _pendingListeners.remove(sessionId);
    }

    // Add run segment log entry
    entry.timerHistory.add(TimerLogEntry(
      setForMinutes: minutes,
      startedAt: DateTime.now(),
      elapsedSeconds: 0,
      outcome: 'running',
    ));

    _timers[sessionId] = entry;
    _postCountdownNotification(entry);
    _startTick(entry);
    entry._notify(); // Immediately notify so UI updates
    _saveTimersToPrefs();
  }

  void pause(String sessionId) {
    final entry = _timers[sessionId];
    if (entry == null || !entry.isRunning) return;
    entry.isPaused = true;
    entry.ticker?.cancel();
    entry.ticker = null;

    // Update the last log entry
    if (entry.timerHistory.isNotEmpty) {
      final last = entry.timerHistory.last;
      if (last.outcome == 'running') {
        final now = DateTime.now();
        final elapsed = now.difference(last.startedAt).inSeconds;
        entry.timerHistory[entry.timerHistory.length - 1] = TimerLogEntry(
          setForMinutes: last.setForMinutes,
          startedAt: last.startedAt,
          stoppedAt: now,
          elapsedSeconds: elapsed,
          outcome: 'paused',
        );
      }
    }

    _postCountdownNotification(entry); // update badge to show "(Paused)"
    entry._notify();
    _saveTimersToPrefs();
  }

  void resume(String sessionId) {
    final entry = _timers[sessionId];
    if (entry == null || !entry.isPaused || entry.remainingSeconds <= 0) return;
    entry.isPaused = false;

    // Add a new log entry for resumption
    entry.timerHistory.add(TimerLogEntry(
      setForMinutes: entry.totalSeconds ~/ 60,
      startedAt: DateTime.now(),
      elapsedSeconds: 0,
      outcome: 'running',
    ));

    _postCountdownNotification(entry);
    _startTick(entry);
    entry._notify();
    _saveTimersToPrefs();
  }

  void reset(String sessionId) {
    final entry = _timers[sessionId];
    if (entry != null) {
      // Update last running/paused log entry to 'reset'
      if (entry.timerHistory.isNotEmpty) {
        final last = entry.timerHistory.last;
        if (last.outcome == 'running' || last.outcome == 'paused') {
          final now = DateTime.now();
          final elapsed = last.outcome == 'running'
              ? now.difference(last.startedAt).inSeconds
              : last.elapsedSeconds;
          entry.timerHistory[entry.timerHistory.length - 1] = TimerLogEntry(
            setForMinutes: last.setForMinutes,
            startedAt: last.startedAt,
            stoppedAt: now,
            elapsedSeconds: elapsed,
            outcome: 'reset',
          );
        }
      }
      // Keep listeners, notify them, then clean up
      final listeners = List<VoidCallback>.from(entry._listeners);
      entry.ticker?.cancel();
      entry.ticker = null;
      _cancelNotification(entry.notificationId);
      _cancelNotification(entry.notificationId + 1000);
      _timers.remove(sessionId);
      // Notify all listeners so UI refreshes to "no timer" state
      for (final cb in listeners) {
        cb();
      }
      // Move listeners back to pending so they're re-attached on next start()
      _pendingListeners[sessionId] = listeners;
      _saveTimersToPrefs();
    }
  }

  /// End the timer at its current position — logs elapsed time with outcome 'ended'
  /// and removes the timer (similar to reset, but preserves the log as 'ended').
  void endTimer(String sessionId) {
    final entry = _timers[sessionId];
    if (entry == null) return;

    // Update the last log entry to 'ended'
    if (entry.timerHistory.isNotEmpty) {
      final last = entry.timerHistory.last;
      if (last.outcome == 'running' || last.outcome == 'paused') {
        final now = DateTime.now();
        final elapsed = last.outcome == 'running'
            ? now.difference(last.startedAt).inSeconds
            : last.elapsedSeconds;
        entry.timerHistory[entry.timerHistory.length - 1] = TimerLogEntry(
          setForMinutes: last.setForMinutes,
          startedAt: last.startedAt,
          stoppedAt: now,
          elapsedSeconds: elapsed,
          outcome: 'ended',
        );
      }
    }

    // Keep listeners, notify them, then clean up
    final listeners = List<VoidCallback>.from(entry._listeners);
    entry.ticker?.cancel();
    entry.ticker = null;
    _cancelNotification(entry.notificationId);
    _cancelNotification(entry.notificationId + 1000);
    _timers.remove(sessionId);
    // Notify all listeners so UI refreshes
    for (final cb in listeners) {
      cb();
    }
    // Move listeners back to pending so they're re-attached on next start()
    _pendingListeners[sessionId] = listeners;
    _saveTimersToPrefs();
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  _TimerEntry? getEntry(String sessionId) => _timers[sessionId];
  bool hasActiveTimer(String sessionId) => _timers[sessionId]?.isActive ?? false;

  void addListener(String sessionId, VoidCallback cb) {
    final entry = _timers[sessionId];
    if (entry != null) {
      entry.addListener(cb);
    } else {
      // Entry doesn't exist yet — save as pending
      _pendingListeners.putIfAbsent(sessionId, () => []).add(cb);
    }
  }

  void removeListener(String sessionId, VoidCallback cb) {
    _timers[sessionId]?.removeListener(cb);
    _pendingListeners[sessionId]?.remove(cb);
  }

  /// Find an active timer entry by patient name (for schedule card display).
  TimerSnapshot? getActiveTimerByPatientName(String patientName) {
    for (final entry in _timers.values) {
      if (entry.patientName == patientName && entry.isActive) {
        return TimerSnapshot(
          sessionId: entry.sessionId,
          patientName: entry.patientName,
          remainingSeconds: entry.remainingSeconds,
          totalSeconds: entry.totalSeconds,
          isPaused: entry.isPaused,
          isActive: entry.isActive,
          isRunning: entry.isRunning,
          timerHistory: entry.timerHistory,
        );
      }
    }
    return null;
  }

  /// Register a listener that fires on ANY timer change.
  void addGlobalListener(VoidCallback cb) => _globalListeners.add(cb);
  void removeGlobalListener(VoidCallback cb) => _globalListeners.remove(cb);

  // ── Internal ────────────────────────────────────────────────────────────────

  void _startTick(_TimerEntry entry) {
    entry.ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (entry.remainingSeconds <= 1) {
        entry.remainingSeconds = 0;
        entry.ticker?.cancel();
        entry.ticker = null;
        entry.isPaused = false;
        entry._notify();
        _saveTimersToPrefs();
        _onFinished(entry);
      } else {
        entry.remainingSeconds--;
        // Refresh notification every full minute
        if (entry.remainingSeconds % 60 == 0) {
          _postCountdownNotification(entry);
        }
        // Save state every 10 seconds to avoid excessive writes
        if (entry.remainingSeconds % 10 == 0) {
          _saveTimersToPrefs();
        }
        entry._notify();
      }
    });
  }

  void _cancelEntry(String sessionId, {required bool removeFromMap}) {
    final entry = _timers[sessionId];
    if (entry != null) {
      if (entry.timerHistory.isNotEmpty) {
        final last = entry.timerHistory.last;
        if (last.outcome == 'running' || last.outcome == 'paused') {
          final now = DateTime.now();
          final elapsed = last.outcome == 'running'
              ? now.difference(last.startedAt).inSeconds
              : last.elapsedSeconds;
          entry.timerHistory[entry.timerHistory.length - 1] = TimerLogEntry(
            setForMinutes: last.setForMinutes,
            startedAt: last.startedAt,
            stoppedAt: now,
            elapsedSeconds: elapsed,
            outcome: 'cancelled',
          );
        }
      }
      entry.ticker?.cancel();
      entry.ticker = null;
      _cancelNotification(entry.notificationId);
      _cancelNotification(entry.notificationId + 1000);
    }
    if (removeFromMap) {
      _timers.remove(sessionId);
      _saveTimersToPrefs();
    }
  }

  void _onFinished(_TimerEntry entry) {
    // Update last running/paused log entry to 'completed'
    if (entry.timerHistory.isNotEmpty) {
      final last = entry.timerHistory.last;
      if (last.outcome == 'running' || last.outcome == 'paused') {
        final now = DateTime.now();
        final elapsed = last.outcome == 'running'
            ? now.difference(last.startedAt).inSeconds
            : last.elapsedSeconds;
        entry.timerHistory[entry.timerHistory.length - 1] = TimerLogEntry(
          setForMinutes: last.setForMinutes,
          startedAt: last.startedAt,
          stoppedAt: now,
          elapsedSeconds: elapsed,
          outcome: 'completed',
        );
      }
    }
    _cancelNotification(entry.notificationId);
    _postAlarmNotification(entry);
    _showInAppAlarm(entry);
    _playAlarmVibration();
    _playAlarmSound();

    // Clean up finished timer so it doesn't re-fire on next app open
    _timers.remove(entry.sessionId);
    _saveTimersToPrefs();
  }

  // ── In-app alarm dialog ─────────────────────────────────────────────────────

  void _showInAppAlarm(_TimerEntry entry) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _TimerAlertDialog(
        patientName: entry.patientName,
        sessionId: entry.sessionId,
        routeArgs: entry.routeArgs,
      ),
    );
  }

  /// Plays 5 rapid vibration pulses — the "5-second alarm" effect.
  void _playAlarmVibration() async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      for (int i = 0; i < 5; i++) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 900));
      }
    } catch (_) {}
  }

  /// Plays the timer-ended sound from assets.
  Future<void> _playAlarmSound() async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('audio/timer ended sound.mpeg'));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {
      // Sound failure is non-critical
    }
  }

  // ── Notifications ───────────────────────────────────────────────────────────

  /// Shows/updates the persistent countdown notification for this entry.
  void _postCountdownNotification(_TimerEntry entry) async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      final mins = entry.minutesRemaining;
      final label = entry.isPaused
          ? '⏸ ${entry.patientName} — ${mins}min (Paused)'
          : '⏱ ${entry.patientName} — ${mins}min remaining';

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'session_timer',
          'Session Timer',
          channelDescription: 'Live countdown for active session timers',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,       // Cannot be swiped away by user
          autoCancel: false,   // Does NOT dismiss when tapped
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          showWhen: false,
          category: AndroidNotificationCategory.service,
        ),
      );

      await _fln.show(
        entry.notificationId,
        label,
        'Tap to return to session',
        details,
        payload: entry.sessionId,
      );
    } catch (_) {}
  }

  /// Shows the alarm notification when a timer finishes.
  void _postAlarmNotification(_TimerEntry entry) async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'session_alarm',
          'Session Alarm',
          channelDescription: 'Alarm when a session timer completes',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(
              [0, 600, 200, 600, 200, 600, 200, 600, 200, 600]),
          autoCancel: true,
          category: AndroidNotificationCategory.alarm,
        ),
      );

      await _fln.show(
        entry.notificationId + 1000,
        '⏰ Time is up!',
        'Session timer finished for ${entry.patientName}',
        details,
        payload: entry.sessionId,
      );
    } catch (_) {}
  }

  Future<void> _cancelNotification(int id) async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      await _fln.cancel(id);
    } catch (_) {}
  }
}

// ── In-app alarm dialog ───────────────────────────────────────────────────────

class _TimerAlertDialog extends StatefulWidget {
  final String patientName;
  final String sessionId;
  final Map<String, dynamic>? routeArgs;
  const _TimerAlertDialog({required this.patientName, required this.sessionId, this.routeArgs});

  @override
  State<_TimerAlertDialog> createState() => _TimerAlertDialogState();
}

class _TimerAlertDialogState extends State<_TimerAlertDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _alarmTimer;
  int _alarmCount = 0;
  int _snoozeMinutes = 5; // default snooze

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // Play system alert sound 5 times over 5 seconds
    _alarmTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_alarmCount >= 5) {
        t.cancel();
        return;
      }
      SystemSound.play(SystemSoundType.alert);
      _alarmCount++;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _alarmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: context.colors.surface,
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(
              scale: 1.0 + _pulse.value * 0.15,
              child: child,
            ),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: context.colors.error.withValues(alpha: 0.5), width: 2.5),
              ),
              child: Icon(Icons.alarm_rounded,
                  size: 38, color: context.colors.error),
            ),
          ),
          const SizedBox(height: 18),
          Text('Time\'s Up!',
              style: context.textStyles.h3.copyWith(color: context.colors.error),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: context.textStyles.bodyMedium
                  .copyWith(color: context.colors.textSecondary),
              children: [
                const TextSpan(text: 'Time is up for patient :\n'),
                TextSpan(
                  text: widget.patientName,
                  style: context.textStyles.h4
                      .copyWith(color: context.colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Snooze row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _snoozeMinutes,
                  isDense: true,
                  style: context.textStyles.caption.copyWith(color: context.colors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2m')),
                    DropdownMenuItem(value: 5, child: Text('5m')),
                    DropdownMenuItem(value: 10, child: Text('10m')),
                  ],
                  onChanged: (v) => setState(() => _snoozeMinutes = v ?? 5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                SessionTimerService.instance.start(
                  sessionId: widget.sessionId,
                  patientName: widget.patientName,
                  minutes: _snoozeMinutes,
                  routeArgs: widget.routeArgs,
                );
              },
              icon: Icon(Icons.snooze_rounded, size: 16, color: context.colors.warning),
              label: Text('Snooze',
                  style: TextStyle(color: context.colors.warning, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            SessionTimerService.instance.reset(widget.sessionId);
            Navigator.of(context).pop();
          },
          child: Text('Dismiss',
              style: TextStyle(
                  color: context.colors.error, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}