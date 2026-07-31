import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/scheduling/appointment_sync.dart';
import 'package:pms_app/core/scheduling/audit_logger.dart';
import 'package:pms_app/core/scheduling/missed_session_detector.dart';
import 'package:pms_app/core/scheduling/slot_finder.dart';
import 'package:pms_app/core/scheduling/treatment_lifecycle.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/core/constants/pb_collections.dart';

/// Backward-compatible facade over the v2 scheduling engine.
///
/// All existing call sites continue to work unchanged. Internally, all work
/// is delegated to the correct v2 component.
///
/// Component wiring happens in this constructor — shared instances ensure
/// the same [AuditLogger] and [TreatmentLifecycle] are used everywhere.
class SessionLifecycleService {
  late final MissedSessionDetector _detector;
  late final TreatmentScheduler _scheduler;
  late final TreatmentLifecycle _lifecycle;
  late final AuditLogger _auditLogger;
  late final AppointmentSync _appointmentSync;
  final PocketBase _pb;

  SessionLifecycleService(PocketBase pb) : _pb = pb {
    _auditLogger = AuditLogger(pb);
    _lifecycle = TreatmentLifecycle(pb);
    _appointmentSync = AppointmentSync(pb);
    final slotFinder = SlotFinder(pb);
    final contextLoader = SchedulingContextLoader(pb);
    _scheduler = TreatmentScheduler(
      pb,
      slotFinder,
      contextLoader,
      _appointmentSync,
      _lifecycle,
      _auditLogger,
    );
    _detector = MissedSessionDetector(
      pb,
      _lifecycle,
      _auditLogger,
    );
  }

  // ─── Overdue Session Sweep ────────────────────────────────────────────────

  /// Sweep past-due sessions and flag them as [overdue].
  ///
  /// Replaces the old checkAndMarkMissedSessions — now safe: no session is
  /// marked missed or rescheduled without explicit human confirmation.
  Future<int> flagOverdueSessions(String doctorId) =>
      _detector.detectAndProcess(doctorId);

  /// Legacy alias kept for backward compat — routes to [flagOverdueSessions].
  Future<int> checkAndMarkMissedSessions(String doctorId) =>
      flagOverdueSessions(doctorId);

  // ─── Overdue Session Queries ───────────────────────────────────────────────

  /// Load all [overdue] sessions for a doctor, sorted by scheduled_date.
  Future<List<SessionModel>> getOverdueSessions(String doctorId) async {
    try {
      final result = await _pb.collection(PBCollections.sessions).getFullList(
        filter: 'doctor = "$doctorId" && status = "overdue"',
        sort: 'scheduled_date,session_number',
        expand: 'patient,treatment_plan',
      );
      return result.map((r) => SessionModel.fromRecord(r)).toList();
    } catch (e) {
      debugPrint('[SessionLifecycleService] getOverdueSessions error: $e');
      return [];
    }
  }

  /// Load all [overdue] sessions for all doctors in a clinic.
  /// Batches in groups of 20 to avoid PocketBase filter string overflow.
  Future<List<SessionModel>> getOverdueSessionsForClinic(String clinicId) async {
    try {
      // Fetch all doctor IDs in the clinic
      final doctors = await _pb.collection('doctors').getFullList(
        filter: 'clinic = "$clinicId"',
        fields: 'id',
      );
      if (doctors.isEmpty) return [];

      // Chunk into groups of 20 to keep filter strings within PocketBase limits
      const chunkSize = 20;
      final allSessions = <SessionModel>[];

      for (var i = 0; i < doctors.length; i += chunkSize) {
        final chunk = doctors.sublist(
          i,
          (i + chunkSize).clamp(0, doctors.length),
        );
        final orFilter = chunk.map((d) => 'doctor = "${d.id}"').join(' || ');

        final result = await _pb.collection(PBCollections.sessions).getFullList(
          filter: '($orFilter) && status = "overdue"',
          sort: 'scheduled_date,session_number',
          expand: 'patient,treatment_plan',
        );
        allSessions.addAll(result.map((r) => SessionModel.fromRecord(r)));
      }

      // Re-sort the merged results
      allSessions.sort((a, b) {
        final dateComp = a.scheduledDate.compareTo(b.scheduledDate);
        if (dateComp != 0) return dateComp;
        return (a.sessionNumber ?? 0).compareTo(b.sessionNumber ?? 0);
      });

      return allSessions;
    } catch (e) {
      debugPrint('[SessionLifecycleService] getOverdueSessionsForClinic error: $e');
      return [];
    }
  }

