import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/session_model.dart';
import '../models/treatment_plan_model.dart';
import '../providers/treatment_provider.dart';

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
      backgroundColor: AppColors.background,
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
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
                          style: AppTextStyles.h2,
                        ),
                        Text(
                          widget.plan.patientName ?? 'Patient',
                          style: AppTextStyles.caption,
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: AppTextStyles.label.copyWith(fontSize: 13),
                        ),
                        Text(
                          '$completedCount / ${widget.plan.totalSessions} sessions',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
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
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
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
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          '₹${widget.plan.sessionFee.toInt()} / session',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Session list
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    )
                  : state.sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions found',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
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
        if (session.status == SessionStatus.upcoming) {
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
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      navigateToRecord(session);
                    },
                    child: const Text(
                      'Proceed',
                      style: TextStyle(color: AppColors.primary),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canRecord
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
          boxShadow: canRecord
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
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
                  style: AppTextStyles.label.copyWith(
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
                    style: AppTextStyles.label.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(dateLabel, style: AppTextStyles.caption),
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
                style: AppTextStyles.caption.copyWith(
                  color: statusColor,
                  fontSize: 11,
                ),
              ),
            ),
            if (session.status == SessionStatus.upcoming) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
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
        return AppColors.info;
      case SessionStatus.waiting:
        return AppColors.warning;
      case SessionStatus.completed:
        return AppColors.success;
      case SessionStatus.missed:
        return AppColors.warning;
      case SessionStatus.cancelled:
        return AppColors.error;
    }
  }

  String _statusLabel(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:
        return 'Upcoming';
      case SessionStatus.waiting:
        return 'Waiting';
      case SessionStatus.completed:
        return 'Done';
      case SessionStatus.missed:
        return 'Missed';
      case SessionStatus.cancelled:
        return 'Cancelled';
    }
  }
}
