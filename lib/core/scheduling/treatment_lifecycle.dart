import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';

/// State machine for treatment plan lifecycle transitions.
///
/// Every scheduling status change goes through this class to ensure only
/// valid transitions occur and statistics are kept consistent.
class TreatmentLifecycle {
  final PocketBase pb;

  TreatmentLifecycle(this.pb);

  // ─── State Transitions ────────────────────────────────────────────────────

  /// Valid transitions:
  ///
  ///   active       → paused, manualReview, completed, closed
  ///   paused       → active, closed
  ///   manualReview → active, closed
  ///   completed    → (terminal, no transitions)
  ///   closed       → (terminal, no transitions)
  static const Map<TreatmentPlanStatus, Set<TreatmentPlanStatus>> _validTransitions = {
    TreatmentPlanStatus.active: {
      TreatmentPlanStatus.paused,
      TreatmentPlanStatus.manualReview,
      TreatmentPlanStatus.completed,
      TreatmentPlanStatus.closed,
    },
    TreatmentPlanStatus.paused: {
      TreatmentPlanStatus.active,
      TreatmentPlanStatus.closed,
    },
    TreatmentPlanStatus.manualReview: {
      TreatmentPlanStatus.active,
      TreatmentPlanStatus.closed,
    },
    TreatmentPlanStatus.completed: {},
    TreatmentPlanStatus.closed: {},
  };

  /// Execute a lifecycle state transition.
  ///
  /// Throws [InvalidTransitionException] if the transition is not allowed.
  /// [closureReason] and [closedBy] are required when transitioning to [closed].
  Future<void> transition(
    String planId,
    TreatmentPlanStatus newStatus, {
    ClosureReason? closureReason,
    String? closedBy,
  }) async {
    final rec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
    final currentStatus = TreatmentPlanModel.parseStatus(rec.getStringValue('status'));

    final allowed = _validTransitions[currentStatus] ?? {};
    if (!allowed.contains(newStatus)) {
      throw InvalidTransitionException(
        'Cannot transition treatment plan from '
        '${TreatmentPlanModel.statusToString(currentStatus)} to '
        '${TreatmentPlanModel.statusToString(newStatus)}.',
      );
    }

    final body = <String, dynamic>{
      'status': TreatmentPlanModel.statusToString(newStatus),
    };

    // Clear paused state when leaving paused
    if (currentStatus == TreatmentPlanStatus.paused &&
        newStatus == TreatmentPlanStatus.active) {
      body['is_paused'] = false;
      body['paused_at'] = null;
    }

    // Set paused state when entering paused
    if (newStatus == TreatmentPlanStatus.paused) {
      body['is_paused'] = true;
      body['paused_at'] = DateTime.now().toUtc().toIso8601String();
    }

    // Record closure metadata
    if (newStatus == TreatmentPlanStatus.closed) {
      if (closureReason != null) {
        body['closure_reason'] = _closureReasonToString(closureReason);
      }
      if (closedBy != null && closedBy.isNotEmpty) {
        body['closed_by'] = closedBy;
      }
    }

    await pb.collection(PBCollections.treatmentPlans).update(planId, body: body);
  }

  // ─── Statistics ────────────────────────────────────────────────────────────

  /// Called when a session is completed.
  ///
  /// Resets consecutive_misses to 0, increments completed_sessions,
  /// updates last_activity_at. Auto-transitions plan to [completed] if
  /// all sessions are now finished.
  Future<void> onSessionCompleted(String planId) async {
    try {
      final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final totalSessions = planRec.getIntValue('total_sessions');
      final completedSessions = planRec.getIntValue('completed_sessions');
      final newCompleted = completedSessions + 1;

      await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
        'consecutive_misses': 0,
        'completed_sessions': newCompleted,
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Auto-complete plan when all sessions are done
      if (totalSessions > 0 && newCompleted >= totalSessions) {
        try {
          await transition(planId, TreatmentPlanStatus.completed);
        } catch (_) {
          // Plan may already be completed or closed — swallow silently
        }
      }
    } catch (e) {
      debugPrint('[TreatmentLifecycle] onSessionCompleted error: $e');
    }
  }

