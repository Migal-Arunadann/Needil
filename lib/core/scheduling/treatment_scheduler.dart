import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/scheduling/appointment_sync.dart';
import 'package:pms_app/core/scheduling/audit_logger.dart';
import 'package:pms_app/core/scheduling/slot_finder.dart';
import 'package:pms_app/core/scheduling/treatment_lifecycle.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

/// How subsequent sessions behave when a specific session is rescheduled.
enum RescheduleMode {
  /// Reschedule the target session and cascade all subsequent pending sessions.
  cascadeAll,

  /// Reschedule only the target session. Leave subsequent sessions untouched.
  missedOnly,
}

// ─── Proposal types (Dry-run pipeline) ───────────────────────────────────────

/// A proposed date/time for a single session — no DB writes yet.
class ProposedSlot {
  final String sessionId;
  final int sessionNumber;
  final String oldDate;
  final String oldTime;
  final String newDate;
  final String newTime;
  /// True if this session was pinned and was therefore skipped during cascade.
  final bool wasPinned;
  /// True if the session was missed/paused and will be restored to upcoming.
  final bool statusRestored;

  /// True if this was the specific session the user manually rescheduled.
  final bool isTarget;

  const ProposedSlot({
    required this.sessionId,
    required this.sessionNumber,
    required this.oldDate,
    required this.oldTime,
    required this.newDate,
    required this.newTime,
    this.wasPinned = false,
    this.statusRestored = false,
    this.isTarget = false,
  });
  ProposedSlot copyWith({
    String? sessionId,
    int? sessionNumber,
    String? oldDate,
    String? oldTime,
    String? newDate,
    String? newTime,
    bool? wasPinned,
    bool? statusRestored,
    bool? isTarget,
  }) {
    return ProposedSlot(
      sessionId: sessionId ?? this.sessionId,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      oldDate: oldDate ?? this.oldDate,
      oldTime: oldTime ?? this.oldTime,
      newDate: newDate ?? this.newDate,
      newTime: newTime ?? this.newTime,
      wasPinned: wasPinned ?? this.wasPinned,
      statusRestored: statusRestored ?? this.statusRestored,
      isTarget: isTarget ?? this.isTarget,
    );
  }
}

/// A complete in-memory schedule proposal for a plan rebuild.
/// No DB writes happen until [TreatmentScheduler._commitProposal] is called.
class ScheduleProposal {
  final String planId;
  final List<ProposedSlot> slots;
  final int newScheduleVersion;
  final String trigger;
  final String performedBy;
  final String? clinicId;
  final String sessionType;
  /// Number of non-pinned sessions submitted for scheduling.
  /// Used by [TreatmentScheduler._validateProposal] to detect partial builds.
  final int totalExpected;
  final int? updatedIntervalDays;
  final int currentIntervalDays;

  const ScheduleProposal({
    required this.planId,
    required this.slots,
    required this.newScheduleVersion,
    required this.trigger,
    required this.performedBy,
    this.clinicId,
    required this.sessionType,
    required this.totalExpected,
    this.updatedIntervalDays,
    this.currentIntervalDays = 1,
  });

  ScheduleProposal copyWith({
    String? planId,
    List<ProposedSlot>? slots,
    int? newScheduleVersion,
    String? trigger,
    String? performedBy,
    String? clinicId,
    String? sessionType,
    int? totalExpected,
    int? updatedIntervalDays,
    int? currentIntervalDays,
  }) {
    return ScheduleProposal(
      planId: planId ?? this.planId,
      slots: slots ?? this.slots,
      newScheduleVersion: newScheduleVersion ?? this.newScheduleVersion,
      trigger: trigger ?? this.trigger,
      performedBy: performedBy ?? this.performedBy,
      clinicId: clinicId ?? this.clinicId,
      sessionType: sessionType ?? this.sessionType,
      totalExpected: totalExpected ?? this.totalExpected,
      updatedIntervalDays: updatedIntervalDays ?? this.updatedIntervalDays,
      currentIntervalDays: currentIntervalDays ?? this.currentIntervalDays,
    );
  }
}

/// The result of validating a [ScheduleProposal].
class ValidationResult {
  final bool isValid;
  final List<String> warnings;
  final String? failureReason;

  const ValidationResult.ok({List<String>? warnings})
      : isValid = true,
        warnings = const [],
        failureReason = null;

  const ValidationResult.fail(this.failureReason)
      : isValid = false,
        warnings = const [];

  const ValidationResult.withWarnings(this.warnings)
      : isValid = true,
        failureReason = null;
}

class ReschedulePreview {
  final ScheduleProposal proposal;
  final ValidationResult validation;

  const ReschedulePreview(this.proposal, this.validation);
}

// ─── TreatmentScheduler ───────────────────────────────────────────────────────

