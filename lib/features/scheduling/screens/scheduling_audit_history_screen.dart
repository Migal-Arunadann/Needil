import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/core/utils/time_utils.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';

class SchedulingAuditHistoryScreen extends ConsumerStatefulWidget {
  final TreatmentPlanModel plan;

  const SchedulingAuditHistoryScreen({super.key, required this.plan});

  @override
  ConsumerState<SchedulingAuditHistoryScreen> createState() =>
      _SchedulingAuditHistoryScreenState();
}

class _SchedulingAuditHistoryScreenState
    extends ConsumerState<SchedulingAuditHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final pb = ref.read(pocketbaseProvider);
      final result = await pb
          .collection(PBCollections.schedulingAuditLogs)
          .getList(
            filter: 'treatment_plan = "${widget.plan.id}"',
            sort: '-created',
            perPage: 100,
          );
      setState(() {
        _logs = result.items.map((r) => r.data..['id'] = r.id).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load audit logs: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Schedule History', style: context.textStyles.h2),
                Text(
                  '${widget.plan.treatmentType} · ${widget.plan.patientName ?? "Patient"}',
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: context.colors.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: context.colors.error),
              const SizedBox(height: 12),
              Text(ErrorFormatter.format(_error!), style: context.textStyles.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded,
                  size: 56, color: context.colors.textHint),
              const SizedBox(height: 12),
              Text('No scheduling events recorded yet.',
                  style: context.textStyles.bodyMedium.copyWith(
                      color: context.colors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildLogCard(_logs[index]),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final oldDate = log['old_date'] as String? ?? '';
    final newDate = log['new_date'] as String? ?? '';
    final oldTime = log['old_time'] as String? ?? '';
    final newTime = log['new_time'] as String? ?? '';
    final reason = log['reason'] as String? ?? '';
    final trigger = log['trigger'] as String? ?? '';
    final performedBy = log['performed_by'] as String? ?? '';
    final schedVersion = log['schedule_version'];
    final createdRaw = log['created'] as String? ?? '';

    DateTime? createdDt;
    try {
      createdDt = DateTime.parse(createdRaw).toLocal();
    } catch (_) {}

    final (icon, color) = _actionMeta(action);

    final hasDateChange = oldDate.isNotEmpty && newDate.isNotEmpty && oldDate != newDate;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _actionLabel(action),
                        style: context.textStyles.label.copyWith(fontSize: 13),
                      ),
                    ),
                    if (schedVersion != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'v$schedVersion',
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.info,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (hasDateChange) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded,
                          size: 13, color: context.colors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '$oldDate${oldTime.isNotEmpty ? " ${TimeUtils.formatStringTime(oldTime)}" : ""} → $newDate${newTime.isNotEmpty ? " ${TimeUtils.formatStringTime(newTime)}" : ""}',
                        style: context.textStyles.caption.copyWith(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (createdDt != null)
                      Text(
                        DateFormat('MMM d, yyyy · h:mm a').format(createdDt),
                        style: context.textStyles.caption.copyWith(
                          color: context.colors.textHint,
                          fontSize: 10,
                        ),
                      ),
                    if (trigger.isNotEmpty || performedBy.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.colors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trigger == 'doctor_manual' ? 'Manual' : trigger == 'system' ? 'Auto' : trigger,
                          style: context.textStyles.caption.copyWith(
                            fontSize: 9,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _actionMeta(String action) {
    switch (action) {
      case 'plan_created':
        return (Icons.add_circle_outline, context.colors.success);
      case 'session_rescheduled':
        return (Icons.event_repeat_rounded, context.colors.primary);
      case 'session_missed':
        return (Icons.event_busy_rounded, context.colors.warning);
      case 'plan_paused':
        return (Icons.pause_circle_outline, context.colors.warning);
      case 'plan_resumed':
        return (Icons.play_circle_outline, context.colors.success);
      case 'plan_closed':
        return (Icons.cancel_outlined, context.colors.error);
      case 'plan_completed':
        return (Icons.verified_rounded, context.colors.success);
      case 'manual_review':
        return (Icons.sync_problem_rounded, context.colors.error);
      case 'mark_arrived':
        return (Icons.check_circle_outline, context.colors.info);
      default:
        return (Icons.history_rounded, context.colors.textSecondary);
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'plan_created':       return 'Treatment Plan Created';
      case 'session_rescheduled':return 'Session Rescheduled';
      case 'session_missed':     return 'Session Missed';
      case 'plan_paused':        return 'Plan Paused';
      case 'plan_resumed':       return 'Plan Resumed';
      case 'plan_closed':        return 'Treatment Closed';
      case 'plan_completed':     return 'Treatment Completed';
      case 'manual_review':      return 'Entered Manual Review';
      case 'mark_arrived':       return 'Patient Arrived';
      default:                   return action.replaceAll('_', ' ').toUpperCase();
    }
  }
}