  // ─── Human Confirmation Actions ───────────────────────────────────────────

  /// Human confirms: patient came but doctor forgot to record.
  ///
  /// Sets status → completed using the session's original scheduled date,
  /// resets consecutive_misses, increments completed_sessions.
  /// Returns the updated [SessionModel] for the UI to navigate to the form.
  Future<void> confirmSessionCompleted(
    String sessionId,
    String planId, {
    required String performedBy,
  }) async {
    final sessionRec = await _pb.collection(PBCollections.sessions).getOne(sessionId);
    final session = SessionModel.fromRecord(sessionRec);

    // Use the original scheduled date as completed_at — not today
    final originalDt = DateTime.tryParse(session.scheduledDate);
    final completedAt = originalDt != null
        ? originalDt.toUtc().toIso8601String()
        : DateTime.now().toUtc().toIso8601String();

    await _pb.collection(PBCollections.sessions).update(sessionId, body: {
      'status': 'completed',
      'completed_at': completedAt,
    });

    await _appointmentSync.syncStatus(session, 'completed');
    await _lifecycle.onSessionCompleted(planId);

    await _auditLogger.log(
      sessionId: sessionId,
      planId: planId,
      action: 'retroactively_completed',
      oldDate: session.scheduledDate,
      reason: 'Confirmed by $performedBy — patient attended but was not recorded',
      trigger: 'doctor_manual',
      performedBy: performedBy,
      scheduleVersion: await _currentVersion(planId),
    );
  }

  /// Human confirms: patient genuinely did not show up.
  ///
  /// Sets status → missed, increments consecutive_misses.
  /// Returns the new consecutive_misses count so caller can handle ≥3.
  Future<int> confirmSessionMissed(
    String sessionId,
    String planId, {
    required String performedBy,
  }) async {
    final sessionRec = await _pb.collection(PBCollections.sessions).getOne(sessionId);
    final session = SessionModel.fromRecord(sessionRec);

    final scheduledDt = DateTime.tryParse(session.scheduledDate);
    final missedAt = scheduledDt != null
        ? scheduledDt.toUtc().toIso8601String()
        : DateTime.now().toUtc().toIso8601String();

    await _pb.collection(PBCollections.sessions).update(sessionId, body: {
      'status': 'missed',
      'missed_at': missedAt,
    });

    await _appointmentSync.syncStatus(session, 'cancelled');
    final newConsecutive = await _lifecycle.onSessionMissed(planId);

    await _auditLogger.log(
      sessionId: sessionId,
      planId: planId,
      action: 'manually_confirmed_missed',
      oldDate: session.scheduledDate,
      reason: 'Confirmed missed by $performedBy',
      trigger: 'doctor_manual',
      performedBy: performedBy,
      scheduleVersion: await _currentVersion(planId),
      metadata: {'consecutiveMisses': newConsecutive},
    );

    // If 3+ consecutive misses, move plan to manualReview
    if (newConsecutive >= 3) {
      try {
        await _lifecycle.transition(planId, TreatmentPlanStatus.manualReview);
        await _auditLogger.log(
          planId: planId,
          action: 'moved_to_manual_review',
          reason: '$newConsecutive consecutive misses confirmed by $performedBy',
          trigger: 'doctor_manual',
          performedBy: performedBy,
          scheduleVersion: await _currentVersion(planId),
        );
      } on InvalidTransitionException catch (_) {
        // Plan is already in manualReview (e.g., from a prior 3-miss event).
        // The miss was recorded correctly — no action needed, no error thrown.
      }
    }

    return newConsecutive;
  }

  /// Clinic was closed — revert the session to upcoming with no penalty.
  ///
  /// Optionally sets a new [newDate] if the session needs to be moved.
  Future<void> dismissAsClinicHoliday(
    String sessionId, {
    String? newDate,
    required String performedBy,
  }) async {
    final body = <String, dynamic>{'status': 'upcoming'};
    if (newDate != null && newDate.isNotEmpty) {
      body['scheduled_date'] = newDate;
    }

    await _pb.collection(PBCollections.sessions).update(sessionId, body: body);

    final sessionRec = await _pb.collection(PBCollections.sessions).getOne(sessionId);
    final session = SessionModel.fromRecord(sessionRec);
    final planId = session.treatmentPlanId;

    await _auditLogger.log(
      sessionId: sessionId,
      planId: planId,
      action: 'clinic_holiday_dismissed',
      reason: 'Clinic was closed — dismissed by $performedBy without miss penalty',
      trigger: 'doctor_manual',
      performedBy: performedBy,
      scheduleVersion: await _currentVersion(planId),
      metadata: newDate != null ? {'newDate': newDate} : <String, dynamic>{},
    );
  }