/// Orchestrates all scheduling operations for a treatment plan.
///
/// Pipeline: generateProposal → validate → commit
///
/// Public operations:
///   [rescheduleAfterMiss]         – Called by MissedSessionDetector
///   [rescheduleSession]           – Manual reschedule by doctor/receptionist
///   [pausePlan]                   – Pause: marks sessions + cancels appointments
///   [resumePlan]                  – Resume: reschedules paused sessions from today
///   [autoScheduleFromDashboard]   – Dashboard: force reschedule for manual_review plans
///   [closeTreatment]              – Early closure: cancels remaining sessions
class TreatmentScheduler {
  final PocketBase pb;
  final SlotFinder slotFinder;
  final SchedulingContextLoader contextLoader;
  final AppointmentSync appointmentSync;
  final TreatmentLifecycle lifecycle;
  final AuditLogger auditLogger;

  TreatmentScheduler(
    this.pb,
    this.slotFinder,
    this.contextLoader,
    this.appointmentSync,
    this.lifecycle,
    this.auditLogger,
  );

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Reschedule after the [MissedSessionDetector] marks sessions as missed.
  ///
  /// Anchors from today. Respects pinned sessions.
  /// On [NoSlotFoundException], transitions plan to manualReview.
  Future<void> rescheduleAfterMiss(
    String planId,
    List<SessionModel> missedSessions, {
    required String performedBy,
  }) async {
    try {
      final context = await contextLoader.load(planId);
      final preferredTime = await _loadPreferredTime(planId);
      final allSessions = await _loadPendingSessions(planId, includeMissed: true);

      final earliestMissedNum = missedSessions
          .map((s) => s.sessionNumber)
          .reduce((a, b) => a < b ? a : b);

      final toReschedule = allSessions
          .where((s) =>
              s.sessionNumber >= earliestMissedNum &&
              (s.status == SessionStatus.missed ||
                  s.status == SessionStatus.upcoming))
          .toList()
        ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

      if (toReschedule.isEmpty) return;

      final proposal = await _generateProposal(
        context: context,
        sessionsToReschedule: toReschedule,
        anchorDate: DateTime.now(),
        preferredTime: preferredTime,
        trigger: 'system_auto',
        performedBy: performedBy,
        planId: planId,
      );

      final validation = _validateProposal(proposal);
      if (!validation.isValid) {
        // Cannot find slots — push to manual review
        await lifecycle.transition(planId, TreatmentPlanStatus.manualReview);
        await auditLogger.log(
          planId: planId,
          action: 'moved_to_manual_review',
          reason: validation.failureReason ?? 'No slots available',
          trigger: 'system_auto',
          performedBy: performedBy,
          scheduleVersion: await _currentVersion(planId),
          metadata: {'failureReason': validation.failureReason},
        );
        return;
      }

      await _commitProposal(proposal, validation, context);
    } catch (e) {
      debugPrint('[TreatmentScheduler] rescheduleAfterMiss error: $e');
    }
  }

  /// Generates a schedule proposal for manually rescheduling a session, without writing to the DB.
  /// This simulates pinning the target session and cascading subsequent sessions.
  Future<ReschedulePreview> generateRescheduleProposal(
    String sessionId, {
    required String newDate,
    required String newTime,
    required String performedBy,
    required String trigger,
    RescheduleMode mode = RescheduleMode.cascadeAll,
    bool applyTimeToAll = false,
    int? overrideIntervalDays,
  }) async {
    final sessionRec = await pb.collection(PBCollections.sessions).getOne(sessionId);
    final targetSession = SessionModel.fromRecord(sessionRec);
    final planId = targetSession.treatmentPlanId;
    
    final context = await contextLoader.load(planId);
    final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
    final newVersion = planRec.getIntValue('schedule_version');
    final sessionType = planRec.getStringValue('treatment_type');
    final activeInterval = overrideIntervalDays ?? (planRec.getIntValue('interval_days') > 0 ? planRec.getIntValue('interval_days') : 1);
    
    // Simulate target session being pinned and moved
    final targetProposedSlot = ProposedSlot(
      sessionId: sessionId,
      sessionNumber: targetSession.sessionNumber,
      oldDate: targetSession.originalDate ?? targetSession.scheduledDate,
      oldTime: targetSession.scheduledTime ?? '',
      newDate: newDate,
      newTime: newTime,
      wasPinned: true, // target session is pinned
      statusRestored: targetSession.status == SessionStatus.missed ||
          targetSession.status == SessionStatus.paused ||
          targetSession.status == SessionStatus.overdue,
      isTarget: true,
    );
    
    final slots = <ProposedSlot>[targetProposedSlot];
    
    if (mode == RescheduleMode.cascadeAll) {
      final allSessions = await _loadPendingSessions(planId, includeMissed: true);
      final subsequent = allSessions
          .where((s) =>
              s.sessionNumber > targetSession.sessionNumber &&
              !s.isPinned &&
              (s.status == SessionStatus.upcoming ||
                  s.status == SessionStatus.missed ||
                  s.status == SessionStatus.paused ||
                  s.status == SessionStatus.overdue))
          .toList()
        ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

      if (subsequent.isNotEmpty) {
        final anchorDate = DateTime.tryParse(newDate)?.toLocal() ?? DateTime.now();
        final cascadeProposal = await _generateProposal(
          context: context,
          sessionsToReschedule: subsequent,
          anchorDate: anchorDate,
          preferredTime: applyTimeToAll ? newTime : await _loadPreferredTime(planId),
          trigger: trigger,
          performedBy: performedBy,
          planId: planId,
          anchorIsOffset: true,
          overrideIntervalDays: activeInterval,
        );
        slots.addAll(cascadeProposal.slots);
      }
    }
    
    int expectedCascade = 0;
    if (mode == RescheduleMode.cascadeAll) {
      expectedCascade = (await _loadPendingSessions(planId, includeMissed: true))
          .where((s) =>
              s.sessionNumber > targetSession.sessionNumber &&
              !s.isPinned &&
              (s.status == SessionStatus.upcoming ||
                  s.status == SessionStatus.missed ||
                  s.status == SessionStatus.paused ||
                  s.status == SessionStatus.overdue))
          .length;
    }
    
    final proposal = ScheduleProposal(
      planId: planId,
      slots: slots,
      newScheduleVersion: newVersion,
      trigger: trigger,
      performedBy: performedBy,
      clinicId: context.clinicId,
      sessionType: sessionType,
      totalExpected: expectedCascade,
      updatedIntervalDays: overrideIntervalDays,
      currentIntervalDays: activeInterval,
    );
    
    return ReschedulePreview(proposal, _validateProposal(proposal));
  }