  /// Called when a single session is marked missed.
  ///
  /// Increments both consecutive_misses (by 1) and total_misses (by 1).
  /// Returns the new consecutive_misses value.
  Future<int> onSessionMissed(String planId) async {
    try {
      final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final consecutive = planRec.getIntValue('consecutive_misses');
      final total = planRec.getIntValue('total_misses');
      final newConsecutive = consecutive + 1;
      final newTotal = total + 1;

      await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
        'consecutive_misses': newConsecutive,
        'total_misses': newTotal,
      });
      return newConsecutive;
    } catch (e) {
      debugPrint('[TreatmentLifecycle] onSessionMissed error: $e');
      return 0;
    }
  }

  /// Check if the plan has been inactive beyond its expiry threshold.
  ///
  /// If expired, transitions to [manualReview] and returns true.
  /// Returns false if the plan is not expired or already in a terminal state.
  Future<bool> checkExpiry(String planId) async {
    try {
      final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final status = TreatmentPlanModel.parseStatus(planRec.getStringValue('status'));

      // Terminal and manual_review states do not expire further
      if (status == TreatmentPlanStatus.completed ||
          status == TreatmentPlanStatus.closed ||
          status == TreatmentPlanStatus.manualReview) {
        return false;
      }

      final expiryDays = planRec.getIntValue('expiry_days');
      final effectiveExpiry = expiryDays > 0 ? expiryDays : 90;

      final lastActivityStr = planRec.getStringValue('last_activity_at');
      final baseline = lastActivityStr.isNotEmpty
          ? DateTime.tryParse(lastActivityStr) ?? DateTime.tryParse(planRec.getStringValue('created'))
          : DateTime.tryParse(planRec.getStringValue('created'));

      if (baseline == null) return false;

      final daysSinceActivity = DateTime.now().difference(baseline).inDays;
      if (daysSinceActivity >= effectiveExpiry) {
        await transition(planId, TreatmentPlanStatus.manualReview);
        return true;
      }
    } catch (e) {
      debugPrint('[TreatmentLifecycle] checkExpiry error: $e');
    }
    return false;
  }

  /// Increment schedule_version and return the new version number.
  Future<int> incrementScheduleVersion(String planId) async {
    try {
      final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final currentVersion = planRec.getIntValue('schedule_version');
      final newVersion = (currentVersion > 0 ? currentVersion : 0) + 1;
      await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
        'schedule_version': newVersion,
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      });
      return newVersion;
    } catch (e) {
      debugPrint('[TreatmentLifecycle] incrementScheduleVersion error: $e');
      return 1;
    }
  }

  /// Retrieve all plans in manual_review status for a doctor or clinic.
  ///
  /// Used by the Auto-Scheduling Dashboard.
  Future<List<TreatmentPlanModel>> getPendingReviewPlans(
    String id, {
    bool isClinic = false,
  }) async {
    try {
      String filter;
      if (isClinic) {
        // Use getFullList to avoid the 50-doctor hard cap
        final docs = await pb.collection('doctors').getFullList(
          filter: 'clinic = "$id"',
        );
        if (docs.isEmpty) return [];
        final doctorFilter =
            docs.map((doc) => 'doctor = "${doc.id}"').join(' || ');
        filter = '($doctorFilter) && status = "manual_review"';
      } else {
        filter = 'doctor = "$id" && status = "manual_review"';
      }

      // Use getFullList to avoid the 100-plan hard cap
      final result = await pb.collection(PBCollections.treatmentPlans).getFullList(
        filter: filter,
        expand: 'patient,doctor',
      );
      return result.map((r) => TreatmentPlanModel.fromRecord(r)).toList();
    } catch (e) {
      debugPrint('[TreatmentLifecycle] getPendingReviewPlans error: $e');
      return [];
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _closureReasonToString(ClosureReason r) {
    switch (r) {
      case ClosureReason.completed:
        return 'completed';
      case ClosureReason.discontinued:
        return 'discontinued';
      case ClosureReason.patientStopped:
        return 'patient_stopped';
      case ClosureReason.medicalDecision:
        return 'medical_decision';
      case ClosureReason.financial:
        return 'financial';
    }
  }
}

// ─── Exceptions ───────────────────────────────────────────────────────────────

class InvalidTransitionException implements Exception {
  final String message;
  InvalidTransitionException(this.message);
  @override
  String toString() => 'InvalidTransitionException: $message';
}
