import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart' show RescheduleMode;
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';

import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/features/scheduling/screens/available_slots_screen.dart';
import 'package:pms_app/features/scheduling/screens/scheduling_audit_history_screen.dart';
import 'package:pms_app/features/treatments/widgets/cascade_preview_sheet.dart';
import 'package:pms_app/features/appointments/widgets/conflict_warning_dialog.dart';

class SessionListScreen extends ConsumerStatefulWidget {
  final TreatmentPlanModel plan;

  const SessionListScreen({super.key, required this.plan});

  @override
  ConsumerState<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends ConsumerState<SessionListScreen> {
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _isPaused = widget.plan.isPaused;
    Future.microtask(() {
      ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
    });
  }

  String get _currentUserId => ref.read(authProvider).userId ?? 'system';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionsProvider);
    final completedCount = state.sessions
        .where((s) => s.status == SessionStatus.completed)
        .length;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final header = Padding(
              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.plan.treatmentType,
                          style: context.textStyles.h2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.plan.totalSessions} Sessions • Every ${widget.plan.intervalDays} Day${widget.plan.intervalDays > 1 ? "s" : ""} • ₹${widget.plan.sessionFee.toInt()}/session',
                          style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.plan.patientName ?? 'Patient',
                          style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                        ),
                      ],
                    ),
                  ),
                  // Audit history icon
                  IconButton(
                    tooltip: 'Schedule History',
                    icon: Icon(Icons.history_rounded, size: 22, color: context.colors.textSecondary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SchedulingAuditHistoryScreen(plan: widget.plan),
                      ),
                    ),
                  ),
                  // ⋮ menu with Close Treatment
                  if (widget.plan.status != TreatmentPlanStatus.completed &&
                      widget.plan.status != TreatmentPlanStatus.closed)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: context.colors.textSecondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'close') _closeTreatment();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'close',
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, size: 18, color: context.colors.error),
                              const SizedBox(width: 10),
                              Text('Close Treatment',
                                  style: TextStyle(color: context.colors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  // Pause / Resume button
                  if (widget.plan.status != TreatmentPlanStatus.completed &&
                      widget.plan.status != TreatmentPlanStatus.closed)
                    _buildPauseResumeButton(),
                ],
              ),
            );

            final isPausedOrReview = widget.plan.status == TreatmentPlanStatus.paused || widget.plan.status == TreatmentPlanStatus.manualReview;
            
            final statusContextRow = isPausedOrReview ? Container(
              margin: EdgeInsets.only(top: 16, left: isDesktop ? 0 : 24, right: isDesktop ? 0 : 24),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.plan.status == TreatmentPlanStatus.paused 
                    ? context.colors.warning.withValues(alpha: 0.1)
                    : context.colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.plan.status == TreatmentPlanStatus.paused 
                    ? context.colors.warning.withValues(alpha: 0.3)
                    : context.colors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.plan.status == TreatmentPlanStatus.paused ? Icons.pause_circle_outline : Icons.warning_amber_rounded,
                    size: 18,
                    color: widget.plan.status == TreatmentPlanStatus.paused ? context.colors.warning : context.colors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.plan.status == TreatmentPlanStatus.paused
                          ? 'Paused${widget.plan.pausedAt != null ? " on " + DateFormat('dd MMM yyyy').format(DateTime.parse(widget.plan.pausedAt!).toLocal()) : ""}${widget.plan.closureReason?.isNotEmpty == true ? " • Reason: " + widget.plan.closureReason! : ""}'
                          : 'Manual Review${widget.plan.closureReason?.isNotEmpty == true ? " • " + widget.plan.closureReason! : ""}',
                      style: context.textStyles.caption.copyWith(
                        color: widget.plan.status == TreatmentPlanStatus.paused ? context.colors.warning : context.colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ) : const SizedBox.shrink();

            final progressBar = Padding(
              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completedCount of ${widget.plan.totalSessions} Sessions Completed',
                        style: context.textStyles.label.copyWith(fontSize: 13),
                      ),
                      if (widget.plan.scheduleVersion > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v${widget.plan.scheduleVersion}',
                            style: context.textStyles.caption.copyWith(
                              color: context.colors.info,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: widget.plan.totalSessions > 0
                          ? completedCount / widget.plan.totalSessions
                          : 0,
                      backgroundColor: context.colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.colors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );

            final listContent = state.isLoading
                ? Center(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : state.sessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No sessions found',
                        style: context.textStyles.bodyMedium.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: isDesktop,
                    physics: isDesktop ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                    padding: isDesktop
                        ? const EdgeInsets.symmetric(vertical: 16)
                        : const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: state.sessions.length,
                    itemBuilder: (context, index) {
                      return _sessionCard(state.sessions[index], isLast: index == state.sessions.length - 1);
                    },
                  );

            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadowColor.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          if (isPausedOrReview) statusContextRow,
                          const SizedBox(height: 24),
                          progressBar,
                          const SizedBox(height: 24),
                          listContent,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return Column(
                children: [
                  header,
                  if (isPausedOrReview) statusContextRow,
                  const SizedBox(height: 16),
                  progressBar,
                  const SizedBox(height: 16),
                  Expanded(child: listContent),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildPlanStatusBadge(TreatmentPlanStatus status) {
    final (label, color, icon) = switch (status) {
      TreatmentPlanStatus.active      => ('Active', context.colors.success, Icons.check_circle_outline),
      TreatmentPlanStatus.paused      => ('Paused', context.colors.warning, Icons.pause_circle_outline),
      TreatmentPlanStatus.manualReview=> ('Manual Review', context.colors.error, Icons.sync_problem_rounded),
      TreatmentPlanStatus.completed   => ('Completed', context.colors.primary, Icons.verified_rounded),
      TreatmentPlanStatus.closed      => ('Closed', context.colors.textSecondary, Icons.cancel_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textStyles.caption.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(SessionModel session, {bool isLast = false}) {
    final statusColor = _statusColor(session.status);
    final now = DateTime.now();
    final scheduledDt = DateTime.tryParse(session.scheduledDate);
    final isPast = scheduledDt?.isBefore(now) ?? false;
    final isFuture = scheduledDt != null &&
        DateTime(scheduledDt.year, scheduledDt.month, scheduledDt.day)
            .isAfter(DateTime(now.year, now.month, now.day));
    final canRecord = session.status == SessionStatus.upcoming && isPast;

    String dateLabel = '';
    if (scheduledDt != null) {
      dateLabel = DateFormat('EEE, MMM d').format(scheduledDt);
    }

    void navigateToRecord(SessionModel session) {
      Navigator.pushNamed(context, '/sessions/record', arguments: session).then(
        (_) {
          ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
        },
      );
    }

    final isActive = session.status == SessionStatus.upcoming ||
        session.status == SessionStatus.inProgress ||
        session.status == SessionStatus.waiting;

    return GestureDetector(
      onTap: () {
        if (!isActive) return;
        if (scheduledDt != null) {
          final schedDay = DateTime(scheduledDt.year, scheduledDt.month, scheduledDt.day);
          final today = DateTime(now.year, now.month, now.day);
          if (schedDay != today) {
            if (isFuture) {
              // V-5 fix: Block recording future sessions
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Session Not Due Yet'),
                  content: Text(
                    'This session is scheduled for ${DateFormat('EEE, MMM d').format(scheduledDt)}. '
                    'You cannot record it before its scheduled date.\n\nYou can reschedule it if needed.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _rescheduleSessionFromList(session);
                      },
                      child: Text('Reschedule', style: TextStyle(color: context.colors.primary)),
                    ),
                  ],
                ),
              );
            } else {
              // Past date mismatch — allow with confirmation
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Date Mismatch'),
                  content: const Text(
                    'This session is not scheduled for today. Are you sure you want to record it now?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        navigateToRecord(session);
                      },
                      child: Text(
                        'Proceed',
                        style: TextStyle(color: context.colors.primary),
                      ),
                    ),
                  ],
                ),
              );
            }
          } else {
            navigateToRecord(session);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canRecord
                ? context.colors.primary.withValues(alpha: 0.4)
                : context.colors.border,
          ),
          boxShadow: canRecord
              ? [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Session number circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#${session.sessionNumber}',
                  style: context.textStyles.label.copyWith(
                    color: statusColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session ${session.sessionNumber}',
                    style: context.textStyles.label.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.treatmentModality.isNotEmpty
                        ? session.treatmentModality
                        : widget.plan.treatmentType,
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(dateLabel, style: context.textStyles.caption),
                      // Missed session: show original date if rescheduled
                      if (session.isRescheduled && session.originalDate != null &&
                          session.originalDate!.isNotEmpty &&
                          session.originalDate != session.scheduledDate) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(was ${DateFormat('MMM d').format(DateTime.parse(session.originalDate!))})',
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.textHint,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (session.rescheduleCount > 0)
                    Text(
                      'Rescheduled ${session.rescheduleCount}×',
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.warning,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            // Badges
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(session.status),
                    style: context.textStyles.caption.copyWith(
                      color: statusColor,
                      fontSize: 11,
                    ),
                  ),
                ),
                // Pinned badge 📌
                if (session.isPinned) ...[
                  const SizedBox(width: 5),
                  Tooltip(
                    message: 'Pinned — protected from auto-rescheduling',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.push_pin_rounded, size: 10, color: const Color(0xFF8B5CF6)),
                        const SizedBox(width: 2),
                        Text('P', style: context.textStyles.caption.copyWith(
                          color: const Color(0xFF8B5CF6), fontSize: 9, fontWeight: FontWeight.w700,
                        )),
                      ]),
                    ),
                  ),
                ],
                // Rescheduled badge
                if (session.isRescheduled) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_repeat_rounded, size: 10, color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text('R', style: context.textStyles.caption.copyWith(
                        color: const Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w700,
                      )),
                    ]),
                  ),
                ],
              ],
            ),
            // Per-session action menu (upcoming/missed sessions only)
            if (isActive || session.status == SessionStatus.missed) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: context.colors.textHint),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'reschedule') _rescheduleSessionFromList(session);
                  if (v == 'pin') _togglePin(session);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'reschedule',
                    child: Row(
                      children: [
                        Icon(Icons.event_repeat_rounded, size: 16, color: context.colors.primary),
                        const SizedBox(width: 10),
                        Text('Reschedule', style: TextStyle(color: context.colors.textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          session.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                          size: 16,
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          session.isPinned ? 'Unpin Session' : 'Pin Session',
                          style: const TextStyle(color: Color(0xFF8B5CF6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else if (isActive) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textHint,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:
        return context.colors.info;
      case SessionStatus.waiting:
        return context.colors.warning;
      case SessionStatus.inProgress:
        return const Color(0xFFF59E0B);
      case SessionStatus.completed:
        return context.colors.success;
      case SessionStatus.missed:
        return context.colors.warning;
      case SessionStatus.cancelled:
        return context.colors.error;
      case SessionStatus.paused:
        return context.colors.info;
    }
  }

  String _statusLabel(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:
        return 'Upcoming';
      case SessionStatus.waiting:
        return 'Waiting';
      case SessionStatus.inProgress:
        return 'Ongoing';
      case SessionStatus.completed:
        return 'Done';
      case SessionStatus.missed:
        return 'Missed';
      case SessionStatus.cancelled:
        return 'Cancelled';
      case SessionStatus.paused:
        return 'Paused';
    }
  }

  // ─── Per-session reschedule from session list ─────────────────────────────

  Future<void> _rescheduleSessionFromList(SessionModel session) async {
    // Navigate to available slots picker and get result
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: widget.plan.doctorId,
          treatmentDuration: 30,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final newDate = DateFormat('yyyy-MM-dd').format(result['date'] as DateTime);
    final newTime = result['time'] as String;

    // Ask cascade mode
    final mode = await _askCascadeMode();
    if (mode == null || !mounted) return;

    try {
      if (mode == RescheduleMode.cascadeAll) {
        final lifecycle = ref.read(sessionLifecycleServiceProvider);
        final preview = await lifecycle.previewRescheduleSessionAndCascade(
          sessionId: session.id,
          newDate: newDate,
          newTime: newTime,
          performedBy: _currentUserId,
        );
        
        if (!mounted) return;
        
        final confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight),
            child: CascadePreviewSheet(
              preview: preview,
              onConfirm: () => Navigator.pop(ctx, true),
              onCancel: () => Navigator.pop(ctx, false),
            ),
          ),
        );
        
        if (confirmed != true || !mounted) return;
        
        await lifecycle.commitRescheduleProposal(preview);
        
        if (mounted) {
          final conflicts = preview.proposal.totalExpected - preview.proposal.slots.where((s) => !s.wasPinned).length;
          if (conflicts > 0) {
            showDialog(
              context: context,
              builder: (ctx) => ConflictWarningDialog(
                successfulMoves: preview.proposal.slots.where((s) => s.oldDate != s.newDate && !s.wasPinned).length,
                skippedSessions: preview.proposal.slots.where((s) => s.wasPinned && !s.isTarget).length,
                totalConflicts: conflicts,
              ),
            );
          } else {
            AppToast.show('Reschedule cascade complete ✓', type: ToastType.success);
          }
        }
      } else {
        final service = ref.read(treatmentServiceProvider);
        await service.rescheduleSession(
          sessionId: session.id,
          newDate: newDate,
          newTime: newTime,
          performedBy: _currentUserId,
          mode: mode,
        );
        if (mounted) {
          AppToast.show('Session rescheduled (others unchanged) ✓', type: ToastType.success);
        }
      }
      ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
    } catch (e) {
      if (mounted) AppToast.show('Failed to reschedule: $e', type: ToastType.error);
    }
  }

  Future<RescheduleMode?> _askCascadeMode() => showDialog<RescheduleMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: context.colors.surface,
      title: Text('Reschedule Future Sessions?', style: context.textStyles.h3),
      content: Text(
        'Do you want to shift all upcoming sessions forward to keep the same spacing?',
        style: context.textStyles.bodyMedium,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, RescheduleMode.cascadeAll),
          child: const Text('Shift All Upcoming'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, RescheduleMode.missedOnly),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Only This Session'),
        ),
      ],
    ),
  );

  // ─── Pin / Unpin session ─────────────────────────────────────────────────

  Future<void> _togglePin(SessionModel session) async {
    try {
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      await lifecycle.togglePinSession(
        sessionId: session.id,
        planId: widget.plan.id,
        isPinned: !session.isPinned,
        scheduleVersion: widget.plan.scheduleVersion,
        performedBy: _currentUserId,
      );
      ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
      if (mounted) {
        AppToast.show(
          session.isPinned ? 'Session unpinned' : 'Session pinned 📌',
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (mounted) AppToast.show('Failed: $e', type: ToastType.error);
    }
  }

  // ─── Close Treatment ─────────────────────────────────────────────────────

  Future<void> _closeTreatment() async {
    final reason = await showClosureReasonDialog(
      context,
      patientName: widget.plan.patientName ?? 'Patient',
    );
    if (reason == null || !mounted) return;

    try {
      final service = ref.read(treatmentServiceProvider);
      await service.closeTreatment(
        widget.plan.id,
        reason: reason,
        performedBy: _currentUserId,
      );
      if (mounted) {
        AppToast.show('Treatment closed ✓', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppToast.show('Failed to close: $e', type: ToastType.error);
    }
  }

  // ─── Pause / Resume ─────────────────────────────────────────────────────

  Widget _buildPauseResumeButton() {
    return GestureDetector(
      onTap: _isPaused ? _showResumeDialog : _pauseSessions,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _isPaused
              ? context.colors.success.withValues(alpha: 0.12)
              : context.colors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isPaused
                ? context.colors.success.withValues(alpha: 0.3)
                : context.colors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          size: 20,
          color: _isPaused ? context.colors.success : context.colors.warning,
        ),
      ),
    );
  }

  Future<void> _pauseSessions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.colors.surface,
        title: Row(children: [
          Icon(Icons.pause_circle_rounded, color: context.colors.warning, size: 24),
          const SizedBox(width: 10),
          Text('Pause Sessions?', style: context.textStyles.h3),
        ]),
        content: Text(
          'All upcoming sessions will be paused and removed from the schedule.\n\nYou can resume them at any time.',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: const Text('Pause'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final service = ref.read(treatmentServiceProvider);
      await service.pauseSessions(widget.plan.id, performedBy: _currentUserId);
      ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
      if (mounted) {
        setState(() => _isPaused = true);
        AppToast.show('Sessions paused ⏸');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to pause: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _showResumeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.colors.surface,
        title: Row(children: [
          Icon(Icons.play_circle_rounded, color: context.colors.success, size: 24),
          const SizedBox(width: 10),
          Text('Resume Sessions', style: context.textStyles.h3),
        ]),
        content: Text(
          'How would you like to resume?\n\n'
          '• Continue — picks up from where you left off\n'
          '• Start from first — redo from the first paused session\n\n'
          'Completed sessions are never redone.',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'first'),
            icon: Icon(Icons.first_page_rounded, size: 18, color: context.colors.primary),
            label: Text('Start from First', style: TextStyle(color: context.colors.primary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final service = ref.read(treatmentServiceProvider);
      await service.resumeSessions(
        widget.plan.id,
        startFromFirst: result == 'first',
        performedBy: _currentUserId,
      );
      ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
      if (mounted) {
        setState(() => _isPaused = false);
        AppToast.show('Sessions resumed ▶', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to resume: $e', type: ToastType.error);
      }
    }
  }
}

// ─── Shared Closure Reason Dialog ────────────────────────────────────────────
/// Exported so patient_profile and auto_scheduling_dashboard can reuse it.
Future<ClosureReason?> showClosureReasonDialog(
  BuildContext context, {
  required String patientName,
}) async {
  ClosureReason selected = ClosureReason.discontinued;

  return showDialog<ClosureReason>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final colors = ctx.colors;
        final textStyles = ctx.textStyles;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: colors.surface,
          title: Row(
            children: [
              Icon(Icons.cancel_outlined, color: colors.error, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Close Treatment', style: textStyles.h3, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select reason for closing $patientName\'s plan. All remaining sessions will be cancelled.',
                style: textStyles.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...ClosureReason.values.map((r) => RadioListTile<ClosureReason>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: r,
                groupValue: selected,
                activeColor: colors.error,
                title: Text(_closureReasonLabel(r), style: textStyles.bodyMedium),
                onChanged: (v) { if (v != null) setS(() => selected = v); },
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Close Treatment'),
            ),
          ],
        );
      },
    ),
  );
}

String _closureReasonLabel(ClosureReason r) {
  switch (r) {
    case ClosureReason.completed:      return 'Treatment Completed';
    case ClosureReason.discontinued:   return 'Doctor Discontinued';
    case ClosureReason.patientStopped: return 'Patient Chose to Stop';
    case ClosureReason.medicalDecision:return 'Medical Decision';
    case ClosureReason.financial:      return 'Financial / Billing Issue';
  }
}