  /// Commits a [ScheduleProposal] previously generated by [generateRescheduleProposal].
  Future<void> commitRescheduleProposal(ReschedulePreview preview) async {
    final proposal = preview.proposal;
    final validation = preview.validation;
    final planId = proposal.planId;
    final context = await contextLoader.load(planId);
    
    final targetSlot = proposal.slots.firstWhere((s) => s.isTarget);
    
    final sessionRec = await pb.collection(PBCollections.sessions).getOne(targetSlot.sessionId);
    final targetSession = SessionModel.fromRecord(sessionRec);
    
    // 1. Commit the target session (pinning it)
    await pb.collection(PBCollections.sessions).update(targetSlot.sessionId, body: {
      'is_pinned': true,
      'scheduled_date': targetSlot.newDate,
      'scheduled_time': targetSlot.newTime,
      'is_rescheduled': true,
      'original_date': targetSession.originalDate ?? targetSession.scheduledDate,
      'reschedule_count': targetSession.rescheduleCount + 1,
      if (targetSlot.statusRestored) 'status': 'upcoming',
    });

    // Sync appointment for the target session
    final updatedSessionRec = await pb.collection(PBCollections.sessions).getOne(targetSlot.sessionId);
    final updatedSession = SessionModel.fromRecord(updatedSessionRec);
    await appointmentSync.updateForSession(
      session: updatedSession,
      newDate: targetSlot.newDate,
      newTime: targetSlot.newTime,
      clinicId: context.clinicId,
      sessionType: proposal.sessionType,
    );

    // Log the manual pin
    await auditLogger.log(
      sessionId: targetSlot.sessionId,
      planId: planId,
      action: 'pinned',
      oldDate: targetSession.scheduledDate,
      oldTime: targetSession.scheduledTime ?? '',
      newDate: targetSlot.newDate,
      newTime: targetSlot.newTime,
      reason: 'Manual reschedule by ${proposal.trigger}',
      trigger: proposal.trigger,
      performedBy: proposal.performedBy,
      scheduleVersion: await _currentVersion(planId),
    );

    // 2. Commit the rest of the cascade
    await _commitProposal(proposal, validation, context);
  }

