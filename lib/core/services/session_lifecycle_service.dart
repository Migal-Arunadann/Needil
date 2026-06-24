import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';

/// Handles automatic session lifecycle events:
///   – Auto-marking missed sessions the day after they were scheduled
///   – Auto-rescheduling missed sessions + cascading subsequent sessions
class SessionLifecycleService {
  final PocketBase pb;

  SessionLifecycleService(this.pb);

  // ─── Auto-Miss Detection ──────────────────────────────────────────────────

  /// Checks for any `upcoming` sessions whose scheduled_date < today
  /// and marks them as `missed`. Also triggers auto-rescheduling.
  ///
  /// Returns a list of human-readable summaries of rescheduled sessions
  /// so the caller can show a notification.
  /// 
  /// If a plan hits the 3-miss limit, the summary will contain a special
  /// entry starting with `PAUSE_PROMPT:` followed by the plan ID.
  Future<List<String>> checkAndMarkMissedSessions(String doctorId) async {
    final today = _formatDate(DateTime.now());
    final summaries = <String>[];

    try {
      // Find all sessions for this doctor that are still 'upcoming' but
      // whose scheduled_date is strictly in the past.
      final result = await pb.collection(PBCollections.sessions).getList(
        filter:
            'doctor = "$doctorId" && status = "upcoming" && scheduled_date < "$today"',
        sort: 'scheduled_date,session_number',
        perPage: 200,
      );

      if (result.items.isEmpty) return summaries;

      // Group by treatment plan so we reschedule once per plan
      final Map<String, List<SessionModel>> byPlan = {};
      for (final rec in result.items) {
        final session = SessionModel.fromRecord(rec);
        byPlan.putIfAbsent(session.treatmentPlanId, () => []).add(session);
      }

      for (final entry in byPlan.entries) {
        final planId = entry.key;
        final missedSessions = entry.value;

        // Load plan to check consecutive misses
        TreatmentPlanModel plan;
        try {
          final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
          plan = TreatmentPlanModel.fromRecord(planRec);
        } catch (_) {
          continue;
        }

        // Skip if plan is already paused
        if (plan.isPaused) continue;

        // Mark each as missed + update linked appointment
        for (final s in missedSessions) {
          await pb.collection(PBCollections.sessions).update(
            s.id,
            body: {'status': 'missed'},
          );
          await _syncAppointmentStatus(s, 'cancelled');
        }

        // Increment consecutive miss count
        final newMissCount = plan.consecutiveMisses + missedSessions.length;
        await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
          'consecutive_misses': newMissCount,
        });

        // If 3+ consecutive misses, signal pause prompt instead of rescheduling
        if (newMissCount >= 3) {
          // Fetch patient name for the prompt
          String patientName = 'Patient';
          try {
            final patRec = await pb.collection('patients').getOne(plan.patientId);
            patientName = patRec.getStringValue('full_name');
          } catch (_) {}
          summaries.add('PAUSE_PROMPT:$planId:$patientName:$newMissCount');
          continue;
        }

        // Auto-reschedule the missed session(s) and cascade subsequent ones
        final rescheduled = await _autoRescheduleForPlan(
          planId,
          missedSessions,
        );
        summaries.addAll(rescheduled);
      }
    } catch (e) {
      debugPrint('[SessionLifecycle] checkAndMarkMissed error: $e');
    }

    return summaries;
  }

  // ─── Auto-Rescheduling ────────────────────────────────────────────────────

  /// Reschedules missed sessions and cascades the shift to all subsequent
  /// upcoming sessions in the same plan, respecting:
  ///   – Doctor's working days
  ///   – Bed capacity (no double-booking)
  ///   – interval >= plan's original interval_days
  Future<List<String>> _autoRescheduleForPlan(
    String planId,
    List<SessionModel> missedSessions,
  ) async {
    final summaries = <String>[];

    try {
      // Load plan
      final planRec =
          await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final plan = TreatmentPlanModel.fromRecord(planRec);

      // Load doctor info
      final docRec = await pb.collection('doctors').getOne(plan.doctorId);
      final doctor = DoctorModel.fromRecord(docRec);
      final validDays = doctor.workingDays;

      // Bed capacity
      int maxBeds = 3;
      if (doctor.clinicId != null && doctor.clinicId!.isNotEmpty) {
        try {
          final clinicRec =
              await pb.collection('clinics').getOne(doctor.clinicId!);
          maxBeds = clinicRec.getIntValue('bed_count');
          if (maxBeds <= 0) maxBeds = 3;
        } catch (_) {}
      }

      // Load ALL sessions of this plan sorted by session_number
      final allRes = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId"',
        sort: 'session_number',
        perPage: 200,
      );
      final allSessions =
          allRes.items.map((r) => SessionModel.fromRecord(r)).toList();

      // Find the earliest missed session number
      final earliestMissedNum =
          missedSessions.map((s) => s.sessionNumber).reduce(
                (a, b) => a < b ? a : b,
              );

      // Determine the preferred time from the plan's first session
      String preferredTime = '10:00';
      for (final s in allSessions) {
        if (s.scheduledTime != null && s.scheduledTime!.isNotEmpty) {
          preferredTime = s.scheduledTime!;
          break;
        }
      }

      // Get sessions that need rescheduling:
      // - The missed session(s) themselves
      // - Any upcoming sessions with session_number >= earliestMissedNum
      final toReschedule = allSessions.where((s) {
        if (s.sessionNumber < earliestMissedNum) return false;
        return s.status == SessionStatus.missed ||
            s.status == SessionStatus.upcoming;
      }).toList()
        ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

      if (toReschedule.isEmpty) return summaries;

      // Calculate the anchor: the missed session's original date + 1 day
      final firstMissed = toReschedule.first;
      final originalDate = DateTime.parse(firstMissed.scheduledDate);
      DateTime cursor = originalDate.add(const Duration(days: 1));

      for (int i = 0; i < toReschedule.length; i++) {
        final session = toReschedule[i];

        if (i > 0) {
          // For subsequent sessions, advance cursor by the plan's interval
          cursor = cursor.add(Duration(days: plan.intervalDays));
        }

        // Skip to next working day
        cursor = _nextWorkingDay(cursor, validDays);

        // Find an available slot on that day
        final slotResult = await _findAvailableSlot(
          doctorId: plan.doctorId,
          startDate: cursor,
          preferredTime: preferredTime,
          maxBeds: maxBeds,
          validDays: validDays,
        );

        final newDate = _formatDate(slotResult.date);
        final newTime = slotResult.time;
        cursor = slotResult.date; // update cursor to actual scheduled date

        // Update session
        await pb.collection(PBCollections.sessions).update(session.id, body: {
          'scheduled_date': newDate,
          'scheduled_time': newTime,
          'is_rescheduled': true,
          'original_date': session.scheduledDate,
          // If it was missed, keep it missed. If upcoming, keep upcoming.
          if (session.status == SessionStatus.missed) 'status': 'upcoming',
        });

        // Update linked appointment
        await _updateLinkedAppointment(session, newDate, newTime);

        // Fetch patient name for summary
        String patientName = 'Patient';
        try {
          final patRec =
              await pb.collection('patients').getOne(session.patientId);
          patientName = patRec.getStringValue('full_name');
        } catch (_) {}

        summaries.add(
          'Session #${session.sessionNumber} for $patientName → $newDate at $newTime',
        );
      }
    } catch (e) {
      debugPrint('[SessionLifecycle] autoReschedule error: $e');
    }

    return summaries;
  }

  // ─── Slot Finding (reuses smart scheduling logic) ─────────────────────────

  /// Finds the next available slot starting from [startDate], respecting
  /// working days and bed capacity.
  Future<_SlotResult> _findAvailableSlot({
    required String doctorId,
    required DateTime startDate,
    required String preferredTime,
    required int maxBeds,
    required List<int> validDays,
  }) async {
    final timeParts = preferredTime.split(':');
    final pTimeHr = int.parse(timeParts[0]);
    final pTimeMn = int.parse(timeParts[1]);

    DateTime currentDate = startDate;
    int dayAttempts = 0;

    while (dayAttempts < 60) {
      // Skip non-working days
      if (validDays.isNotEmpty) {
        while (!validDays.contains(currentDate.weekday)) {
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }

      final dateStr = _formatDate(currentDate);
      DateTime slotAttempt = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        pTimeHr,
        pTimeMn,
      );

      // Try up to 16 time slots on this day
      for (int attempt = 0; attempt < 16; attempt++) {
        if (slotAttempt.hour >= 20) break;

        final checkTimeStr =
            '${slotAttempt.hour.toString().padLeft(2, "0")}:${slotAttempt.minute.toString().padLeft(2, "0")}';

        final existing = await pb.collection(PBCollections.appointments).getList(
          filter:
              'doctor = "$doctorId" && date = "$dateStr" && time = "$checkTimeStr" && status != "cancelled"',
        );

        if (existing.totalItems < maxBeds) {
          return _SlotResult(date: currentDate, time: checkTimeStr);
        }

        slotAttempt = slotAttempt.add(const Duration(minutes: 30));
      }

      currentDate = currentDate.add(const Duration(days: 1));
      dayAttempts++;
    }

    // Fallback: use the original date and preferred time
    return _SlotResult(date: startDate, time: preferredTime);
  }

  /// Advance [date] to the next working day (or return it if already valid).
  DateTime _nextWorkingDay(DateTime date, List<int> validDays) {
    if (validDays.isEmpty) return date;
    while (!validDays.contains(date.weekday)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  // ─── Appointment Helpers ──────────────────────────────────────────────────

  Future<void> _syncAppointmentStatus(
      SessionModel session, String newStatus) async {
    try {
      String datePart = session.scheduledDate;
      try {
        final dt = DateTime.parse(session.scheduledDate);
        datePart = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}

      final appts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "${session.patientId}" && doctor = "${session.doctorId}" '
            '&& date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z" && time = "${session.scheduledTime}" '
            '&& type = "session" && status != "cancelled"',
      );
      for (final appt in appts.items) {
        await pb.collection(PBCollections.appointments).update(
          appt.id,
          body: {'status': newStatus},
        );
      }
    } catch (_) {}
  }

  /// Update the linked appointment's date/time when a session is rescheduled.
  Future<void> _updateLinkedAppointment(
      SessionModel session, String newDate, String newTime) async {
    try {
      String datePart = session.scheduledDate;
      try {
        final dt = DateTime.parse(session.scheduledDate);
        datePart = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}

      final appts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "${session.patientId}" && doctor = "${session.doctorId}" '
            '&& date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z" && time = "${session.scheduledTime}" '
            '&& type = "session"',
      );
      for (final appt in appts.items) {
        await pb.collection(PBCollections.appointments).update(appt.id, body: {
          'date': newDate,
          'time': newTime,
          'status': 'scheduled',
        });
      }
    } catch (_) {}
  }

  /// Retrieves all active treatment plans that have 3+ consecutive misses
  /// and are not paused.
  Future<List<TreatmentPlanModel>> getPendingMissedPlans(String doctorIdOrClinicId, {bool isClinic = false}) async {
    try {
      String filter;
      if (isClinic) {
        final docs = await pb.collection('doctors').getList(
          filter: 'clinic = "$doctorIdOrClinicId"',
          perPage: 50,
        );
        if (docs.items.isEmpty) return [];
        final doctorFilter = docs.items.map((doc) => 'doctor = "${doc.id}"').join(' || ');
        filter = '($doctorFilter) && consecutive_misses >= 3 && is_paused = false && status = "active"';
      } else {
        filter = 'doctor = "$doctorIdOrClinicId" && consecutive_misses >= 3 && is_paused = false && status = "active"';
      }

      final result = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: filter,
        expand: 'patient,doctor',
        perPage: 100,
      );

      return result.items.map((r) => TreatmentPlanModel.fromRecord(r)).toList();
    } catch (e) {
      debugPrint('[SessionLifecycle] getPendingMissedPlans error: $e');
      return [];
    }
  }

  /// Public entry point to explicitly run auto-rescheduling for a plan
  /// that was held back due to hitting the miss limit.
  Future<List<String>> autoRescheduleForPlan(String planId) async {
    try {
      // Fetch all sessions for this plan with status = 'missed'
      final sessRes = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId" && status = "missed"',
        sort: 'session_number',
        perPage: 100,
      );

      final missedSessions = sessRes.items.map((r) => SessionModel.fromRecord(r)).toList();
      if (missedSessions.isEmpty) return [];

      final results = await _autoRescheduleForPlan(planId, missedSessions);

      // Reset consecutive misses to 0 since we have rescheduled them
      await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
        'consecutive_misses': 0,
      });

      return results;
    } catch (e) {
      debugPrint('[SessionLifecycle] autoRescheduleForPlan error: $e');
      return [];
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _SlotResult {
  final DateTime date;
  final String time;
  _SlotResult({required this.date, required this.time});
}
