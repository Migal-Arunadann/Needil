import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
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
  @override
  void initState() {
    super.initState();
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
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    SizedBox(height: 8),
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
            ),
            SizedBox(height: 16),

            // Session list
            Expanded(
              child: state.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.colors.primary,
                        strokeWidth: 3,
                      ),
                    )
                  : state.sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions found',
                        style: context.textStyles.bodyMedium.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      itemCount: state.sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _sessionCard(state.sessions[index]);
                      },
                    ),
            ),
          ],
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
    }
  }
}