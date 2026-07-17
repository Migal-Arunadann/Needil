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
  /// and marks them as `missed`. Also triggers auto-rescheduling for plans
  /// with fewer than 3 consecutive misses.
  ///
  /// Plans with 3+ misses are skipped here — they will surface in the
  /// Auto-Scheduling Dashboard via [getPendingMissedPlans].
  Future<void> checkAndMarkMissedSessions(String doctorId) async {
    final today = _formatDate(DateTime.now());

    try {
      // Find all sessions for this doctor that are unresolved but
      // whose scheduled_date is strictly in the past.
      final result = await pb.collection(PBCollections.sessions).getList(
        filter:
            'doctor = "$doctorId" && (status = "upcoming" || status = "waiting" || status = "in_progress") && scheduled_date < "$today"',
        sort: 'scheduled_date,session_number',
        perPage: 200,
      );

      if (result.items.isEmpty) return;

      // Group by treatment plan so we reschedule once per plan
      final Map<String, List<SessionModel>> byPlan = {};
      for (final rec in result.items) {
        final session = SessionModel.fromRecord(rec);
        byPlan.putIfAbsent(session.treatmentPlanId, () => []).add(session);
      }

      for (final entry in byPlan.entries) {
        final planId = entry.key;
        final staleSessions = entry.value;

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

        final missedSessions = <SessionModel>[];

        // Process each stale session
        for (final s in staleSessions) {
          if (s.status == SessionStatus.inProgress) {
            // Check if any data was saved for the session
            bool hasData = (s.notes != null && s.notes!.trim().isNotEmpty) ||
                (s.remarks != null && s.remarks!.trim().isNotEmpty) ||
                (s.bpLevel != null && s.bpLevel!.trim().isNotEmpty) ||
                (s.pulse != null && s.pulse! > 0) ||
                (s.photos.isNotEmpty);

            if (hasData) {
              // Auto-complete the session since work was done but user forgot to end it
              await pb.collection(PBCollections.sessions).update(
                s.id,
                body: {'status': 'completed'},
              );
              await _syncAppointmentStatus(s, 'completed');
              continue; // Do NOT add to missedSessions
            }
          }

          // Otherwise (upcoming, waiting, or in_progress with no data): Auto-miss
          await pb.collection(PBCollections.sessions).update(
            s.id,
            body: {'status': 'missed'},
          );
          await _syncAppointmentStatus(s, 'cancelled');
          missedSessions.add(s);
        }

        if (missedSessions.isEmpty) continue;

        // Increment consecutive miss count
        final newMissCount = plan.consecutiveMisses + missedSessions.length;
        await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
          'consecutive_misses': newMissCount,
        });

        // If 3+ consecutive misses, skip auto-rescheduling.
        // The Auto-Scheduling Dashboard will surface these plans via
        // getPendingMissedPlans().
        if (newMissCount >= 3) continue;

        // Auto-reschedule the missed session(s) and cascade subsequent ones
        // from today forward.
        await _autoRescheduleForPlan(
          planId,
          missedSessions,
          anchorDate: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[SessionLifecycle] checkAndMarkMissed error: $e');
    }
  }

  // ─── Auto-Rescheduling ────────────────────────────────────────────────────

  /// Reschedules missed sessions and cascades the shift to all subsequent
  /// upcoming sessions in the same plan, respecting:
  ///   – Doctor's working days
  ///   – Bed capacity (no double-booking)
  ///   – interval >= plan's original interval_days
  ///
  /// [anchorDate] sets the starting point for rescheduling. Defaults to
  /// the missed session's original date + 1 day.
  Future<void> _autoRescheduleForPlan(
    String planId,
    List<SessionModel> missedSessions, {
    DateTime? anchorDate,
  }) async {
    try {
      // Load plan
      final planRec =
          await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final plan = TreatmentPlanModel.fromRecord(planRec);

      // Load doctor info
      final docRec = await pb.collection('doctors').getOne(plan.doctorId);
      final doctor = DoctorModel.fromRecord(docRec);
      final validDays = doctor.workingDays;
      final clinicId = doctor.clinicId;

      // Bed capacity
      int maxBeds = 3;
      if (clinicId != null && clinicId.isNotEmpty) {
        try {
          final clinicRec =
              await pb.collection('clinics').getOne(clinicId);
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

      if (toReschedule.isEmpty) return;

      // Determine anchor: use provided date, or missed session's original date + 1 day
      DateTime cursor;
      if (anchorDate != null) {
        cursor = anchorDate;
      } else {
        final firstMissed = toReschedule.first;
        final originalDate = DateTime.parse(firstMissed.scheduledDate);
        cursor = originalDate.add(const Duration(days: 1));
      }

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

        // Update session record
        await pb.collection(PBCollections.sessions).update(session.id, body: {
          'scheduled_date': newDate,
          'scheduled_time': newTime,
          'is_rescheduled': true,
          'original_date': session.scheduledDate,
          // If it was missed, restore it to upcoming
          if (session.status == SessionStatus.missed) 'status': 'upcoming',
        });

        // Replace old linked appointment with a fresh one that has the
        // correct date, time, and clinic ID (fixes invisible session bug).
        await _replaceLinkedAppointment(
          session: session,
          newDate: newDate,
          newTime: newTime,
          clinicId: clinicId,
          sessionType: plan.treatmentType,
        );
      }
    } catch (e) {
      debugPrint('[SessionLifecycle] autoReschedule error: $e');
    }
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

  /// Sync a session's linked appointment to [newStatus].
  ///
  /// Uses plain `date = "YYYY-MM-DD"` (not a timestamp range) because the
  /// date field stores plain date strings, not datetimes. The old approach
  /// using `date >= "... 00:00:00.000Z"` was broken due to lexicographic
  /// comparison failures.
  Future<void> _syncAppointmentStatus(
      SessionModel session, String newStatus) async {
    try {
      // Normalise to YYYY-MM-DD
      String datePart = session.scheduledDate;
      try {
        final dt = DateTime.parse(session.scheduledDate);
        datePart = _formatDate(dt);
      } catch (_) {}

      final appts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "${session.patientId}" && doctor = "${session.doctorId}" '
            '&& date = "$datePart" && time = "${session.scheduledTime}" '
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

  /// Cancel the old linked appointment and create a fresh one with the
  /// correct date, time, and clinic ID.
  ///
  /// This is safer than updating the old record because:
  ///   1. The old record may already be `cancelled`
  ///   2. A fresh record always has the correct `clinic` field, ensuring
  ///      the appointment is visible to clinic-role users.
  Future<void> _replaceLinkedAppointment({
    required SessionModel session,
    required String newDate,
    required String newTime,
    required String? clinicId,
    required String sessionType,
  }) async {
    try {
      // Normalise old date to YYYY-MM-DD
      String oldDatePart = session.scheduledDate;
      try {
        final dt = DateTime.parse(session.scheduledDate);
        oldDatePart = _formatDate(dt);
      } catch (_) {}

      // Cancel the old appointment (regardless of current status)
      final oldAppts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "${session.patientId}" && doctor = "${session.doctorId}" '
            '&& date = "$oldDatePart" && time = "${session.scheduledTime}" '
            '&& type = "session"',
      );
      for (final appt in oldAppts.items) {
        await pb.collection(PBCollections.appointments).update(
          appt.id,
          body: {'status': 'cancelled'},
        );
      }

      // Create a fresh appointment with all required fields
      await pb.collection(PBCollections.appointments).create(body: {
        'patient': session.patientId,
        'doctor': session.doctorId,
        if (clinicId != null && clinicId.isNotEmpty) 'clinic': clinicId,
        'type': 'session',
        'date': newDate,
        'time': newTime,
        'status': 'scheduled',
        'session_type': sessionType,
      });
    } catch (e) {
      debugPrint('[SessionLifecycle] _replaceLinkedAppointment error: $e');
    }
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
  /// Rescheduling starts from today.
  Future<void> autoRescheduleForPlan(String planId) async {
    try {
      // Fetch all sessions for this plan with status = 'missed'
      final sessRes = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId" && status = "missed"',
        sort: 'session_number',
        perPage: 100,
      );

      final missedSessions = sessRes.items.map((r) => SessionModel.fromRecord(r)).toList();
      if (missedSessions.isEmpty) return;

      await _autoRescheduleForPlan(
        planId,
        missedSessions,
        anchorDate: DateTime.now(),
      );

      // Reset consecutive misses to 0 since we have rescheduled them
      await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
        'consecutive_misses': 0,
      });
    } catch (e) {
      debugPrint('[SessionLifecycle] autoRescheduleForPlan error: $e');
    }
  }

  /// Called by [TreatmentService.markSessionMissed] to reschedule a
  /// manually-missed session and cascade subsequent ones from today,
  /// when the plan has fewer than 3 consecutive misses.
  Future<void> rescheduleFromToday(String planId, List<SessionModel> missedSessions) async {
    await _autoRescheduleForPlan(
      planId,
      missedSessions,
      anchorDate: DateTime.now(),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _SlotResult {
  final DateTime date;
  final String time;
  _SlotResult({required this.date, required this.time});
}
