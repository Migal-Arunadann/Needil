import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/scheduling/appointment_sync.dart';
import 'package:pms_app/core/scheduling/audit_logger.dart';
import 'package:pms_app/core/scheduling/treatment_lifecycle.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';

/// Detects stale sessions and evaluates whether they should be auto-completed
/// or marked missed. Hands eligible plans to [TreatmentScheduler] for
/// rescheduling.
///
/// Responsibilities:
///   1. Query all stale (past-due) sessions for a doctor
///   2. Determine outcome: auto-complete (has clinical data) vs. missed
///   3. Update statistics via [TreatmentLifecycle]
///   4. Check expiry for inactive plans
///   5. Clear stale pins (pinned sessions in the past)
///   6. Hand plans with < 3 consecutive misses to [TreatmentScheduler]
///   7. Plans with >= 3 misses → transition to manualReview
///
/// This class intentionally does NOT perform slot-finding or appointment
/// creation — that is [TreatmentScheduler]'s domain.
class MissedSessionDetector {
  final PocketBase pb;
  final TreatmentLifecycle lifecycle;
  final TreatmentScheduler scheduler;
  final AppointmentSync appointmentSync;
  final AuditLogger auditLogger;

  MissedSessionDetector(
    this.pb,
    this.lifecycle,
    this.scheduler,
    this.appointmentSync,
    this.auditLogger,
  );

  // ─── Main Entry Point ─────────────────────────────────────────────────────

  /// Sweep all stale sessions for [doctorId].
  ///
  /// Paginates through all results to avoid the 200-item cap.
  /// Each plan's misses are processed independently so one plan's failure
  /// does not affect others.
  Future<int> detectAndProcess(String doctorId) async {
    final today = _formatDate(DateTime.now().toLocal());
    int totalAutoRescheduled = 0;

    try {
      // Paginate through all stale sessions
      final allStaleSessions = await _loadAllStale(doctorId, today);
      if (allStaleSessions.isEmpty) return 0;

      // Group by plan
      final Map<String, List<SessionModel>> byPlan = {};
      for (final session in allStaleSessions) {
        byPlan.putIfAbsent(session.treatmentPlanId, () => []).add(session);
      }

      for (final entry in byPlan.entries) {
        totalAutoRescheduled += await _processPlan(entry.key, entry.value, today);
      }
    } catch (e) {
      debugPrint('[MissedSessionDetector] detectAndProcess error: $e');
    }
    
    return totalAutoRescheduled;
  }

  // ─── Per-Plan Processing ──────────────────────────────────────────────────

