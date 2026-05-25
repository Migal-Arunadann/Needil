import 'dart:async';
import 'package:flutter/material.dart';
import '../../app.dart';
import '../constants/app_text_styles.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'session_timer_service.dart';

/// Singleton service that tracks idle time for consultations and sessions.
/// After 15 minutes of no interaction, fires an in-app dialog + notification.
///
/// For sessions: idle check is skipped if a timer is actively running.
class IdleReminderService {
  IdleReminderService._();
  static final IdleReminderService instance = IdleReminderService._();

  /// Map of id → last interaction timestamp
  final Map<String, DateTime> _lastInteraction = {};

  /// Map of id → type ('consultation' or 'session')
  final Map<String, String> _types = {};

  /// Map of id → display name
  final Map<String, String> _names = {};

  Timer? _pollingTimer;
  bool _dialogShowing = false;

  static const _idleThreshold = Duration(minutes: 15);
  static const _pollInterval = Duration(minutes: 1);

  /// Start tracking a consultation or session.
  void startTracking({
    required String id,
    required String type, // 'consultation' or 'session'
    required String displayName,
  }) {
    _lastInteraction[id] = DateTime.now();
    _types[id] = type;
    _names[id] = displayName;
    _ensurePolling();
  }

  /// Call this whenever the user interacts with the form (typing, tapping, etc.).
  void recordInteraction(String id) {
    if (_lastInteraction.containsKey(id)) {
      _lastInteraction[id] = DateTime.now();
    }
  }

  /// Stop tracking (on end/complete/navigate away).
  void stopTracking(String id) {
    _lastInteraction.remove(id);
    _types.remove(id);
    _names.remove(id);
    if (_lastInteraction.isEmpty) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  void _ensurePolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _checkIdle());
  }

  void _checkIdle() {
    if (_dialogShowing) return;
    final now = DateTime.now();

    for (final entry in _lastInteraction.entries) {
      final id = entry.key;
      final lastTime = entry.value;
      final type = _types[id] ?? 'session';
      final name = _names[id] ?? 'Patient';

      // Skip session idle check if timer is running
      if (type == 'session') {
        if (SessionTimerService.instance.hasActiveTimer(id)) continue;
      }

      if (now.difference(lastTime) >= _idleThreshold) {
        _showIdleReminder(id, type, name);
        break; // Show one at a time
      }
    }
  }

  void _showIdleReminder(String id, String type, String name) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;

    _dialogShowing = true;
    final typeLabel = type == 'consultation' ? 'Consultation' : 'Session';

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        title: Row(children: [
          Icon(Icons.timer_off_rounded, color: ctx.colors.warning, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text('$typeLabel Idle', style: ctx.textStyles.h4)),
        ]),
        content: Text(
          '$typeLabel for $name has been idle for 15+ minutes.\nResume activity or end it.',
          style: ctx.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _dialogShowing = false;
              // Reset the timer
              recordInteraction(id);
            },
            child: Text('Resume', style: TextStyle(color: ctx.colors.primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _dialogShowing = false;
            },
            child: Text('Dismiss', style: TextStyle(color: ctx.colors.textHint)),
          ),
        ],
      ),
    ).then((_) => _dialogShowing = false);
  }

  /// Clean up all tracking.
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastInteraction.clear();
    _types.clear();
    _names.clear();
  }
}
