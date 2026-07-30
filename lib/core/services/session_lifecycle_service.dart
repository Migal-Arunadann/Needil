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
  final PocketBase _pb;

  SessionLifecycleService(PocketBase pb) : _pb = pb {
    _auditLogger = AuditLogger(pb);
    _lifecycle = TreatmentLifecycle(pb);
    final appointmentSync = AppointmentSync(pb);
    final slotFinder = SlotFinder(pb);
    final contextLoader = SchedulingContextLoader(pb);
    _scheduler = TreatmentScheduler(
      pb,
      slotFinder,
      contextLoader,
      appointmentSync,
      _lifecycle,
      _auditLogger,
    );
    _detector = MissedSessionDetector(
      pb,
      _lifecycle,
      _scheduler,
      appointmentSync,
      _auditLogger,
    );
  }

  // ─── Public API (preserved signatures) ───────────────────────────────────

  /// Detect and process missed sessions.
  Future<int> checkAndMarkMissedSessions(String doctorId) =>
      _detector.detectAndProcess(doctorId);

  /// Force-reschedule a plan from the Auto-Scheduling Dashboard.
  Future<void> autoRescheduleForPlan(String planId) =>
      _scheduler.autoScheduleFromDashboard(planId, performedBy: 'system');

  /// Get all plans currently in [manualReview] status for a doctor or clinic.
  ///
  /// Used by the Auto-Scheduling Dashboard.
  Future<List<TreatmentPlanModel>> getPendingMissedPlans(
    String doctorIdOrClinicId, {
    bool isClinic = false,
  }) =>
      _lifecycle.getPendingReviewPlans(doctorIdOrClinicId, isClinic: isClinic);

  /// Reschedule a specific session to a new date, cascading subsequent sessions.
  ///
  /// Called by TreatmentService.rescheduleSession and session_list_screen.
  /// [performedBy] should be the current user's PocketBase record ID; defaults
  /// to 'system' for backward compatibility with automated callers.
  Future<void> rescheduleSessionAndCascade({
    required String sessionId,
    required String newDate,
    String? newTime,
    DateTime? customAnchorDate,
    String performedBy = 'system',
    RescheduleMode mode = RescheduleMode.cascadeAll,
  }) =>
      _scheduler.rescheduleSession(
        sessionId,
        newDate: newDate,
        newTime: newTime ?? '10:00',
        performedBy: performedBy,
        trigger: performedBy == 'system' ? 'system' : 'doctor_manual',
        mode: mode,
      );

  /// Generates a schedule proposal for manually rescheduling a session (no DB writes).
  Future<ReschedulePreview> previewRescheduleSessionAndCascade({
    required String sessionId,
    required String newDate,
    String? newTime,
    String performedBy = 'system',
    RescheduleMode mode = RescheduleMode.cascadeAll,
  }) =>
      _scheduler.generateRescheduleProposal(
        sessionId,
        newDate: newDate,
        newTime: newTime ?? '10:00',
        performedBy: performedBy,
        trigger: performedBy == 'system' ? 'system' : 'doctor_manual',
        mode: mode,
      );

  /// Commits a previewed schedule proposal.
  Future<void> commitRescheduleProposal(ReschedulePreview preview) =>
      _scheduler.commitRescheduleProposal(preview);

  /// Reschedule missed sessions from today — called by TreatmentService.markSessionMissed.
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

  /// Expose the AuditLogger so callers can register event hooks.
  AuditLogger get auditLogger => _auditLogger;

  /// Expose the TreatmentScheduler for direct access when needed.
  TreatmentScheduler get scheduler => _scheduler;

  /// Expose the TreatmentLifecycle for direct access.
  TreatmentLifecycle get lifecycle => _lifecycle;
}