  Future<int> _processPlan(
    String planId,
    List<SessionModel> staleSessions,
    String today,
  ) async {
    try {
      final planRec =
          await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final plan = TreatmentPlanModel.fromRecord(planRec);

      // Skip paused, completed, and closed plans
      if (plan.status == TreatmentPlanStatus.paused ||
          plan.status == TreatmentPlanStatus.completed ||
          plan.status == TreatmentPlanStatus.closed) {
        return 0;
      }

      // Check expiry before processing misses
      final expired = await lifecycle.checkExpiry(planId);
      if (expired) {
        await auditLogger.log(
          planId: planId,
          action: 'expired_to_manual_review',
          reason: 'Plan exceeded inactivity threshold',
          trigger: 'system_auto',
          performedBy: 'system',
          scheduleVersion: plan.scheduleVersion,
        );
        return 0; // checkExpiry already transitioned to manualReview
      }

      final missedSessions = <SessionModel>[];
      final version = plan.scheduleVersion;

      for (final session in staleSessions) {
        // Clear stale pins: a pinned session in the past is no longer a valid anchor
        if (session.isPinned) {
          await pb.collection(PBCollections.sessions).update(session.id, body: {
            'is_pinned': false,
          });
        }

        if (_hasClinicData(session)) {
          // Session has clinical data entered — auto-complete it
          await pb.collection(PBCollections.sessions).update(session.id, body: {
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          });
          await appointmentSync.syncStatus(session, 'completed');
          await lifecycle.onSessionCompleted(planId);
          await auditLogger.log(
            sessionId: session.id,
            planId: planId,
            action: 'auto_completed',
            oldDate: session.scheduledDate,
            reason: 'Clinical data present — auto-completed stale in_progress session',
            trigger: 'system_auto',
            performedBy: 'system',
            scheduleVersion: version,
          );
        } else {
          // No clinical data — mark missed.
          // Use the session's own scheduled_date as missed_at so audit logs
          // and the UI reflect when the session was *due*, not when the sweep ran.
          final scheduledDt = DateTime.tryParse(session.scheduledDate);
          final missedAt = scheduledDt != null
              ? scheduledDt.toUtc().toIso8601String()
              : DateTime.now().toUtc().toIso8601String();
          await pb.collection(PBCollections.sessions).update(session.id, body: {
            'status': 'missed',
            'missed_at': missedAt,
          });
          await appointmentSync.syncStatus(session, 'cancelled');
          // Per-session audit entry so individual session history is traceable
          await auditLogger.log(
            sessionId: session.id,
            planId: planId,
            action: 'missed',
            oldDate: session.scheduledDate,
            reason: 'Past due with no clinical data',
            trigger: 'system_auto',
            performedBy: 'system',
            scheduleVersion: version,
          );
          missedSessions.add(session);
        }
      }

      if (missedSessions.isEmpty) return 0;

      // Increment miss counts once per individual missed session so that
      // consecutive_misses and total_misses grow by 1 for each session,
      // not 1 per sweep batch.
      int newConsecutive = 0;
      for (final _ in missedSessions) {
        newConsecutive = await lifecycle.onSessionMissed(planId);
      }

      await auditLogger.log(
        planId: planId,
        action: 'sessions_missed',
        reason: '${missedSessions.length} stale session(s) marked missed',
        trigger: 'system_auto',
        performedBy: 'system',
        scheduleVersion: version,
        metadata: {
          'missedCount': missedSessions.length,
          'consecutiveMisses': newConsecutive,
        },
      );

      if (newConsecutive >= 3) {
        // Too many consecutive misses — surface in dashboard
        await lifecycle.transition(planId, TreatmentPlanStatus.manualReview);
        await auditLogger.log(
          planId: planId,
          action: 'moved_to_manual_review',
          reason: '$newConsecutive consecutive misses',
          trigger: 'system_auto',
          performedBy: 'system',
          scheduleVersion: version,
        );
        return 0;
      }

      // Hand to TreatmentScheduler for rescheduling
      await scheduler.rescheduleAfterMiss(
        planId,
        missedSessions,
        performedBy: 'system',
      );
      return missedSessions.length;
    } catch (e) {
      debugPrint('[MissedSessionDetector] _processPlan($planId) error: $e');
      return 0;
    }
  }

  // ─── Clinical Data Check ───────────────────────────────────────────────────

  /// Returns true if the session has any clinical data entered.
  ///
  /// Used to determine whether a stale in_progress session should be
  /// auto-completed (work was done but user forgot to close the session)
  /// or marked as missed (nothing was recorded).
  ///
  /// This logic deliberately lives in the DETECTOR, not the scheduler,
  /// because it evaluates clinical/domain data — outside scheduling's concern.
  static bool _hasClinicData(SessionModel s) {
    return (s.notes != null && s.notes!.trim().isNotEmpty) ||
        (s.remarks != null && s.remarks!.trim().isNotEmpty) ||
        (s.bpLevel != null && s.bpLevel!.trim().isNotEmpty) ||
        (s.pulse != null && s.pulse! > 0) ||
        (s.photos.isNotEmpty);
  }

  // ─── Data Fetching ─────────────────────────────────────────────────────────

  /// Load ALL stale sessions (past-due, not completed/cancelled) for [doctorId],
  /// paginating through the full result set.
  Future<List<SessionModel>> _loadAllStale(
    String doctorId,
    String today,
  ) async {
    final sessions = <SessionModel>[];
    int page = 1;
    const pageSize = 200;

    while (true) {
      final result = await pb.collection(PBCollections.sessions).getList(
        page: page,
        perPage: pageSize,
        filter:
            'doctor = "$doctorId" '
            '&& (status = "upcoming" || status = "waiting" || status = "in_progress") '
            '&& scheduled_date < "$today"',
        sort: 'scheduled_date,session_number',
      );

      sessions.addAll(result.items.map((r) => SessionModel.fromRecord(r)));

      if (result.items.length < pageSize) break;
      page++;
    }

    return sessions;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
