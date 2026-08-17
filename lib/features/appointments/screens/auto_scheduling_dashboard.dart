import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/patients/providers/patient_provider.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/features/scheduling/screens/available_slots_screen.dart';
import 'package:pms_app/features/treatments/widgets/cascade_preview_sheet.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart';

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
  /// Global notifier tracking if the Needs Attention dashboard has been opened or notification dismissed during this session.
  static final ValueNotifier<bool> notificationDismissed = ValueNotifier<bool>(false);

  final List<SessionModel> overdueSessions;
  final List<AppointmentModel> overdueConsultations;
  final List<TreatmentPlanModel> manualReviewPlans;
  final VoidCallback onRefresh;

  const AutoSchedulingDashboard({
    super.key,
    required this.overdueSessions,
    this.overdueConsultations = const [],
    this.manualReviewPlans = const [],
    required this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required List<SessionModel> overdueSessions,
    List<AppointmentModel> overdueConsultations = const [],
    List<TreatmentPlanModel> manualReviewPlans = const [],
    required VoidCallback onRefresh,
    // Legacy compat: old callers pass `plans` (TreatmentPlanModel list).
    // Those are routed to manualReviewPlans.
    List<TreatmentPlanModel>? plans,
  }) async {
    notificationDismissed.value = true;
    AppToast.dismiss(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AutoSchedulingDashboard(
          overdueSessions: overdueSessions,
          overdueConsultations: overdueConsultations,
          manualReviewPlans: plans ?? manualReviewPlans,
          onRefresh: onRefresh,
        ),
      );
    } else {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => AutoSchedulingDashboard(
            overdueSessions: overdueSessions,
            overdueConsultations: overdueConsultations,
            manualReviewPlans: plans ?? manualReviewPlans,
            onRefresh: onRefresh,
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<AutoSchedulingDashboard> createState() =>
      _AutoSchedulingDashboardState();
}

class _AutoSchedulingDashboardState
    extends ConsumerState<AutoSchedulingDashboard>
    with SingleTickerProviderStateMixin {
  late List<SessionModel> _sessions;
  late List<AppointmentModel> _consultations;
  late List<TreatmentPlanModel> _manualPlans;
  bool _isProcessing = false;
  String? _processingId;
  late TabController _tabController;

  String? _selectedPatientId;
  String? _highlightSessionId;

  @override
  void initState() {
    super.initState();
    AutoSchedulingDashboard.notificationDismissed.value = true;
    AppToast.dismiss();
    _sessions = List.from(widget.overdueSessions);
    _consultations = List.from(widget.overdueConsultations);
    _manualPlans = List.from(widget.manualReviewPlans);
    
    // We now have 3 potential tabs: Consultations, Sessions, Manual Review
    int tabCount = 2; // Consultations and Sessions
    if (_manualPlans.isNotEmpty) tabCount++;
    
    _tabController = TabController(
      length: tabCount,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentUserId => ref.read(authProvider).userId ?? 'system';

  Future<void> _onCardTapped(String patientId, String sessionId) async {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) {
      setState(() {
        _selectedPatientId = patientId;
        _highlightSessionId = sessionId;
      });
    } else {
      setState(() { _isProcessing = true; _processingId = sessionId; });
      try {
        final pRecord = await ref.read(pocketbaseProvider).collection('patients').getOne(patientId);
        final p = PatientModel.fromRecord(pRecord);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PatientProfileScreen(
            patient: p,
            initialTabIndex: 0,
            highlightSessionId: sessionId,
          )
        ));
      } catch (e) {
        if (mounted) AppToast.show('Failed to load patient: $e', type: ToastType.error);
      } finally {
        if (mounted) setState(() { _isProcessing = false; _processingId = null; });
      }
    }
  }

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
    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
      if (_selectedPatientId == session.patientId) {
        _selectedPatientId = null;
        _highlightSessionId = null;
      }
    });
    widget.onRefresh();

    // Close dashboard, then navigate to session form.
    // The session is still 'overdue' — the form detects this and
    // auto-completes it retroactively when the doctor saves.
    Navigator.of(context).pop();
    context.push('/sessions/record', extra: session);
  }

  // ─── Patient Missed ──────────────────────────────────────────────────

  Future<void> _onPatientMissed(SessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Patient Missed', style: context.textStyles.h3),
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
            child: const Text('Confirm Missed'),
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
        setState(() {
          _sessions.removeWhere((s) => s.id == session.id);
          if (_selectedPatientId == session.patientId) {
            _selectedPatientId = null;
            _highlightSessionId = null;
          }
        });
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
        if (_sessions.isEmpty && _consultations.isEmpty && _manualPlans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.show('Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }
  }


  Future<void> _onClinicClosed(SessionModel session) async {
    // 1. Pick Anchor Date & Time Slot
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: session.doctorId,
          treatmentDuration: 30,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null || result['date'] == null || result['time'] == null) {
      AppToast.show('Date and time required — session remains in review.', type: ToastType.warning);
      return;
    }
    final pickedDate = result['date'] as DateTime;
    final pickedTime = result['time'] as String;
    final newDateStr = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';

    // 2. Generate Initial Cascade Reschedule Proposal
    setState(() { _isProcessing = true; _processingId = session.id; });
    final ReschedulePreview preview;
    try {
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      preview = await lifecycle.previewRescheduleSessionAndCascade(
        sessionId: session.id,
        newDate: newDateStr,
        newTime: pickedTime,
        performedBy: _currentUserId,
      );
    } catch (e) {
      if (mounted) AppToast.show('Error generating schedule: $e', type: ToastType.error);
      return;
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }

    if (!mounted) return;

    // 3. Show Interactive Cascade Preview Sheet (Dialog on Desktop, Sheet on Mobile)
    final confirmedPreview = await CascadePreviewSheet.show(
      context: context,
      preview: preview,
      newTime: pickedTime,
      doctorId: session.doctorId,
      clinicId: ref.read(authProvider).clinicId,
      onRegenerate: ({
        required sessionId,
        required newDate,
        newTime,
        applyTimeToAll = false,
        overrideIntervalDays,
      }) {
        return ref.read(sessionLifecycleServiceProvider).previewRescheduleSessionAndCascade(
          sessionId: sessionId,
          newDate: newDate,
          newTime: newTime,
          performedBy: _currentUserId,
          applyTimeToAll: applyTimeToAll,
          overrideIntervalDays: overrideIntervalDays,
        );
      },
    );

    if (confirmedPreview == null || !mounted) return;

    // 4. Commit Proposal to PocketBase
    setState(() { _isProcessing = true; _processingId = session.id; });
    try {
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      await lifecycle.commitRescheduleProposal(confirmedPreview);

      if (mounted) {
        setState(() {
          _sessions.removeWhere((s) => s.treatmentPlanId == session.treatmentPlanId || s.id == session.id);
          if (_selectedPatientId == session.patientId) {
            _selectedPatientId = null;
            _highlightSessionId = null;
          }
        });
        widget.onRefresh();
        AppToast.show(
          'Session ${session.sessionNumber} and subsequent sessions rescheduled ✓',
          type: ToastType.success,
        );
        if (_sessions.isEmpty && _consultations.isEmpty && _manualPlans.isEmpty) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) AppToast.show('Error saving schedule: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }
  }

  // ─── Pause Sessions ───────────────────────────────────────────────────────

  Future<void> _onPauseSessions({
    required String planId,
    required String patientName,
    required List<SessionModel> planSessions,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Pause Treatment for $patientName?', style: context.textStyles.h3),
        content: Text(
          'This will pause the treatment plan and all upcoming sessions for $patientName. '
          'No further sessions will be auto-scheduled until the plan is resumed.',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pause Treatment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _isProcessing = true; _processingId = planId; });
    try {
      final service = ref.read(treatmentServiceProvider);
      await service.pauseSessions(planId, performedBy: _currentUserId);
      if (mounted) {
        // Remove all sessions of this plan from the list
        setState(() => _sessions.removeWhere((s) => s.treatmentPlanId == planId));
        widget.onRefresh();
        AppToast.show(
          'Treatment plan paused. Sessions for $patientName are on hold.',
          type: ToastType.warning,
          duration: const Duration(seconds: 5),
        );
        if (_sessions.isEmpty && _consultations.isEmpty && _manualPlans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.show('Error pausing plan: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }
  }

  // ─── Consultations Handlers ─────────────────────────────────────────────

  Future<void> _onConsultationDidntArrive(AppointmentModel apt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Patient Didn\'t Arrive', style: context.textStyles.h3),
        content: Text(
          'Mark consultation for ${apt.patientName ?? "Unknown"} on ${_formatDate(apt.date)} as Missed/Cancelled?',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Missed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _isProcessing = true; _processingId = apt.id; });
    try {
      final pb = ref.read(pocketbaseProvider);
      await pb.collection('appointments').update(apt.id, body: {
        'status': 'cancelled', // Or 'missed' if AppointmentModel uses it
      });

      if (mounted) {
        setState(() => _consultations.removeWhere((c) => c.id == apt.id));
        widget.onRefresh();
        AppToast.show('Consultation marked as missed', type: ToastType.success);
        if (_sessions.isEmpty && _consultations.isEmpty && _manualPlans.isEmpty) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.show('Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() { _isProcessing = false; _processingId = null; });
    }
  }

  Future<void> _onConsultationForgotRecord(AppointmentModel apt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Retroactively Record Consultation', style: context.textStyles.h3),
        content: Text(
          'Open the form to record details for ${apt.patientName ?? "Unknown"}?',
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

    // Optimistically remove from list and refresh badge
    setState(() => _consultations.removeWhere((c) => c.id == apt.id));
    widget.onRefresh();

    // Close dashboard and navigate to PatientInfoScreen / Consultation
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop(); // Close dashboard
    
    // We cannot push PatientInfoScreen directly because it requires imports.
    // However, if we pop, they can just click the normal card. 
    // Wait, the card is now gone! We should just refresh the list so it appears as waiting/scheduled?
    // Let's just update the status to scheduled so it appears on the main screen, then they can tap it.
    try {
      final pb = ref.read(pocketbaseProvider);
      await pb.collection('appointments').update(apt.id, body: {
        'status': 'scheduled',
      });
      AppToast.show('Consultation reverted to Upcoming. Tap it in the list to fill details.', type: ToastType.info);
    } catch (e) {
      if (mounted) AppToast.show('Error: $e', type: ToastType.error);
    }
  }


  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final totalItems = _sessions.length + _consultations.length + _manualPlans.length;
    final hasSelection = isDesktop && _selectedPatientId != null;

    Widget dashboardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(totalItems),
        TabBar(
          controller: _tabController,
          labelColor: context.colors.primary,
          unselectedLabelColor: context.colors.textSecondary,
          indicatorColor: context.colors.primary,
          tabs: [
            Tab(text: 'Consultations (${_consultations.length})'),
            Tab(text: 'Sessions (${_sessions.length})'),
            if (_manualPlans.isNotEmpty)
              Tab(text: 'Manual Reschedule (${_manualPlans.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildConsultationList(),
              _buildSessionList(),
              if (_manualPlans.isNotEmpty) _buildManualReviewList(),
            ],
          ),
        ),
      ],
    );

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: dashboardContent,
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: context.colors.background,
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: hasSelection ? width * 0.9 : 650,
        height: MediaQuery.of(context).size.height * 0.85,
        child: hasSelection
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 450,
                    child: dashboardContent,
                  ),
                  Container(
                    width: 1,
                    color: context.colors.border,
                  ),
                  Expanded(
                    child: _buildRightPane(),
                  ),
                ],
              )
            : dashboardContent,
      ),
    );
  }

  Widget _buildRightPane() {
    return FutureBuilder<PatientModel>(
      future: ref.read(pocketbaseProvider).collection('patients').getOne(_selectedPatientId!).then((r) => PatientModel.fromRecord(r)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('Failed to load patient: ${snapshot.error}'));
        }
        return ClipRRect(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
          child: PatientProfileScreen(
            patient: snapshot.data!,
            initialTabIndex: 0,
            isCompact: true,
            highlightSessionId: _highlightSessionId,
          ),
        );
      },
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
                      : '$totalItems appointment${totalItems == 1 ? '' : 's'} needs review',
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

  Widget _buildConsultationList() {
    if (_consultations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All consultations reviewed!',
        subtitle: 'No overdue consultations need your attention.',
        color: context.colors.success,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _consultations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _buildConsultationCard(_consultations[i]),
    );
  }

  Widget _buildConsultationCard(AppointmentModel apt) {
    final isLoading = _isProcessing && _processingId == apt.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.error.withValues(alpha: 0.4),
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
                    color: context.colors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.assignment_ind_rounded, color: context.colors.error, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (apt.patientName != null && apt.patientName!.isNotEmpty)
                            ? apt.patientName!
                            : 'Unknown Patient',
                        style: context.textStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${apt.type.name.toUpperCase()}'
                        ' · ${_formatDate(apt.date)}'
                        '${apt.time.isNotEmpty ? " · ${apt.time}" : ""}'
                        '${(apt.doctorName != null && apt.doctorName!.isNotEmpty) ? " · Dr. ${apt.doctorName}" : ""}',
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
                    color: context.colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Overdue',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.error,
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
                      label: 'Didn\'t Arrive',
                      icon: Icons.event_busy_rounded,
                      color: context.colors.error,
                      onTap: () => _onConsultationDidntArrive(apt),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: 'Forgot to Record',
                      icon: Icons.edit_note_rounded,
                      color: context.colors.primary,
                      onTap: () => _onConsultationForgotRecord(apt),
                    ),
                  ),
                ],
              ),
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

    // Group sessions by treatmentPlanId
    final Map<String, List<SessionModel>> grouped = {};
    for (final s in _sessions) {
      final key = s.treatmentPlanId.isNotEmpty ? s.treatmentPlanId : s.id;
      grouped.putIfAbsent(key, () => []).add(s);
    }
    // Sort each group by session number
    for (final group in grouped.values) {
      group.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
    }

    final groupKeys = grouped.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groupKeys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final planId = groupKeys[i];
        final planSessions = grouped[planId]!;
        if (planSessions.length == 1) {
          // Single overdue session — render flat card (no grouping)
          return _buildSessionCard(planSessions.first);
        }
        // Multiple overdue sessions for same patient — render grouped card
        return _buildPatientSessionGroup(
          planId: planId,
          sessions: planSessions,
        );
      },
    );
  }

  Widget _buildSessionCard(SessionModel session) {
    final isLoading = _isProcessing && _processingId == session.id;

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.warning.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: GestureDetector(
        onTap: () => _onCardTapped(session.patientId, session.id),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (session.patientName != null && session.patientName!.isNotEmpty) 
                            ? session.patientName! 
                            : 'Unknown Patient',
                        style: context.textStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Session ${session.sessionNumber}'
                        ' · ${_formatDate(session.scheduledDate)}'
                        '${(session.scheduledTime != null && session.scheduledTime!.isNotEmpty) ? " · ${session.scheduledTime}" : ""}'
                        '${session.treatmentModality.isNotEmpty ? " · ${session.treatmentModality}" : ""}'
                        '${(session.doctorName != null && session.doctorName!.isNotEmpty) ? " · Dr. ${session.doctorName}" : ""}',
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
                      label: 'Patient Arrived',
                      icon: Icons.check_circle_rounded,
                      color: context.colors.success,
                      onTap: () => _onPatientCame(session),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: 'Patient Missed',
                      icon: Icons.cancel_rounded,
                      color: context.colors.error,
                      onTap: () => _onPatientMissed(session),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: 'Clinic Closed',
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
    ));

    return cardContent;
  }

  /// Renders a grouped patient card for when a patient has 2+ overdue sessions.
  Widget _buildPatientSessionGroup({
    required String planId,
    required List<SessionModel> sessions,
  }) {
    final patientName = (sessions.first.patientName?.isNotEmpty == true)
        ? sessions.first.patientName!
        : 'Unknown Patient';
    final missCount = sessions.length;
    final isPausing = _isProcessing && _processingId == planId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.error.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: GestureDetector(
        onTap: () => _onCardTapped(sessions.first.patientId, sessions.first.id),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Patient header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_off_outlined,
                      color: context.colors.error, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              patientName,
                              style: context.textStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Consecutive misses badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.colors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 11, color: context.colors.error),
                                const SizedBox(width: 3),
                                Text(
                                  '$missCount ${missCount == 1 ? 'Overdue' : 'Overdues'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sessions.first.treatmentModality.isNotEmpty
                            ? sessions.first.treatmentModality
                            : "Treatment",
                        style: context.textStyles.bodySmall.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pause Sessions button
                if (isPausing)
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _onPauseSessions(
                      planId: planId,
                      patientName: patientName,
                      planSessions: sessions,
                    ),
                    icon: Icon(Icons.pause_circle_outline_rounded,
                        size: 16, color: context.colors.warning),
                    label: Text(
                      'Pause Treatment',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: context.colors.warning.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: context.colors.warning.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border.withValues(alpha: 0.5)),
          // ── Individual session sub-cards ─────────────────────────────
          ...sessions.map((session) => _buildSessionSubCard(session)),
        ],
      ),
    ));
  }

  /// Compact session row inside a patient group card.
  Widget _buildSessionSubCard(SessionModel session) {
    final isLoading = _isProcessing && _processingId == session.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Session ${session.sessionNumber} · ${_formatDate(session.scheduledDate)}'
                  '${(session.scheduledTime != null && session.scheduledTime!.isNotEmpty) ? " · ${session.scheduledTime}" : ""}',
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Overdue',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    label: 'Patient Arrived',
                    icon: Icons.check_circle_rounded,
                    color: context.colors.success,
                    onTap: () => _onPatientCame(session),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    label: "Patient Missed",
                    icon: Icons.cancel_rounded,
                    color: context.colors.error,
                    onTap: () => _onPatientMissed(session),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    label: 'Clinic Closed',
                    icon: Icons.business_rounded,
                    color: context.colors.textSecondary,
                    onTap: () => _onClinicClosed(session),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border.withValues(alpha: 0.3)),
      ],
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
