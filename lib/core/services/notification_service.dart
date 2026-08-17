import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

/// Service to handle real-time push alerts via PocketBase WebSockets
/// and time-based local scheduled reminders (late alert, appointment reminder).
class NotificationService {
  final PocketBase _pb;
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  
  // Track active real-time subscription to prevent duplicates
  String? _subscribedClinicId;
  bool _isSubscribed = false;

  NotificationService(this._pb, this._ref);

  /// Resolves the patient's display name, looking up the patient record if needed.
  Future<String> _resolvePatientName(RecordModel record) async {
    final direct = record.getStringValue('patient_name').trim();
    if (direct.isNotEmpty) return direct;

    final patientId = record.getStringValue('patient').trim();
    if (patientId.isNotEmpty) {
      try {
        final patRec = await _pb.collection('patients').getOne(patientId);
        final patName = patRec.getStringValue('full_name').trim();
        if (patName.isNotEmpty) return patName;
      } catch (_) {}
    }
    return 'Patient';
  }

  /// Subscribes to real-time PocketBase appointment updates for the logged in clinic.
  Future<void> subscribeToRealtime(String clinicId, UserRole? role, String? doctorId) async {
    if (_isSubscribed && _subscribedClinicId == clinicId) return;

    // Clean up any existing subscription first
    await unsubscribeFromRealtime();

    _subscribedClinicId = clinicId;
    _isSubscribed = true;

    try {
      // Subscribe to all actions (*) on the appointments collection
      await _pb.collection('appointments').subscribe('*', (e) async {
        final record = e.record;
        if (record == null) return;

        // Verify the appointment belongs to the active clinic
        if (record.getStringValue('clinic') != clinicId) return;

        // Filter notifications for Doctor role (Doctors only see their own appointments)
        if (role == UserRole.doctor && doctorId != null) {
          if (record.getStringValue('doctor') != doctorId) return;
        }

        // Get user preferences
        final prefs = await SharedPreferences.getInstance();

        if (e.action == 'create') {
          // Schedule future late reminders and appointment reminders for the new booking
          await scheduleRemindersForAppointment(record, prefs);
        } else if (e.action == 'update') {
          final status = record.getStringValue('status');
          final type = record.getStringValue('type');
          final consultationEndTime = record.getStringValue('consultation_end_time');
          final checkInTime = record.getStringValue('check_in_time');
          final isSession = type == 'session' ||
              record.getStringValue('linked_session_id').isNotEmpty ||
              record.getStringValue('linked_treatment_plan_id').isNotEmpty;

          if (status == 'cancelled') {
            // Only send cancellation push alert for primary patient appointments (consultations/walk-ins/call-bys).
            // Do NOT spam push notifications when treatment plan sessions are released/paused/rescheduled.
            final notifyCancelled = prefs.getBool('notif_appointment_cancelled') ?? true;
            if (notifyCancelled && !isSession) {
              final patientName = await _resolvePatientName(record);
              await _showNotification(
                id: record.id.hashCode + 1,
                title: '❌ Appointment Cancelled',
                body: 'Patient: $patientName',
              );
            }
            // Cancel scheduled future alerts
            await cancelRemindersForAppointment(record.id);
          } else if (status == 'completed' || checkInTime.isNotEmpty || consultationEndTime.isNotEmpty) {
            // If checked in, completed, or consultation done, dismiss late reminders
            await cancelRemindersForAppointment(record.id);
          } else {
            // For other updates, re-schedule reminders with new details/times
            await scheduleRemindersForAppointment(record, prefs);
          }
        } else if (e.action == 'delete') {
          await cancelRemindersForAppointment(record.id);
        }
      });

      // Synchronize and schedule reminders for all upcoming appointments in today's list
      await scheduleFutureReminders(clinicId, role, doctorId);
    } catch (_) {}
  }

  /// Unsubscribes from the real-time PocketBase WebSocket endpoint.
  Future<void> unsubscribeFromRealtime() async {
    if (!_isSubscribed) return;
    try {
      await _pb.collection('appointments').unsubscribe('*');
    } catch (_) {}
    _isSubscribed = false;
    _subscribedClinicId = null;
  }

