import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reason label shown per-plan card in the manual review dashboard.
String _reviewReasonLabel(TreatmentPlanModel plan) {
  if (plan.status == TreatmentPlanStatus.paused) {
    return 'Plan Paused';
  }
  if (plan.consecutiveMisses >= 3) {
    return '${plan.consecutiveMisses} Consecutive Misses';
  }
  final lastActivity = plan.lastActivityAt;
  if (lastActivity != null) {
    final daysSince = DateTime.now().difference(lastActivity).inDays;
    if (daysSince >= plan.expiryDays) {
      return 'Inactive for $daysSince days (expired)';
    }
  }
  if (plan.status == TreatmentPlanStatus.manualReview) {
    return 'No available slots found';
  }
  return 'Manual Review Required';
}

Color _reviewReasonColor(TreatmentPlanModel plan, BuildContext context) {
  if (plan.status == TreatmentPlanStatus.paused) return context.colors.warning;
  if (plan.consecutiveMisses >= 3) return context.colors.error;
  final lastActivity = plan.lastActivityAt;
  if (lastActivity != null) {
    final daysSince = DateTime.now().difference(lastActivity).inDays;
    if (daysSince >= plan.expiryDays) return context.colors.warning;
  }
  if (plan.status == TreatmentPlanStatus.manualReview) return context.colors.error;
  return context.colors.textSecondary;
}

IconData _reviewReasonIcon(TreatmentPlanModel plan) {
  if (plan.status == TreatmentPlanStatus.paused) return Icons.pause_circle_outline_rounded;
  if (plan.consecutiveMisses >= 3) return Icons.warning_amber_rounded;
  final lastActivity = plan.lastActivityAt;
  if (lastActivity != null) {
    final daysSince = DateTime.now().difference(lastActivity).inDays;
    if (daysSince >= plan.expiryDays) return Icons.hourglass_empty_rounded;
  }
  if (plan.status == TreatmentPlanStatus.manualReview) return Icons.event_busy_rounded;
  return Icons.info_outline_rounded;
}

class AutoSchedulingDashboard extends ConsumerStatefulWidget {
  final List<TreatmentPlanModel> initialPlans;
  final VoidCallback onRefresh;

  const AutoSchedulingDashboard({
    super.key,
    required this.initialPlans,
    required this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TreatmentPlanModel> plans,
    required VoidCallback onRefresh,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AutoSchedulingDashboard(
        initialPlans: plans,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  ConsumerState<AutoSchedulingDashboard> createState() => _AutoSchedulingDashboardState();
}

class _AutoSchedulingDashboardState extends ConsumerState<AutoSchedulingDashboard> {
  late List<TreatmentPlanModel> _plans;
  bool _isProcessing = false;
  String? _processingPlanId;
  String? _globalProcessingText;

  @override
  void initState() {
    super.initState();
    _plans = List.from(widget.initialPlans);
  }

  String get _currentUserId => ref.read(authProvider).userId ?? 'system';

  /// Auto-reschedule a single plan. Keeps it in the list if no slot was found.
  Future<void> _reschedulePlan(TreatmentPlanModel plan) async {
    setState(() {
      _isProcessing = true;
      _processingPlanId = plan.id;
    });

    try {
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      await lifecycle.autoRescheduleForPlan(plan.id);

      if (mounted) {
        AppToast.show('Session(s) auto-rescheduled for ${plan.patientName ?? "Patient"}.', type: ToastType.success);
        setState(() => _plans.removeWhere((p) => p.id == plan.id));
        widget.onRefresh();
        if (_plans.isEmpty) Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('no slot') || msg.contains('noslot')) {
          AppToast.show(
            'No available slots found for ${plan.patientName ?? "Patient"}. Plan remains in Manual Review.',
            type: ToastType.error,
          );
          // Keep the plan card in the list — don't remove it.
        } else {
          AppToast.show('Failed to reschedule: $e', type: ToastType.error);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingPlanId = null;
        });
      }
    }
  }

  /// V-4 fix: Only show Pause Plan when plan is NOT in manual_review status.
  /// manual_review → paused is an invalid state transition in the engine.
  /// Instead, we offer a "Close Treatment" action.
  Future<void> _closePlan(TreatmentPlanModel plan) async {
    final reason = await _showClosureReasonDialog(
      context,
      patientName: plan.patientName ?? 'Patient',
    );
    if (reason == null || !mounted) return;

    setState(() {
      _isProcessing = true;
      _processingPlanId = plan.id;
    });

    try {
      final treatmentService = ref.read(treatmentServiceProvider);
      await treatmentService.closeTreatment(
        plan.id,
        reason: reason,
        performedBy: _currentUserId,
      );
      if (mounted) {
        AppToast.show('Treatment plan closed for ${plan.patientName ?? "Patient"}.', type: ToastType.success);
        setState(() => _plans.removeWhere((p) => p.id == plan.id));
        widget.onRefresh();
        if (_plans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.show('Failed to close plan: $e', type: ToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingPlanId = null;
        });
      }
    }
  }

  Future<void> _pausePlan(TreatmentPlanModel plan) async {
    setState(() {
      _isProcessing = true;
      _processingPlanId = plan.id;
    });

    try {
      final treatmentService = ref.read(treatmentServiceProvider);
      await treatmentService.pauseSessions(plan.id, performedBy: _currentUserId);

      if (mounted) {
        AppToast.show('Sessions for ${plan.patientName ?? "Patient"} have been paused.');
        setState(() => _plans.removeWhere((p) => p.id == plan.id));
        widget.onRefresh();
        if (_plans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to pause plan: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingPlanId = null;
        });
      }
    }
  }