  /// Manually reschedule a specific session.
  ///
  /// Sets [is_pinned] = true on the target session.
  /// Cascades subsequent sessions when [mode] = [RescheduleMode.cascadeAll].
  Future<void> rescheduleSession(
    String sessionId, {
    required String newDate,
    required String newTime,
    required String performedBy,
    required String trigger,
    RescheduleMode mode = RescheduleMode.cascadeAll,
    bool applyTimeToAll = false,
  }) async {
    try {
      final sessionRec =
          await pb.collection(PBCollections.sessions).getOne(sessionId);
      final targetSession = SessionModel.fromRecord(sessionRec);
      final planId = targetSession.treatmentPlanId;

      final context = await contextLoader.load(planId);
      final preferredTime = applyTimeToAll ? newTime : await _loadPreferredTime(planId);

      // Pin the target session before cascade
      await pb.collection(PBCollections.sessions).update(sessionId, body: {
        'is_pinned': true,
        'scheduled_date': newDate,
        'scheduled_time': newTime,
        'is_rescheduled': true,
        'original_date': targetSession.originalDate ?? targetSession.scheduledDate,
        'reschedule_count': targetSession.rescheduleCount + 1,
        if (targetSession.status == SessionStatus.missed ||
            targetSession.status == SessionStatus.paused)
          'status': 'upcoming',
      });

      // Sync the appointment for the target session
      final updatedSessionRec =
          await pb.collection(PBCollections.sessions).getOne(sessionId);
      final updatedSession = SessionModel.fromRecord(updatedSessionRec);
      await appointmentSync.updateForSession(
        session: updatedSession,
        newDate: newDate,
        newTime: newTime,
        clinicId: context.clinicId,
        sessionType: await _loadSessionType(planId),
      );

      // Log the pin
      await auditLogger.log(
        sessionId: sessionId,
        planId: planId,
        action: 'pinned',
        oldDate: targetSession.scheduledDate,
        oldTime: targetSession.scheduledTime ?? '',
        newDate: newDate,
        newTime: newTime,
        reason: 'Manual reschedule by $trigger',
        trigger: trigger,
        performedBy: performedBy,
        scheduleVersion: await _currentVersion(planId),
      );

      if (mode == RescheduleMode.missedOnly) return;

      // Cascade subsequent non-pinned sessions.
      // HR-1 fix: includeMissed: true so missed sessions after the pinned one
      // are also cascaded — previously they were silently skipped.
      final allSessions = await _loadPendingSessions(planId, includeMissed: true);
      final subsequent = allSessions
          .where((s) =>
              s.sessionNumber > targetSession.sessionNumber &&
              !s.isPinned &&
              (s.status == SessionStatus.upcoming ||
                  s.status == SessionStatus.missed ||
                  s.status == SessionStatus.paused))
          .toList()
        ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

      if (subsequent.isEmpty) return;

      // Anchor cascade from the newly pinned date
      final anchorDate =
          DateTime.tryParse(newDate)?.toLocal() ?? DateTime.now();
      try {
        final proposal = await _generateProposal(
          context: context,
          sessionsToReschedule: subsequent,
          anchorDate: anchorDate,
          preferredTime: preferredTime,
          trigger: trigger,
          performedBy: performedBy,
          planId: planId,
          anchorIsOffset: true, // start cursor from anchor + interval
        );

        final validation = _validateProposal(proposal);
        await _commitProposal(proposal, validation, context);
      } catch (e) {
        // HR-3 fix: if cascade fails, attempt to restore the target session
        // to its original date/time so the schedule is left consistent.
        debugPrint('[TreatmentScheduler] cascade failed for $sessionId — attempting rollback: $e');
        try {
          await pb.collection(PBCollections.sessions).update(sessionId, body: {
            'is_pinned': false,
            'scheduled_date': targetSession.scheduledDate,
            'scheduled_time': targetSession.scheduledTime,
            'is_rescheduled': targetSession.isRescheduled,
            'reschedule_count': targetSession.rescheduleCount,
            if (targetSession.status == SessionStatus.missed ||
                targetSession.status == SessionStatus.paused)
              'status': targetSession.status.name,
          });
        } catch (rollbackError) {
          debugPrint('[TreatmentScheduler] rollback also failed: $rollbackError');
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('[TreatmentScheduler] rescheduleSession error: $e');
    }
  }

  /// Inspects all pending sessions of [planId] and ensures they are strictly in chronological order:
  /// Session 1 date < Session 2 date < Session 3 date < Session 4 date...
  /// If any session has an inverted or colliding date, it realigns them from the first inverted session.
  Future<void> realignPlanSequence(String planId, {required String performedBy}) async {
    try {
      final context = await contextLoader.load(planId);
      final allSessions = await _loadPendingSessions(planId, includeMissed: true);
      if (allSessions.length < 2) return;

      allSessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

      bool needsRealign = false;
      int firstInvertedIndex = -1;

      for (int i = 1; i < allSessions.length; i++) {
        final prevDt = DateTime.tryParse(allSessions[i - 1].scheduledDate);
        final currDt = DateTime.tryParse(allSessions[i].scheduledDate);
        if (prevDt != null && currDt != null) {
          if (!currDt.isAfter(prevDt)) {
            needsRealign = true;
            firstInvertedIndex = i;
            break;
          }
        }
      }

      if (!needsRealign || firstInvertedIndex == -1) return;

      final prevSession = allSessions[firstInvertedIndex - 1];
      final anchorDate = DateTime.tryParse(prevSession.scheduledDate)?.toLocal() ?? DateTime.now();
      final sessionsToReschedule = allSessions.sublist(firstInvertedIndex);
      final preferredTime = await _loadPreferredTime(planId);

      final proposal = await _generateProposal(
        context: context,
        sessionsToReschedule: sessionsToReschedule,
        anchorDate: anchorDate,
        preferredTime: preferredTime,
        trigger: 'sequence_realign',
        performedBy: performedBy,
        planId: planId,
        anchorIsOffset: true,
      );

      final validation = _validateProposal(proposal);
      await _commitProposal(proposal, validation, context);
    } catch (e) {
      debugPrint('[TreatmentScheduler] realignPlanSequence error: $e');
    }
  }

  /// Checks if there is a pending session scheduled on the [targetDate] that is not [excludeSessionId].
  Future<SessionModel?> findConflictingSession(
    String planId,
    String targetDate,
    String excludeSessionId,
  ) async {
    final allSessions = await _loadPendingSessions(planId, includeMissed: true);
    for (final s in allSessions) {
      if (s.id != excludeSessionId &&
          !s.isPinned &&
          (s.scheduledDate == targetDate || s.originalDate == targetDate) &&
          (s.status == SessionStatus.upcoming ||
           s.status == SessionStatus.missed ||
           s.status == SessionStatus.paused)) {
        return s;
      }
    }
    return null;
  }

  /// Pause a treatment plan.
  ///
  /// Pauses BOTH upcoming AND missed sessions (v1 only paused upcoming).
  /// Cancels all linked appointments.
  Future<void> pausePlan(
    String planId, {
    required String performedBy,
    required String trigger,
  }) async {
    try {
      // HR-2 fix: Pause sessions FIRST, then transition the plan.
      // Previously the plan was transitioned to paused before sessions were
      // updated. A crash mid-loop would leave the plan paused but some
      // sessions still upcoming — permanently invisible to the detector
      // (skips paused plans) and to resumePlan (queries only paused sessions).
      final version = await _currentVersion(planId);

      // Pause all pending sessions (upcoming + missed + waiting + overdue — not completed/cancelled)
      final sessRes = await pb.collection(PBCollections.sessions).getList(
        filter:
            'treatment_plan = "$planId" && (status = "upcoming" || status = "missed" || status = "waiting" || status = "overdue")',
        sort: 'session_number',
        perPage: 200,
      );

      for (final sessRec in sessRes.items) {
        final session = SessionModel.fromRecord(sessRec);
        await pb.collection(PBCollections.sessions).update(session.id, body: {
          'status': 'paused',
          'paused_at': DateTime.now().toUtc().toIso8601String(),
        });
        await appointmentSync.cancelForSession(session.id, session: session);
        await auditLogger.log(
          sessionId: session.id,
          planId: planId,
          action: 'paused',
          oldDate: session.scheduledDate,
          oldTime: session.scheduledTime ?? '',
          reason: 'Plan paused',
          trigger: trigger,
          performedBy: performedBy,
          scheduleVersion: version,
        );
      }

      // Transition the plan to paused only after all sessions are safely updated.
      // If this throws, sessions are paused but the plan status will be corrected
      // on the next resume attempt (sessions are paused, so they'll be found).
      await lifecycle.transition(planId, TreatmentPlanStatus.paused);
    } catch (e) {
      debugPrint('[TreatmentScheduler] pausePlan error: $e');
    }
  }

  /// Resume a paused treatment plan.
  ///
  /// [rescheduleAll] = true:
  ///   Clears all pins, reschedules every paused session from today.
  ///
  /// [rescheduleAll] = false:
  ///   Preserves pinned sessions, reschedules non-pinned paused sessions
  ///   from today — pinned sessions keep their existing dates.
  Future<void> resumePlan(
    String planId, {
    required bool rescheduleAll,
    required String performedBy,
    required String trigger,
  }) async {
    try {
      final context = await contextLoader.load(planId);
      final preferredTime = await _loadPreferredTime(planId);

      final sessRes = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId" && status = "paused"',
        sort: 'session_number',
        perPage: 200,
      );

      if (sessRes.items.isEmpty) {
        // Nothing paused — just un-pause the plan
        await lifecycle.transition(planId, TreatmentPlanStatus.active);
        return;
      }

      // If rescheduleAll: clear all pins before rebuilding
      if (rescheduleAll) {
        for (final rec in sessRes.items) {
          if (rec.getBoolValue('is_pinned')) {
            await pb.collection(PBCollections.sessions).update(rec.id, body: {
              'is_pinned': false,
            });
          }
        }
      }

      // Re-load sessions (pins may have changed)
      final reloadedRes = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId" && status = "paused"',
        sort: 'session_number',
        perPage: 200,
      );

      final toReschedule = reloadedRes.items
          .map((r) => SessionModel.fromRecord(r))
          .where((s) => !s.isPinned) // skip pinned sessions unless rescheduleAll cleared them
          .toList();

      if (toReschedule.isNotEmpty) {
        final proposal = await _generateProposal(
          context: context,
          sessionsToReschedule: toReschedule,
          anchorDate: DateTime.now(),
          preferredTime: preferredTime,
          trigger: trigger,
          performedBy: performedBy,
          planId: planId,
        );

        final validation = _validateProposal(proposal);
        await _commitProposal(proposal, validation, context);
      }

      // For pinned sessions that were preserved — restore their status to upcoming
      // without changing their dates
      if (!rescheduleAll) {
        for (final rec in reloadedRes.items) {
          if (rec.getBoolValue('is_pinned')) {
            final session = SessionModel.fromRecord(rec);
            await pb.collection(PBCollections.sessions).update(session.id, body: {
              'status': 'upcoming',
            });
            // Re-create appointment for pinned session
            await appointmentSync.createForSession(
              sessionId: session.id,
              patientId: session.patientId,
              doctorId: session.doctorId,
              date: session.scheduledDate,
              time: session.scheduledTime ?? preferredTime,
              clinicId: context.clinicId,
              sessionType: await _loadSessionType(planId),
            );
          }
        }
      }

      // Transition plan back to active
      await lifecycle.transition(planId, TreatmentPlanStatus.active);
    } catch (e) {
      debugPrint('[TreatmentScheduler] resumePlan error: $e');
    }
  }