  /// Triggers a local OS push notification instantly.
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'clinic_notifications',
      'Clinic Alerts',
      channelDescription: 'Real-time booking and scheduling notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);
    try {
      await _fln.show(id, title, body, details);
    } catch (_) {}
  }

  /// Schedules time-sensitive reminders (Late Reminders and Appointment Reminders) for an appointment.
  Future<void> scheduleRemindersForAppointment(RecordModel record, SharedPreferences prefs) async {
    final status = record.getStringValue('status');
    final checkInTime = record.getStringValue('check_in_time');
    final dateStr = record.getStringValue('date');
    final timeStr = record.getStringValue('time');

    // Do not schedule if patient already checked in, checked out, or cancelled
    if (status == 'cancelled' || status == 'completed' || checkInTime.isNotEmpty) {
      await cancelRemindersForAppointment(record.id);
      return;
    }

    final parsedDateTime = DateTime.tryParse('$dateStr $timeStr');
    if (parsedDateTime == null) return;

    final patientName = await _resolvePatientName(record);

    const androidDetails = AndroidNotificationDetails(
      'scheduled_reminders',
      'Scheduled Reminders',
      channelDescription: 'Upcoming appointments and patient late alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    final now = DateTime.now();

    // ── 1. Patient Late Reminder ──
    final notifyLate = prefs.getBool('notif_patient_late') ?? true;
    if (notifyLate) {
      final lateMins = prefs.getInt('notif_late_mins') ?? 10;
      final lateTime = parsedDateTime.add(Duration(minutes: lateMins));
      final lateId = record.id.hashCode;

      // Cancel any pre-existing late reminder first
      try {
        await _fln.cancel(lateId);
      } catch (_) {}

      if (lateTime.isAfter(now)) {
        try {
          await _fln.zonedSchedule(
            lateId,
            '⏰ Patient is Late',
            'Patient $patientName has not arrived for their $timeStr appointment.',
            tz.TZDateTime.from(lateTime, tz.local),
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {}
      }
    }

    // ── 2. Upcoming Appointment Reminder ──
    final notifyReminder = prefs.getBool('notif_appointment_reminders') ?? true;
    if (notifyReminder) {
      // Remind 10 minutes before the appointment start
      final reminderTime = parsedDateTime.subtract(const Duration(minutes: 10));
      final reminderId = record.id.hashCode + 50000;

      // Cancel any pre-existing upcoming reminder first
      try {
        await _fln.cancel(reminderId);
      } catch (_) {}

      if (reminderTime.isAfter(now)) {
        try {
          await _fln.zonedSchedule(
            reminderId,
            '📅 Upcoming Appointment',
            'Appointment with $patientName starts in 10 minutes ($timeStr).',
            tz.TZDateTime.from(reminderTime, tz.local),
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {}
      }
    }
  }

  /// Cancels all scheduled notification alerts associated with an appointment.
  Future<void> cancelRemindersForAppointment(String appointmentId) async {
    final hash = appointmentId.hashCode;
    try {
      await _fln.cancel(hash);         // Late Alert ID
      await _fln.cancel(hash + 50000); // Upcoming Reminder ID
    } catch (_) {}
  }

  /// Loads all future appointments and schedules their local notifications locally.
  Future<void> scheduleFutureReminders(String clinicId, UserRole? role, String? doctorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Select future/today's pending appointments
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      String filter = 'clinic = "$clinicId" && date >= "$todayStr" && (status = "scheduled" || status = "waiting")';
      if (role == UserRole.doctor && doctorId != null) {
        filter += ' && doctor = "$doctorId"';
      }

      final result = await _pb.collection('appointments').getList(
        filter: filter,
        perPage: 100,
      );

      for (final record in result.items) {
        await scheduleRemindersForAppointment(record, prefs);
      }
    } catch (_) {}
  }
}

/// Provider to initialize and expose the notification service.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final pb = ref.watch(pocketbaseProvider);
  final service = NotificationService(pb, ref);

  // Setup auth state listener to trigger real-time connection lifecycle dynamically
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.isAuthenticated && next.clinicId != null) {
      service.subscribeToRealtime(next.clinicId!, next.role, next.doctor?.id);
    } else {
      service.unsubscribeFromRealtime();
    }
  });

  return service;
});
