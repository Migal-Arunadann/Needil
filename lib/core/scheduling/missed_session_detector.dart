import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/scheduling/audit_logger.dart';
import 'package:pms_app/core/scheduling/treatment_lifecycle.dart';
import 'package:pms_app/core/scheduling/appointment_sync.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';

/// Detects stale sessions and flags them as [overdue] for human review.
///
/// Responsibilities:
///   1. Query all stale (past-due, upcoming/waiting/in_progress) sessions
///   2. Flag each as `overdue` — a neutral state requiring human confirmation
///   3. Check expiry for inactive plans (time-based, not assumption-based)
///   4. Clear stale pins (pinned sessions in the past)
///
/// IMPORTANT: This class no longer auto-marks sessions as missed, increments
/// miss counters, or triggers cascading reschedules. All of that is driven by
/// explicit human action in the Needs Attention dashboard.
class MissedSessionDetector {
  final PocketBase pb;
  final TreatmentLifecycle lifecycle;
  final AuditLogger auditLogger;

  MissedSessionDetector(
    this.pb,
    this.lifecycle,
    this.auditLogger,
  );

  // ─── Main Entry Point ─────────────────────────────────────────────────────

  /// Sweep all stale sessions for [doctorId] and flag them as `overdue`.
  ///
  /// Returns the count of sessions newly flagged.
  Future<int> detectAndProcess(String doctorId) async {
    final today = _formatDate(DateTime.now().toLocal());
    int totalFlagged = 0;

    try {
      final allStaleSessions = await _loadAllStale(doctorId, today);
      if (allStaleSessions.isEmpty) return 0;

      // Group by plan so expiry check is done once per plan
      final Map<String, List<SessionModel>> byPlan = {};
      for (final session in allStaleSessions) {
        byPlan.putIfAbsent(session.treatmentPlanId, () => []).add(session);
      }

      for (final entry in byPlan.entries) {
        totalFlagged += await _processPlan(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('[MissedSessionDetector] detectAndProcess error: $e');
    }

    return totalFlagged;
  }

  // ─── Per-Plan Processing ──────────────────────────────────────────────────

  Future<int> _processPlan(
    String planId,
    List<SessionModel> staleSessions,
  ) async {
    try {
      final planRec =
          await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final plan = TreatmentPlanModel.fromRecord(planRec);

      // Skip non-active plans — nothing to flag
      if (plan.status == TreatmentPlanStatus.paused ||
          plan.status == TreatmentPlanStatus.completed ||
          plan.status == TreatmentPlanStatus.closed) {
        return 0;
      }

      // Expiry check still runs — this is time-based, not assumption-based.
      // A plan genuinely inactive for 90+ days needs a human regardless.
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
        return 0;
      }

      final version = plan.scheduleVersion;
      int flagged = 0;

      for (final session in staleSessions) {
        // Clear stale pins — a pinned session in the past is no longer valid
        if (session.isPinned) {
          await pb.collection(PBCollections.sessions).update(session.id, body: {
            'is_pinned': false,
          });
        }

        // Flag as OVERDUE — a neutral state.
        // The doctor or receptionist will confirm what really happened
        // via the Needs Attention dashboard.
        await pb.collection(PBCollections.sessions).update(session.id, body: {
          'status': 'overdue',
        });
        await AppointmentSync(pb).syncStatus(session, 'overdue');

        await auditLogger.log(
          sessionId: session.id,
          planId: planId,
          action: 'flagged_overdue',
          reason: 'Past due — awaiting human confirmation',
          trigger: 'system_auto',
          performedBy: 'system',
          scheduleVersion: version,
        );
        flagged++;
      }

      return flagged;
    } catch (e) {
      debugPrint('[MissedSessionDetector] _processPlan($planId) error: $e');
      return 0;
    }
  }

  // ─── Data Fetching ─────────────────────────────────────────────────────────

  /// Load ALL stale sessions (past-due, not completed/cancelled/missed/overdue)
  /// for [doctorId], paginating through the full result set.
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