  // ─── Manual Review (Plan-level) ───────────────────────────────────────────

  /// Get all plans currently in [manualReview] status for a doctor or clinic.
  Future<List<TreatmentPlanModel>> getPendingMissedPlans(
    String doctorIdOrClinicId, {
    bool isClinic = false,
  }) =>
      _lifecycle.getPendingReviewPlans(doctorIdOrClinicId, isClinic: isClinic);

  /// Force-reschedule a plan that is in manualReview.
  Future<void> autoRescheduleForPlan(String planId) =>
      _scheduler.autoScheduleFromDashboard(planId, performedBy: 'system');

  // ─── Rescheduling ─────────────────────────────────────────────────────────

  Future<void> rescheduleSessionAndCascade({
    required String sessionId,
    required String newDate,
    String? newTime,
    DateTime? customAnchorDate,
    String performedBy = 'system',
    RescheduleMode mode = RescheduleMode.cascadeAll,
    bool applyTimeToAll = false,
  }) =>
      _scheduler.rescheduleSession(
        sessionId,
        newDate: newDate,
        newTime: newTime ?? '10:00',
        performedBy: performedBy,
        trigger: performedBy == 'system' ? 'system' : 'doctor_manual',
        mode: mode,
        applyTimeToAll: applyTimeToAll,
      );

  Future<ReschedulePreview> previewRescheduleSessionAndCascade({
    required String sessionId,
    required String newDate,
    String? newTime,
    String performedBy = 'system',
    RescheduleMode mode = RescheduleMode.cascadeAll,
    bool applyTimeToAll = false,
  }) =>
      _scheduler.generateRescheduleProposal(
        sessionId,
        newDate: newDate,
        newTime: newTime ?? '10:00',
        performedBy: performedBy,
        trigger: performedBy == 'system' ? 'system' : 'doctor_manual',
        mode: mode,
        applyTimeToAll: applyTimeToAll,
      );

  Future<void> commitRescheduleProposal(ReschedulePreview preview) =>
      _scheduler.commitRescheduleProposal(preview);

  Future<void> rescheduleFromToday(
    String planId,
    List<SessionModel> missedSessions, {
    DateTime? anchorDate,
  }) =>
      _scheduler.rescheduleAfterMiss(
        planId,
        missedSessions,
        performedBy: 'system',
      );

  Future<void> togglePinSession({
    required String sessionId,
    required String planId,
    required bool isPinned,
    required int scheduleVersion,
    String performedBy = 'system',
  }) async {
    await _pb.collection(PBCollections.sessions).update(
      sessionId,
      body: {'is_pinned': isPinned},
    );
    try {
      final appts = await _pb.collection(PBCollections.appointments).getList(
        filter: 'linked_session_id = "$sessionId"',
        perPage: 1,
      );
      if (appts.items.isNotEmpty) {
        await _pb.collection(PBCollections.appointments).update(
          appts.items.first.id,
          body: {'is_pinned': isPinned},
        );
      }
    } catch (_) {}

    await _auditLogger.log(
      action: isPinned ? 'session_pinned' : 'session_unpinned',
      planId: planId,
      performedBy: performedBy,
      scheduleVersion: scheduleVersion,
      reason: isPinned ? 'Session pinned manually' : 'Session unpinned manually',
      trigger: performedBy == 'system' ? 'system' : 'doctor_manual',
    );
  }

  // ─── Exposures ────────────────────────────────────────────────────────────

  AuditLogger get auditLogger => _auditLogger;
  TreatmentScheduler get scheduler => _scheduler;
  TreatmentLifecycle get lifecycle => _lifecycle;

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<int> _currentVersion(String planId) async {
    try {
      final rec = await _pb.collection(PBCollections.treatmentPlans).getOne(planId);
      return rec.getIntValue('schedule_version');
    } catch (_) {
      return 1;
    }
  }
}