  /// Force-reschedule a plan from the Auto-Scheduling Dashboard.
  ///
  /// Resets consecutive_misses to 0 and transitions from manualReview → active.
  /// Respects pinned sessions.
  Future<void> autoScheduleFromDashboard(
    String planId, {
    required String performedBy,
  }) async {
    try {
      final context = await contextLoader.load(planId);
      final preferredTime = await _loadPreferredTime(planId);

      // MR-3 fix: Reset consecutive_misses BEFORE the proposal commit.
      // If the reset happened after and the commit succeeded but the reset failed,
      // the detector's next sweep would see consecutive_misses >= 3 and immediately
      // re-move the plan to manualReview, then reschedule already-placed sessions.
      await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
        'consecutive_misses': 0,
      });

      // Gather all missed + upcoming sessions to rebuild
      final allSessions = await _loadPendingSessions(planId, includeMissed: true);
      final toReschedule = allSessions
          .where((s) =>
              s.status == SessionStatus.missed ||
              s.status == SessionStatus.upcoming)
          .toList()
        ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

      if (toReschedule.isNotEmpty) {
        final proposal = await _generateProposal(
          context: context,
          sessionsToReschedule: toReschedule,
          anchorDate: DateTime.now(),
          preferredTime: preferredTime,
          trigger: 'dashboard',
          performedBy: performedBy,
          planId: planId,
        );
        final validation = _validateProposal(proposal);
        await _commitProposal(proposal, validation, context);
      }