  Future<void> _rescheduleAll() async {
    setState(() {
      _isProcessing = true;
      _globalProcessingText = 'Rescheduling all patients...';
    });

    final lifecycle = ref.read(sessionLifecycleServiceProvider);
    int successCount = 0;
    int failCount = 0;

    for (final plan in List<TreatmentPlanModel>.from(_plans)) {
      try {
        await lifecycle.autoRescheduleForPlan(plan.id);
        successCount++;
        setState(() => _plans.removeWhere((p) => p.id == plan.id));
      } catch (e) {
        failCount++;
        debugPrint('Error rescheduling plan ${plan.id}: $e');
      }
    }

    if (mounted) {
      if (failCount == 0) {
        AppToast.show('Successfully rescheduled $successCount patient(s).', type: ToastType.success);
        widget.onRefresh();
        Navigator.of(context).pop();
      } else {
        final toastType = successCount == 0 ? ToastType.error : ToastType.warning;
        AppToast.show(
          '$successCount rescheduled, $failCount failed.',
          type: toastType,
        );
        widget.onRefresh();
        setState(() {
          _isProcessing = false;
          _globalProcessingText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: context.colors.background,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: isMobile ? width * 0.95 : 650,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.warning.withValues(alpha: 0.15),
                    context.colors.warning.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: context.colors.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.colors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.sync_problem_rounded,
                      color: context.colors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual Review Required',
                          style: context.textStyles.h2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_plans.length} plan(s) need your attention',
                          style: context.textStyles.bodySmall.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.colors.textSecondary),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            if (_globalProcessingText != null)
              Container(
                color: context.colors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _globalProcessingText!,
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Content List
            Flexible(
              child: _plans.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 64,
                            color: context.colors.success,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'All set!',
                            style: context.textStyles.h3,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No plans require manual review.',
                            style: context.textStyles.bodyMedium.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      shrinkWrap: true,
                      itemCount: _plans.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        final isItemProcessing = _isProcessing && _processingPlanId == plan.id;
                        final isInManualReview = plan.status == TreatmentPlanStatus.manualReview;
                        final reasonLabel = _reviewReasonLabel(plan);
                        final reasonColor = _reviewReasonColor(plan, context);
                        final reasonIcon = _reviewReasonIcon(plan);

                        return Container(
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.colors.border.withValues(alpha: 0.7),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.textPrimary.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.patientName ?? 'Patient',
                                          style: context.textStyles.h3,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          plan.treatmentType,
                                          style: context.textStyles.bodyMedium.copyWith(
                                            color: context.colors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (plan.patientPhone != null && plan.patientPhone!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: InkWell(
                                              onTap: () async {
                                                final uri = Uri(scheme: 'tel', path: plan.patientPhone);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri);
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.phone_rounded,
                                                    size: 13,
                                                    color: context.colors.success,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    plan.patientPhone!,
                                                    style: context.textStyles.caption.copyWith(
                                                      color: context.colors.success,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Reason badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: reasonColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          reasonIcon,
                                          size: 14,
                                          color: reasonColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          reasonLabel,
                                          style: context.textStyles.caption.copyWith(
                                            color: reasonColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Description based on reason
                              Text(
                                plan.consecutiveMisses >= 3
                                    ? 'Patient has missed ${plan.consecutiveMisses} consecutive sessions. Auto-rescheduling is on hold.'
                                    : 'This plan requires manual attention before auto-scheduling can continue.',
                                style: context.textStyles.bodySmall.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Actions Row
                              if (isItemProcessing)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // V-4 fix: Show Pause only for active plans; show Close for manual_review plans.
                                    if (isInManualReview)
                                      TextButton.icon(
                                        onPressed: _isProcessing ? null : () => _closePlan(plan),
                                        icon: Icon(
                                          Icons.cancel_outlined,
                                          color: context.colors.error,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'Close Treatment',
                                          style: TextStyle(
                                            color: context.colors.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      )
                                    else
                                      TextButton.icon(
                                        onPressed: _isProcessing ? null : () => _pausePlan(plan),
                                        icon: Icon(
                                          Icons.pause_circle_outline_rounded,
                                          color: context.colors.error,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'Pause Plan',
                                          style: TextStyle(
                                            color: context.colors.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    // Auto-Reschedule Action
                                    ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : () => _reschedulePlan(plan),
                                      icon: const Icon(
                                        Icons.autorenew_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Auto-Reschedule'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: context.colors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            if (_plans.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(
                      color: context.colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Decide Later',
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _rescheduleAll,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Reschedule All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Closure Reason Dialog ────────────────────────────────────────────────────

/// Shows a dialog asking the user to pick a closure reason.
/// Returns null if cancelled.
Future<ClosureReason?> _showClosureReasonDialog(
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
                child: Text(
                  'Close Treatment',
                  style: textStyles.h3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select the reason for closing $patientName\'s treatment plan. All remaining sessions will be cancelled.',
                style: textStyles.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...ClosureReason.values.map((r) {
                return RadioListTile<ClosureReason>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: r,
                  groupValue: selected,
                  activeColor: colors.error,
                  title: Text(_closureReasonLabel(r), style: textStyles.bodyMedium),
                  onChanged: (v) {
                    if (v != null) setS(() => selected = v);
                  },
                );
              }),
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
    case ClosureReason.completed:
      return 'Treatment Completed';
    case ClosureReason.discontinued:
      return 'Doctor Discontinued';
    case ClosureReason.patientStopped:
      return 'Patient Chose to Stop';
    case ClosureReason.medicalDecision:
      return 'Medical Decision';
    case ClosureReason.financial:
      return 'Financial / Billing Issue';
  }
}
