import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/session_lifecycle_service.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';

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

  Future<void> _reschedulePlan(TreatmentPlanModel plan) async {
    setState(() {
      _isProcessing = true;
      _processingPlanId = plan.id;
    });

    try {
      final pb = ref.read(pocketbaseProvider);
      final lifecycle = SessionLifecycleService(pb);
      final results = await lifecycle.autoRescheduleForPlan(plan.id);

      if (mounted) {
        AppToast.show(results.isNotEmpty
                ? 'Rescheduled: ${results.length} session(s) moved to new slots.'
                : 'Session auto-rescheduled successfully.', type: ToastType.success);

        setState(() {
          _plans.removeWhere((p) => p.id == plan.id);
        });
        widget.onRefresh();

        if (_plans.isEmpty) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to reschedule: $e', type: ToastType.error);
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

  Future<void> _pausePlan(TreatmentPlanModel plan) async {
    setState(() {
      _isProcessing = true;
      _processingPlanId = plan.id;
    });

    try {
      final treatmentService = ref.read(treatmentServiceProvider);
      await treatmentService.pauseSessions(plan.id);

      if (mounted) {
        AppToast.show('Sessions for ${plan.patientName ?? "Patient"} have been paused.');

        setState(() {
          _plans.removeWhere((p) => p.id == plan.id);
        });
        widget.onRefresh();

        if (_plans.isEmpty) {
          Navigator.of(context).pop();
        }
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

    final pb = ref.read(pocketbaseProvider);
    final lifecycle = SessionLifecycleService(pb);
    int successCount = 0;

    for (final plan in List<TreatmentPlanModel>.from(_plans)) {
      try {
        await lifecycle.autoRescheduleForPlan(plan.id);
        successCount++;
        setState(() {
          _plans.removeWhere((p) => p.id == plan.id);
        });
      } catch (e) {
        debugPrint('Error rescheduling plan ${plan.id}: $e');
      }
    }

    if (mounted) {
      AppToast.show('Successfully rescheduled $successCount patient(s).', type: ToastType.success);
      widget.onRefresh();
      Navigator.of(context).pop();
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
                          'Auto-Scheduling Action Required',
                          style: context.textStyles.h2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_plans.length} patient(s) reached 3+ consecutive misses',
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
                            'No pending auto-rescheduling actions required.',
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
                                      ],
                                    ),
                                  ),
                                  // Miss count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 14,
                                          color: context.colors.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${plan.consecutiveMisses} Misses',
                                          style: context.textStyles.caption.copyWith(
                                            color: context.colors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Description
                              Text(
                                'Patient has missed multiple consecutive appointments. Auto-rescheduling is on hold until you approve or pause.',
                                style: context.textStyles.bodySmall.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Actions Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Pause Action
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
                                  // Reschedule Action
                                  ElevatedButton.icon(
                                    onPressed: _isProcessing ? null : () => _reschedulePlan(plan),
                                    icon: isItemProcessing
                                        ? SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Icon(
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