      // Restore to active
      await lifecycle.transition(planId, TreatmentPlanStatus.active);

      await auditLogger.log(
        planId: planId,
        action: 'auto_scheduled_from_dashboard',
        reason: 'Manual intervention via dashboard',
        trigger: 'dashboard',
        performedBy: performedBy,
        scheduleVersion: await _currentVersion(planId),
      );
    } catch (e) {
      debugPrint('[TreatmentScheduler] autoScheduleFromDashboard error: $e');
    }
  }

  /// Close a treatment plan early.
  ///
  /// Cancels all remaining sessions and their appointments.
  /// Records closure reason in the plan.
  Future<void> closeTreatment(
    String planId, {
    required ClosureReason reason,
    required String performedBy,
  }) async {
    try {
      // LR-2 fix: include in_progress so a session being actively conducted
      // when the plan is closed is also cancelled (not left orphaned forever).
      final sessRes = await pb.collection(PBCollections.sessions).getList(
        filter:
            'treatment_plan = "$planId" && '
            '(status = "upcoming" || status = "in_progress" || status = "paused" || status = "missed" || status = "waiting")',
        perPage: 200,
      );

      final version = await _currentVersion(planId);

      for (final rec in sessRes.items) {
        final session = SessionModel.fromRecord(rec);
        await pb.collection(PBCollections.sessions).update(session.id, body: {
          'status': 'cancelled',
        });
        await appointmentSync.cancelForSession(session.id, session: session);
      }

      // Transition plan to closed with reason
      await lifecycle.transition(
        planId,
        TreatmentPlanStatus.closed,
        closureReason: reason,
        closedBy: performedBy,
      );

      await auditLogger.log(
        planId: planId,
        action: 'closed',
        reason: 'Plan closed: ${reason.name}',
        trigger: 'doctor_manual',
        performedBy: performedBy,
        scheduleVersion: version,
        metadata: {'closureReason': reason.name, 'sessionsCancel': sessRes.items.length},
      );
    } catch (e) {
      debugPrint('[TreatmentScheduler] closeTreatment error: $e');
    }
  }

  // ─── Internal Pipeline ─────────────────────────────────────────────────────

  /// Phase 1: Generate a schedule proposal in memory. Zero DB writes.
  ///
  /// Cascade algorithm:
  ///   1. For each session (sorted by session_number):
  ///      a. If isPinned → emit a "wasPinned" slot (no date change), reset cursor to pinned date
  ///      b. Otherwise → ask SlotFinder for the best slot starting from cursor
  ///   2. Pinned anchor causes cursor to re-base after the pin, maintaining interval
  Future<ScheduleProposal> _generateProposal({
    required SchedulingContext context,
    required List<SessionModel> sessionsToReschedule,
    required DateTime anchorDate,
    required String preferredTime,
    required String trigger,
    required String performedBy,
    required String planId,
    bool anchorIsOffset = false, // if true, cascade starts at anchorDate + interval
    int? overrideIntervalDays,
  }) async {
    final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
    final intervalDays = overrideIntervalDays ?? (planRec.getIntValue('interval_days') > 0 ? planRec.getIntValue('interval_days') : 1);
    final sessionType = planRec.getStringValue('treatment_type');
    final newVersion = planRec.getIntValue('schedule_version');

    // CR-1 fix: track how many non-pinned sessions we expect to place.
    // _validateProposal compares this against slots actually placed to detect
    // partial builds (NoSlotFoundException mid-cascade).
    final totalExpected = sessionsToReschedule.where((s) => !s.isPinned).length;

    final slots = <ProposedSlot>[];

    DateTime cursor = anchorDate;
    bool firstNonPinned = true;

    for (final session in sessionsToReschedule) {
      if (session.isPinned) {
        // Preserve pinned session — emit unchanged, reset cursor to pinned date
        final pinnedDate = DateTime.tryParse(session.scheduledDate)?.toLocal() ?? cursor;
        slots.add(ProposedSlot(
          sessionId: session.id,
          sessionNumber: session.sessionNumber,
          oldDate: session.scheduledDate,
          oldTime: session.scheduledTime ?? '',
          newDate: session.scheduledDate,   // unchanged
          newTime: session.scheduledTime ?? preferredTime,
          wasPinned: true,
        ));
        cursor = pinnedDate; // re-base cascade cursor after the pin
        firstNonPinned = false;
        continue;
      }

      // Find a slot for this session
      DateTime candidateStart;
      if (firstNonPinned && !anchorIsOffset) {
        candidateStart = cursor;
        firstNonPinned = false;
      } else {
        candidateStart = cursor.add(Duration(days: intervalDays > 0 ? intervalDays : 1));
        firstNonPinned = false;
      }

      try {
        final slotResult = await slotFinder.findBestSlot(
          context: context,
          startDate: candidateStart,
          preferredTime: preferredTime,
        );
        slots.add(ProposedSlot(
          sessionId: session.id,
          sessionNumber: session.sessionNumber,
          oldDate: session.scheduledDate,
          oldTime: session.scheduledTime ?? '',
          newDate: formatLocalDate(slotResult.date),
          newTime: slotResult.time,
          statusRestored: session.status == SessionStatus.missed ||
              session.status == SessionStatus.paused,
        ));
        cursor = slotResult.date; // advance cursor to actual placed date
      } on NoSlotFoundException catch (noSlot) {
        // Return a partial proposal — _validateProposal detects
        // slots.where(!wasPinned).length < totalExpected and fails it.
        debugPrint('[TreatmentScheduler] No slot found for session ${session.id}: ${noSlot.message}');
        return ScheduleProposal(
          planId: planId,
          slots: slots,
          newScheduleVersion: newVersion + 1,
          trigger: trigger,
          performedBy: performedBy,
          clinicId: context.clinicId,
          sessionType: sessionType,
          totalExpected: totalExpected,
        );
      }
    }

    return ScheduleProposal(
      planId: planId,
      slots: slots,
      newScheduleVersion: newVersion + 1,
      trigger: trigger,
      performedBy: performedBy,
      clinicId: context.clinicId,
      sessionType: sessionType,
      totalExpected: totalExpected,
    );
  }

  /// Phase 2: Validate a proposal. Zero DB writes.
  ///
  /// Checks:
  ///   - All expected sessions have a slot (partial = fail)
  ///   - Date ordering around pinned sessions (warn, don't fail)
  ValidationResult _validateProposal(ScheduleProposal proposal) {
    // CR-1 fix: detect partial builds by comparing placed slots against expected.
    // Previously this used an empty-newDate check which was always false.
    final placed = proposal.slots.where((s) => !s.wasPinned).length;
    if (placed < proposal.totalExpected) {
      return ValidationResult.fail(
        'Could not find slots for all sessions: placed $placed of ${proposal.totalExpected}.',
      );
    }

    // Warn on date-ordering conflicts around pinned sessions
    final warnings = <String>[];
    for (int i = 0; i < proposal.slots.length - 1; i++) {
      final curr = proposal.slots[i];
      final next = proposal.slots[i + 1];
      if (!curr.wasPinned && !next.wasPinned) continue;
      if (curr.newDate.compareTo(next.newDate) > 0) {
        warnings.add(
          'Session ${curr.sessionNumber} (${curr.newDate}) '
          'would occur after Session ${next.sessionNumber} (${next.newDate}). '
          'Review recommended.',
        );
      }
    }

    if (warnings.isNotEmpty) {
      return ValidationResult.withWarnings(warnings);
    }
    return const ValidationResult.ok();
  }

  /// Phase 3: Commit all DB writes.
  ///
  /// For each slot:
  ///   1. Update session date/time/status
  ///   2. Sync appointment via AppointmentSync
  ///
  /// After all sessions:
  ///   3. Increment schedule_version
  ///   4. Write audit log per session
  Future<void> _commitProposal(
    ScheduleProposal proposal,
    ValidationResult validation,
    SchedulingContext context,
  ) async {
    if (!proposal.slots.any((s) => !s.wasPinned)) {
      // All sessions were pinned — nothing to commit
      return;
    }

    for (final slot in proposal.slots) {
      if (slot.wasPinned) continue; // pinned sessions already committed separately

      try {
        // Update session
        final body = <String, dynamic>{
          'scheduled_date': slot.newDate,
          'scheduled_time': slot.newTime,
          'is_rescheduled': true,
        };
        if (slot.statusRestored) {
          body['status'] = 'upcoming';
        }
        await pb.collection(PBCollections.sessions).update(slot.sessionId, body: body);

        // Sync appointment
        final updatedRec =
            await pb.collection(PBCollections.sessions).getOne(slot.sessionId);
        final session = SessionModel.fromRecord(updatedRec);
        await appointmentSync.updateForSession(
          session: session,
          newDate: slot.newDate,
          newTime: slot.newTime,
          clinicId: context.clinicId,
          sessionType: proposal.sessionType,
        );
      } catch (e) {
        debugPrint('[TreatmentScheduler] commit slot error for ${slot.sessionId}: $e');
      }
    }

    // If interval was modified, persist to treatment_plans
    if (proposal.updatedIntervalDays != null && proposal.updatedIntervalDays! > 0) {
      try {
        await pb.collection(PBCollections.treatmentPlans).update(proposal.planId, body: {
          'interval_days': proposal.updatedIntervalDays,
        });
      } catch (e) {
        debugPrint('[TreatmentScheduler] update interval_days error: $e');
      }
    }

    // Increment schedule_version
    final newVersion = await lifecycle.incrementScheduleVersion(proposal.planId);

    // Emit audit logs
    for (final slot in proposal.slots) {
      if (slot.wasPinned) continue;
      await auditLogger.log(
        sessionId: slot.sessionId,
        planId: proposal.planId,
        action: slot.statusRestored ? 'rescheduled_after_miss' : 'rescheduled',
        oldDate: slot.oldDate,
        oldTime: slot.oldTime,
        newDate: slot.newDate,
        newTime: slot.newTime,
        reason: 'Scheduled by ${proposal.trigger}',
        trigger: proposal.trigger,
        performedBy: proposal.performedBy,
        scheduleVersion: newVersion,
        metadata: {
          if (validation.warnings.isNotEmpty) 'warnings': validation.warnings,
        },
      );
    }
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Load all sessions in a plan that are not yet completed/cancelled.
  Future<List<SessionModel>> _loadPendingSessions(
    String planId, {
    bool includeMissed = false,
  }) async {
    final filter = includeMissed
        ? 'treatment_plan = "$planId" && '
            '(status = "upcoming" || status = "missed" || status = "waiting" || status = "overdue" || status = "paused")'
        : 'treatment_plan = "$planId" && '
            '(status = "upcoming" || status = "waiting")';
    final res = await pb.collection(PBCollections.sessions).getList(
      filter: filter,
      sort: 'session_number',
      perPage: 200,
    );
    return res.items.map((r) => SessionModel.fromRecord(r)).toList();
  }

  /// Fetch the preferred time from the plan's earliest non-empty session time.
  Future<String> _loadPreferredTime(String planId) async {
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId"',
        sort: 'session_number',
        perPage: 5,
      );
      for (final r in res.items) {
        final t = r.getStringValue('scheduled_time');
        if (t.isNotEmpty) return t;
      }
    } catch (_) {}
    return '10:00';
  }

  Future<String> _loadSessionType(String planId) async {
    try {
      final rec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      return rec.getStringValue('treatment_type');
    } catch (_) {
      return 'session';
    }
  }

  Future<int> _currentVersion(String planId) async {
    try {
      final rec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      return rec.getIntValue('schedule_version');
    } catch (_) {
      return 1;
    }
  }
}
