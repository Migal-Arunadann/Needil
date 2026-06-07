import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';
import '../models/treatment_plan_model.dart';
import '../providers/treatment_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';


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
                        Text(
                          widget.plan.patientName ?? 'Patient',
                          style: context.textStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  // Pause / Resume button
                  if (widget.plan.status != TreatmentPlanStatus.completed)
                    _buildPauseResumeButton(),
                ],
              ),
            );

            final progressBar = Padding(
              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: context.textStyles.label.copyWith(fontSize: 13),
                        ),
                        Text(
                          '$completedCount / ${widget.plan.totalSessions} sessions',
                          style: context.textStyles.label.copyWith(
                            color: context.colors.primary,
                            fontSize: 13,
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
                        backgroundColor: context.colors.primary.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Every ${widget.plan.intervalDays} days',
                          style: context.textStyles.caption,
                        ),
                        Text(
                          '₹${widget.plan.sessionFee.toInt()} / session',
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                : ListView.separated(
                    shrinkWrap: isDesktop,
                    physics: isDesktop ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                    padding: isDesktop
                        ? const EdgeInsets.symmetric(vertical: 16)
                        : const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: state.sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _sessionCard(state.sessions[index]);
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
                            color: Colors.black.withValues(alpha: 0.2),
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

  Widget _sessionCard(SessionModel session) {
    final statusColor = _statusColor(session.status);
    final isPast =
        DateTime.tryParse(session.scheduledDate)?.isBefore(DateTime.now()) ??
        false;
    final canRecord = session.status == SessionStatus.upcoming && isPast;

    String dateLabel = '';
    final date = DateTime.tryParse(session.scheduledDate);
    if (date != null) {
      dateLabel = DateFormat('EEE, MMM d').format(date);
    }

    void navigateToRecord(SessionModel session) {
      Navigator.pushNamed(context, '/sessions/record', arguments: session).then(
        (_) {
          ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
        },
      );
    }

    return GestureDetector(
      onTap: () {
        if (session.status == SessionStatus.upcoming ||
            session.status == SessionStatus.inProgress ||
            session.status == SessionStatus.waiting) {
          final dt = DateTime.tryParse(session.scheduledDate);
          final now = DateTime.now();
          // PocketBase dates might be UTC; simple local day check:
          if (dt != null &&
              (dt.toLocal().year != now.year ||
                  dt.toLocal().month != now.month ||
                  dt.toLocal().day != now.day)) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
            // Session number
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
                  Text(dateLabel, style: context.textStyles.caption),
                ],
              ),
            ),
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
            // Rescheduled indicator
            if (session.isRescheduled) ...[
              const SizedBox(width: 6),
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
            if (session.status == SessionStatus.upcoming ||
                session.status == SessionStatus.inProgress ||
                session.status == SessionStatus.waiting) ...[
              SizedBox(width: 6),
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

  // ─── Pause / Resume ─────────────────────────────────────────

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
      await service.pauseSessions(widget.plan.id);
      ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
      if (mounted) {
        setState(() => _isPaused = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Sessions paused ⏸'),
          backgroundColor: context.colors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to pause: $e'),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
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
      );
      ref.read(sessionsProvider.notifier).loadPlanSessions(widget.plan.id);
      if (mounted) {
        setState(() => _isPaused = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Sessions resumed ▶'),
          backgroundColor: context.colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to resume: $e'),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }
}