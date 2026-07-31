import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';

/// Needs Attention Dashboard.
///
/// Shows all [overdue] sessions and lets the doctor or receptionist confirm
/// what actually happened for each one — without any automatic assumptions.
///
/// Three outcomes per session:
///   1. "Patient Came"    → navigates to session form for retroactive recording
///   2. "Didn't Show"     → confirms the miss, increments counters
///   3. "Clinic Closed"   → reverts to upcoming with no penalty
///
/// Also surfaces plans in [manualReview] that need human rescheduling.
class AutoSchedulingDashboard extends ConsumerStatefulWidget {
  final List<SessionModel> overdueSessions;
  final List<TreatmentPlanModel> manualReviewPlans;
  final VoidCallback onRefresh;

  const AutoSchedulingDashboard({
    super.key,
    required this.overdueSessions,
    this.manualReviewPlans = const [],
    required this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required List<SessionModel> overdueSessions,
    List<TreatmentPlanModel> manualReviewPlans = const [],
    required VoidCallback onRefresh,
    // Legacy compat: old callers pass `plans` (TreatmentPlanModel list).
    // Those are routed to manualReviewPlans.
    List<TreatmentPlanModel>? plans,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AutoSchedulingDashboard(
        overdueSessions: overdueSessions,
        manualReviewPlans: plans ?? manualReviewPlans,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  ConsumerState<AutoSchedulingDashboard> createState() =>
      _AutoSchedulingDashboardState();
}

class _AutoSchedulingDashboardState
    extends ConsumerState<AutoSchedulingDashboard>
    with SingleTickerProviderStateMixin {
  late List<SessionModel> _sessions;
  late List<TreatmentPlanModel> _manualPlans;
  bool _isProcessing = false;
  String? _processingId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.overdueSessions);
    _manualPlans = List.from(widget.manualReviewPlans);
    _tabController = TabController(
      length: _manualPlans.isNotEmpty ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentUserId => ref.read(authProvider).userId ?? 'system';

  // ─── Patient Came ──────────────────────────────────────────────────────────

  Future<void> _onPatientCame(SessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Record Retroactive Session', style: context.textStyles.h3),
        content: Text(
          'Session ${session.sessionNumber} on '
          '${_formatDate(session.scheduledDate)} will open for retroactive recording.\n\n'
          'Fill in the clinical details and hit Save to complete it.',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Form'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Capture the root navigator BEFORE popping the dialog
    final nav = Navigator.of(context, rootNavigator: true);

    // Optimistically remove from list and refresh badge
    setState(() => _sessions.removeWhere((s) => s.id == session.id));
    widget.onRefresh();

    // Close dashboard, then navigate to session form.
    // The session is still 'overdue' — the form detects this and
    // auto-completes it retroactively when the doctor saves.
    nav.pop();
    nav.pushNamed('/sessions/record', arguments: session);
  }

  // ─── Patient Didn't Show ──────────────────────────────────────────────────

  Future<void> _onDidntShow(SessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Confirm Missed Session', style: context.textStyles.h3),
        content: Text(
          'Mark Session ${session.sessionNumber} as missed on '
          '${_formatDate(session.scheduledDate)}?\n\n'
          'This will count toward the patient\'s consecutive miss record.',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Miss'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _isProcessing = true; _processingId = session.id; });
    try {
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      final newConsecutive = await lifecycle.confirmSessionMissed(
        session.id,
        session.treatmentPlanId,
        performedBy: _currentUserId,
      );

      if (mounted) {
        setState(() => _sessions.removeWhere((s) => s.id == session.id));
        widget.onRefresh();
        if (newConsecutive >= 3) {
          AppToast.show(
            'Session marked as missed. Patient has $newConsecutive consecutive misses — plan flagged for manual review.',
            type: ToastType.warning,
            duration: const Duration(seconds: 6),
          );
        } else {
          AppToast.show('Session marked as missed.', type: ToastType.info);
        }
        if (_sessions.isEmpty && _manualPlans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.show('Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }
  }

  // ─── Clinic Was Closed ────────────────────────────────────────────────────

  Future<void> _onClinicClosed(SessionModel session) async {
    final sessionDate = DateTime.tryParse(session.scheduledDate);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isPastDate = sessionDate != null && sessionDate.isBefore(today);

    // For past-date sessions, force a new date to prevent the infinite overdue loop.
    // (leaving it on the same past date = tomorrow's sweep catches it again)
    DateTime? pickedDate;
    if (isPastDate && mounted) {
      pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        helpText: 'Pick a new session date',
        confirmText: 'Reschedule',
        cancelText: 'Cancel',
      );
      if (!mounted) return;
      if (pickedDate == null) {
        AppToast.show('Date required — session stays as overdue.', type: ToastType.warning);
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Clinic Was Closed', style: context.textStyles.h3),
        content: Text(
          'Session ${session.sessionNumber} on ${_formatDate(session.scheduledDate)} '
          'will be reverted to Upcoming with no miss penalty.\n\n'
          + (pickedDate != null
              ? 'New date: ${_formatDate(pickedDate.toIso8601String().substring(0, 10))}'
              : 'The session stays on the same date.'),
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss — No Penalty'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _isProcessing = true; _processingId = session.id; });
    try {
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      final newDateStr = pickedDate != null
          ? '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}'
          : null;
      await lifecycle.dismissAsClinicHoliday(
        session.id,
        newDate: newDateStr,
        performedBy: _currentUserId,
      );


      if (mounted) {
        setState(() => _sessions.removeWhere((s) => s.id == session.id));
        widget.onRefresh();
        AppToast.show(
          pickedDate != null
              ? 'Session rescheduled — no miss penalty applied ✓'
              : 'Session reverted to upcoming ✓',
          type: ToastType.success,
        );
        if (_sessions.isEmpty && _manualPlans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.show('Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }
  }

  // ─── Dismiss All as Holiday ───────────────────────────────────────────────

  Future<void> _dismissAllAsHoliday() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Dismiss All — Clinic Holiday', style: context.textStyles.h3),
        content: Text(
          'All ${_sessions.length} overdue sessions will be reverted to Upcoming '
          'with no miss penalty applied to any patient.',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _isProcessing = true; _processingId = '__all__'; });
    try {
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      for (final session in List<SessionModel>.from(_sessions)) {
        await lifecycle.dismissAsClinicHoliday(
          session.id,
          performedBy: _currentUserId,
        );
      }
      if (mounted) {
        setState(() => _sessions.clear());
        widget.onRefresh();
        AppToast.show('All sessions dismissed ✓', type: ToastType.success);
        if (_manualPlans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.show('Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final totalItems = _sessions.length + _manualPlans.length;

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
            _buildHeader(totalItems),
            if (_manualPlans.isNotEmpty)
              TabBar(
                controller: _tabController,
                labelColor: context.colors.primary,
                unselectedLabelColor: context.colors.textSecondary,
                indicatorColor: context.colors.primary,
                tabs: [
                  Tab(text: 'Needs Review (${_sessions.length})'),
                  Tab(text: 'Manual Reschedule (${_manualPlans.length})'),
                ],
              ),
            Flexible(
              child: _manualPlans.isNotEmpty
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSessionList(),
                        _buildManualReviewList(),
                      ],
                    )
                  : _buildSessionList(),
            ),
            if (_sessions.isNotEmpty) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalItems) {
    return Container(
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
          bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: context.colors.warning, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs Attention', style: context.textStyles.h3),
                Text(
                  totalItems == 0
                      ? 'All caught up!'
                      : '$totalItems item${totalItems == 1 ? '' : 's'} need your review',
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: context.colors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All sessions reviewed!',
        subtitle: 'No overdue sessions need your attention.',
        color: context.colors.success,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _buildSessionCard(_sessions[i]),
    );
  }

  Widget _buildSessionCard(SessionModel session) {
    final isLoading = _isProcessing && _processingId == session.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.warning.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${session.sessionNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.colors.warning,
                        fontSize: 14,
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
                        style: context.textStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatDate(session.scheduledDate)}'
                        '${session.scheduledTime != null ? " · ${session.scheduledTime}" : ""}'
                        '${session.treatmentModality.isNotEmpty ? " · ${session.treatmentModality}" : ""}',
                        style: context.textStyles.bodySmall.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Overdue',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border.withValues(alpha: 0.4)),
          // Action buttons
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'Patient Came',
                      icon: Icons.check_circle_rounded,
                      color: context.colors.success,
                      onTap: () => _onPatientCame(session),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: 'Didn\'t Show',
                      icon: Icons.cancel_rounded,
                      color: context.colors.error,
                      onTap: () => _onDidntShow(session),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: 'We Were Closed',
                      icon: Icons.business_rounded,
                      color: context.colors.textSecondary,
                      onTap: () => _onClinicClosed(session),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualReviewList() {
    if (_manualPlans.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available_rounded,
        title: 'No plans need rescheduling',
        subtitle: 'All treatment plans are on track.',
        color: context.colors.success,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _manualPlans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _buildManualReviewCard(_manualPlans[i]),
    );
  }

  Widget _buildManualReviewCard(TreatmentPlanModel plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.error.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: context.colors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: context.colors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.patientName ?? 'Patient',
                  style: context.textStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${plan.consecutiveMisses} consecutive misses · ${plan.treatmentType}',
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: navigate to patient plan for manual rescheduling
            },
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: (_isProcessing && _processingId == '__all__')
              ? null
              : _dismissAllAsHoliday,
          icon: const Icon(Icons.business_rounded, size: 16),
          label: Text('Dismiss All — We Were Closed (${_sessions.length})'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            side: BorderSide(color: context.colors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(title,
              style: context.textStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle,
              style: context.textStyles.bodySmall.copyWith(
                  color: context.colors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return DateFormat('EEE, d MMM y').format(dt);
  }
}
