import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/appointment_model.dart';
import '../providers/appointment_provider.dart';
import '../../../core/utils/time_utils.dart';
import '../../patients/models/patient_model.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/models/doctor_model.dart';
import '../../../core/services/scheduling_service.dart';
import '../../scheduling/screens/available_slots_screen.dart';
import '../../consultations/screens/consultation_screen.dart';
import '../../treatments/screens/create_treatment_plan_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import 'patient_info_screen.dart';
import '../../analytics/providers/analytics_provider.dart';

class AppointmentListScreen extends ConsumerStatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  ConsumerState<AppointmentListScreen> createState() =>
      _AppointmentListScreenState();
}

class _AppointmentListScreenState
    extends ConsumerState<AppointmentListScreen> with TickerProviderStateMixin {
  late DateTime _selectedDate;
  final _dateScrollCtrl = ScrollController();
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  void _generateDates() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    _dates = List.generate(lastDay, (i) => DateTime(year, month, i + 1));
  }

  void _scrollToSelectedDate() {
    if (!_dateScrollCtrl.hasClients) return;
    // Scroll so yesterday is first visible (today is second)
    final offset = ((_selectedDate.day - 2) * 76.0);
    _dateScrollCtrl.animateTo(
      offset.clamp(0.0, _dateScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Reset to today and scroll to default position (yesterday first, today second).
  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = now;
      _generateDates();
    });
    ref.read(appointmentListProvider.notifier).changeDate(_formatDate(now));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  @override
  void dispose() {
    _dateScrollCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _generateDates();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
      ref.read(appointmentListProvider.notifier).changeDate(_formatDate(picked));
    }
  }

  bool _isLate(AppointmentModel apt) {
    if (apt.status != AppointmentStatus.scheduled) return false;
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    if (apt.date != todayStr) return false;
    final parts = apt.time.split(':');
    if (parts.length != 2) return false;
    final aptTime = DateTime(now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return now.isAfter(aptTime);
  }

  bool _isMissed(AppointmentModel apt) {
    if (apt.status != AppointmentStatus.scheduled) return false;
    return apt.date.compareTo(_formatDate(DateTime.now())) < 0;
  }

  bool _isFutureDate(AppointmentModel apt) {
    return apt.date.compareTo(_formatDate(DateTime.now())) > 0;
  }

  // ── Consultation card actions ─────────────────────────────────

  Future<void> _markArrived(AppointmentModel apt) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final docRec = await pb.collection('doctors').getOne(apt.doctorId);
      final doctor = DoctorModel.fromRecord(docRec);
      
      final schedService = SchedulingService(pb);
      final daySchedule = schedService.getScheduleForDay(doctor.workingSchedule, DateTime.now().weekday);
      if (daySchedule == null) {
        if (mounted) _showError("Doctor is not scheduled to work today.");
        return;
      }
      
      final now = DateTime.now();
      final nowStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
      if (!schedService.isWithinWorkingHours(daySchedule, nowStr)) {
        if (mounted) _showError("Patient arrival can only be captured between doctor's working hours.");
        return;
      }

      final service = ref.read(appointmentServiceProvider);
      await service.markArrived(apt.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${apt.displayName} marked as arrived ✓'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  Future<void> _markEnded(AppointmentModel apt) async {
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.markEnded(apt.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      ref.read(analyticsProvider.notifier).load(); // background refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${apt.displayName} — appointment ended ✓'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  Future<void> _cancelAppointment(AppointmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Appointment?', style: TextStyle(color: AppColors.error)),
        content: Text('Cancel for ${apt.displayName} at ${TimeUtils.formatStringTime(apt.time)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(appointmentListProvider.notifier).updateStatus(apt.id, AppointmentStatus.cancelled);
    }
  }

  Future<void> _undoArrived(AppointmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(children: [
          const Icon(Icons.undo_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          const Text('Undo Arrival?'),
        ]),
        content: Text('Revert ${apt.displayName}\'s arrival back to scheduled?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Undo'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final service = ref.read(appointmentServiceProvider);
        await service.undoArrived(apt.id);
        ref.read(appointmentListProvider.notifier).loadAppointments();
      } catch (e) {
        if (mounted) _showError('$e');
      }
    }
  }

  Future<void> _rescheduleConsultation(AppointmentModel apt) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: apt.doctorId,
          clinicId: (apt.clinicId != null && apt.clinicId!.isNotEmpty) ? apt.clinicId : null,
          treatmentDuration: 30,
        ),
      ),
    );
    if (result != null && mounted) {
      final newDate = DateFormat('yyyy-MM-dd').format(result['date'] as DateTime);
      final newTime = result['time'] as String;
      try {
        final service = ref.read(appointmentServiceProvider);
        await service.rescheduleAppointment(apt.id, newDate, newTime);
        ref.read(appointmentListProvider.notifier).loadAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (mounted) _showError('$e');
      }
    }
  }

  void _navigateToPatient(AppointmentModel apt) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      final record = await pb.collection(PBCollections.patients).getOne(apt.patientId!);
      final patient = PatientModel.fromRecord(record);
      if (mounted) Navigator.pushNamed(context, '/patient-profile', arguments: patient);
    } catch (e) {
      if (mounted) _showError('Could not load patient: $e');
    }
  }

  Future<void> _startConsultation(AppointmentModel apt) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return;
    // Guard: patient details must be saved first
    if (!apt.patientDetailsSaved) {
      if (mounted) _showError('Please fill and submit patient details before starting a consultation.');
      return;
    }
    // Guard: if form already saved, don't re-open it (buttons already show Create Plan / End Consultation)
    if (apt.consultationFormSaved) return;
    try {
      final service = ref.read(appointmentServiceProvider);
      final ongoing = await service.findOngoingConsultation(apt.patientId!, apt.doctorId);
      String? consultationId;
      if (ongoing != null) {
        consultationId = ongoing.id;
      } else {
        final newConsultation = await service.createConsultation(apt.patientId!, apt.doctorId);
        consultationId = newConsultation.id;
      }
      await service.setConsultationStartTime(apt.id);
      if (mounted) {
        final pb = ref.read(pocketbaseProvider);
        final patientRecord = await pb.collection(PBCollections.patients).getOne(apt.patientId!);
        final patientName = patientRecord.getStringValue('full_name');
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationScreen(
              patientId: apt.patientId!,
              patientName: patientName,
              doctorId: apt.doctorId,
              consultationId: consultationId,
              appointmentId: apt.id, // so screen can mark form saved + end time
            ),
          ),
        );
        ref.read(appointmentListProvider.notifier).loadAppointments();
      }
    } catch (e) {
      if (mounted) _showError('Error starting consultation: $e');
    }
  }

  Future<void> _navigateToCreatePlan(AppointmentModel apt, String consultationId) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      final patientRecord = await pb.collection(PBCollections.patients).getOne(apt.patientId!);
      final patientName = patientRecord.getStringValue('full_name');
      if (mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateTreatmentPlanScreen(
              patientId: apt.patientId!,
              patientName: patientName,
              doctorId: apt.doctorId,
              consultationId: consultationId,
              appointmentId: apt.id, // enables draft cache + plan linking
            ),
          ),
        );
        if (!mounted) return;
        if (result == true) {
          // Auto-end the consultation appointment after a plan is created
          final service = ref.read(appointmentServiceProvider);
          await service.markEnded(apt.id);
          ref.read(analyticsProvider.notifier).load();
          if (mounted) {
            final now = DateTime.now();
            final timeStr =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                'Treatment plan created & consultation ended. Today\'s session is waiting at $timeStr.'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          }
        }
        ref.read(appointmentListProvider.notifier).loadAppointments();
      }
    } catch (e) {
      if (mounted) _showError('Failed to open plan creator: $e');
    }
  }

  // ── Session card actions ───────────────────────────────────────

  Future<void> _markSessionArrived(AppointmentModel apt) async {
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.markSessionArrived(apt.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${apt.displayName} is now waiting for session ✓'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  Future<void> _markStartSession(AppointmentModel apt) async {
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.startSession(apt.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session started for ${apt.displayName} ✓'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  Future<void> _markSessionEnded(AppointmentModel apt) async {
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.markSessionEnded(apt.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      ref.read(analyticsProvider.notifier).load(); // background refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session for ${apt.displayName} completed ✓'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  Future<void> _openSessionPage(AppointmentModel apt) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return;
    try {
      final service = ref.read(appointmentServiceProvider);
      final sessionInfo = await service.findSessionForAppointment(apt);
      if (sessionInfo == null) {
        if (mounted) _showError('Session record not found');
        return;
      }
      final pb = ref.read(pocketbaseProvider);
      final patientRecord = await pb.collection(PBCollections.patients).getOne(apt.patientId!);
      final patientName = patientRecord.getStringValue('full_name');
      final consultationId = sessionInfo['consultationId']!.isNotEmpty
          ? sessionInfo['consultationId']
          : null;
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationScreen(
              patientId: apt.patientId!,
              patientName: patientName,
              doctorId: apt.doctorId,
              consultationId: consultationId,
              isViewMode: true,
            ),
          ),
        );
        ref.read(appointmentListProvider.notifier).loadAppointments();
      }
    } catch (e) {
      if (mounted) _showError('Could not open session: $e');
    }
  }

  Future<void> _rescheduleSession(AppointmentModel apt) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: apt.doctorId,
          clinicId: (apt.clinicId != null && apt.clinicId!.isNotEmpty) ? apt.clinicId : null,
          treatmentDuration: 30,
        ),
      ),
    );
    if (result != null && mounted) {
      final newDate = DateFormat('yyyy-MM-dd').format(result['date'] as DateTime);
      final newTime = result['time'] as String;
      try {
        final service = ref.read(appointmentServiceProvider);
        await service.rescheduleSessionAppointment(apt.id, apt, newDate, newTime);
        ref.read(appointmentListProvider.notifier).loadAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Session for ${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (mounted) _showError('$e');
      }
    }
  }

  Future<void> _cancelSession(AppointmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Session?', style: TextStyle(color: AppColors.error)),
        content: Text('Cancel session for ${apt.displayName} at ${TimeUtils.formatStringTime(apt.time)}?\n\nThis will also remove it from the treatment plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        // Cancel the appointment
        ref.read(appointmentListProvider.notifier).updateStatus(apt.id, AppointmentStatus.cancelled);
        // Also cancel the linked session record
        final service = ref.read(appointmentServiceProvider);
        final sessionInfo = await service.findSessionForAppointment(apt);
        if (sessionInfo != null) {
          final pb = ref.read(pocketbaseProvider);
          await pb.collection(PBCollections.sessions).update(
            sessionInfo['sessionId']!,
            body: {'status': 'cancelled'},
          );
        }
      } catch (e) {
        if (mounted) _showError('$e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentListProvider);
    final all = state.appointments;

    final activeConsultationPatientIds = all
        .where((a) => a.type != AppointmentType.session && a.status != AppointmentStatus.completed && a.status != AppointmentStatus.cancelled)
        .map((a) => a.patientId)
        .toSet();

    final consultations = all.where((a) => a.type != AppointmentType.session).toList();
    final sessions = all.where((a) => a.type == AppointmentType.session && !activeConsultationPatientIds.contains(a.patientId)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule', style: AppTextStyles.h1),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedDate),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Today button
                      GestureDetector(
                        onTap: _goToToday,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('Today',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Calendar button
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Horizontal Date Strip ──
            SizedBox(
              height: 84,
              child: ListView.builder(
                controller: _dateScrollCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _dates.length,
                itemBuilder: (context, index) {
                  final d = _dates[index];
                  final isSelected = d.day == _selectedDate.day &&
                      d.month == _selectedDate.month &&
                      d.year == _selectedDate.year;
                  final now = DateTime.now();
                  final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
                  String dayLabel = DateFormat('E').format(d);
                  if (isToday) dayLabel = 'Today';

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = d);
                      ref.read(appointmentListProvider.notifier).changeDate(_formatDate(d));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(dayLabel, style: AppTextStyles.caption.copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          )),
                          const SizedBox(height: 6),
                          Text(d.day.toString(), style: AppTextStyles.h2.copyWith(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            height: 1,
                          )),
                          const SizedBox(height: 6),
                          Container(
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : isToday ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: AppColors.border, height: 1),
            ),
            const SizedBox(height: 8),

            // ── Main Content ──
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
                  : state.error != null
                      ? _errorView(state.error!)
                      : (consultations.isEmpty && sessions.isEmpty)
                          ? _emptyView()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () => ref.read(appointmentListProvider.notifier).loadAppointments(),
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                                children: [
                                  // ── Consultations Section ──
                                  _sectionHeader('Consultations', Icons.assignment_ind_rounded, consultations.length, AppColors.info),
                                  const SizedBox(height: 12),
                                  if (consultations.isEmpty)
                                    _emptySectionLabel('No consultations scheduled')
                                  else
                                    ...consultations.asMap().entries.map((e) =>
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: _ScheduleCard(
                                          key: ValueKey(e.value.id),
                                          index: e.key,
                                          apt: e.value,
                                          isLate: _isLate(e.value),
                                          isFutureDate: _isFutureDate(e.value),
                                          isMissed: _isMissed(e.value),
                                          onArrived: () => _markArrived(e.value),
                                          onFillDetails: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => PatientInfoScreen(appointment: e.value)),
                                            ).then((_) => ref.read(appointmentListProvider.notifier).loadAppointments());
                                          },
                                          onEnded: () => _markEnded(e.value),
                                          onStartConsultation: () => _startConsultation(e.value),
                                          onCreatePlan: (consultationId) => _navigateToCreatePlan(e.value, consultationId),
                                          onReschedule: () => _rescheduleConsultation(e.value),
                                          onUndoArrived: () => _undoArrived(e.value),
                                          onTap: () => _navigateToPatient(e.value),
                                          onLongPress: () => _cancelAppointment(e.value),
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 24),
                                  const Divider(color: AppColors.border),
                                  const SizedBox(height: 16),

                                  // ── Treatment Sessions Section ──
                                  _sectionHeader('Treatment Sessions', Icons.healing_rounded, sessions.length, AppColors.primary),
                                  const SizedBox(height: 12),
                                  if (sessions.isEmpty)
                                    _emptySectionLabel('No sessions scheduled')
                                  else
                                    ...sessions.asMap().entries.map((e) =>
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: _SessionCard(
                                          key: ValueKey('s_${e.value.id}'),
                                          index: e.key,
                                          apt: e.value,
                                          isLate: _isLate(e.value),
                                          isFutureDate: _isFutureDate(e.value),
                                          isMissed: _isMissed(e.value),
                                          onArrived: () => _markSessionArrived(e.value),
                                          onStartSession: () => _markStartSession(e.value),
                                          onSessionEnded: () => _markSessionEnded(e.value),
                                          onReschedule: () => _rescheduleSession(e.value),
                                          onLongPress: () => _cancelSession(e.value),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.h3),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _emptySectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint))),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No appointments today', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap the + button to create one.', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(appointmentListProvider.notifier).loadAppointments(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Consultation Schedule Card (call_by + walk_in)
// ════════════════════════════════════════════════════════════════════

class _ScheduleCard extends ConsumerStatefulWidget {
  final AppointmentModel apt;
  final int index;
  final bool isLate;
  final bool isFutureDate;
  final bool isMissed;
  final VoidCallback onArrived;
  final VoidCallback onFillDetails;
  final VoidCallback onEnded;
  final VoidCallback onStartConsultation;
  final void Function(String consultationId) onCreatePlan;
  final VoidCallback onReschedule;
  final VoidCallback onUndoArrived;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ScheduleCard({
    super.key,
    required this.apt,
    required this.index,
    required this.isLate,
    required this.isFutureDate,
    required this.isMissed,
    required this.onArrived,
    required this.onFillDetails,
    required this.onEnded,
    required this.onStartConsultation,
    required this.onCreatePlan,
    required this.onReschedule,
    required this.onUndoArrived,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  ConsumerState<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<_ScheduleCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Plan info — only loaded when consultation has started (consultationStartTime != null)
  bool _planInfoLoaded = false;
  bool _hasPlan = false;
  String? _consultationId;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
    // If consultation form already saved, fetch plan info once on init
    if (widget.apt.consultationFormSaved &&
        widget.apt.patientId != null &&
        widget.apt.patientId!.isNotEmpty) {
      _loadPlanInfo();
    }
  }

  Future<void> _loadPlanInfo() async {
    try {
      final service = ref.read(appointmentServiceProvider);
      final info = await service.getConsultationPlanInfo(
          widget.apt.patientId!, widget.apt.doctorId);
      if (mounted) {
        setState(() {
          _planInfoLoaded = true;
          _hasPlan = info?['hasPlan'] as bool? ?? false;
          _consultationId = info?['consultationId'] as String?;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _planInfoLoaded = true);
    }
  }

  @override
  void didUpdateWidget(_ScheduleCard old) {
    super.didUpdateWidget(old);
    // Re-check plan when consultation form is newly saved
    if (!old.apt.consultationFormSaved &&
        widget.apt.consultationFormSaved &&
        widget.apt.patientId != null &&
        widget.apt.patientId!.isNotEmpty) {
      _planInfoLoaded = false;
      _loadPlanInfo();
    }
    // Also re-check if form already saved but plan state may have changed
    // (e.g., doctor just created a plan and returned to the list)
    else if (widget.apt.consultationFormSaved &&
        widget.apt.patientId != null &&
        widget.apt.patientId!.isNotEmpty &&
        _planInfoLoaded &&
        !_hasPlan) {
      // Silently refresh to pick up newly created plan
      _loadPlanInfo();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.apt;

    Color statusColor = AppColors.success;
    String statusStr = 'Completed';
    IconData statusIcon = Icons.check_circle_rounded;

    if (widget.isMissed) {
      statusColor = AppColors.error; statusStr = 'Missed'; statusIcon = Icons.event_busy_rounded;
    } else if (apt.status == AppointmentStatus.cancelled) {
      statusColor = AppColors.error; statusStr = 'Cancelled'; statusIcon = Icons.cancel_rounded;
    } else if (apt.status == AppointmentStatus.inProgress) {
      statusColor = AppColors.warning; statusStr = 'In Progress'; statusIcon = Icons.sync_rounded;
    } else if (apt.status == AppointmentStatus.scheduled) {
      statusColor = AppColors.info; statusStr = 'Scheduled'; statusIcon = Icons.access_time_filled;
    }

    final isCallBy = apt.type == AppointmentType.callBy;
    final typeColor = isCallBy ? AppColors.info : AppColors.accent;
    final typeLabel = isCallBy ? 'Call-By' : 'Walk-In';
    final typeIcon = isCallBy ? Icons.phone_in_talk_rounded : Icons.directions_walk_rounded;

    final isScheduled = apt.status == AppointmentStatus.scheduled;
    final isInProgress = apt.status == AppointmentStatus.inProgress;
    final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;

    // ── Workflow state flags ──────────────────────────────────────────────────

    // Step 1: Patient Arrived
    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showRescheduleBtn = isScheduled && widget.isFutureDate && !widget.isMissed;

    // Step 2: Fill Patient Details (only for call-by — walk-in already has patient linked)
    final showFillDetailsBtn = isInProgress && !hasPatientLinked && isCallBy;
    // Once opened but not submitted → show "Resume"
    final fillDetailsLabel = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? 'Resume Filling Details'
        : 'Fill Patient Details';
    final fillDetailsIcon = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? Icons.edit_note_rounded
        : Icons.badge_rounded;

    // Step 3: Start/Resume Consultation (only after details saved)
    final showStartConsultationBtn = isInProgress &&
        hasPatientLinked &&
        apt.patientDetailsSaved &&
        !apt.consultationFormSaved;
    // Once opened but not submitted → show "Resume"
    final consultationLabel = apt.consultationStartTime != null && !apt.consultationFormSaved
        ? 'Resume Consultation'
        : 'Start Consultation';
    final consultationIcon = apt.consultationStartTime != null && !apt.consultationFormSaved
        ? Icons.restart_alt_rounded
        : Icons.medical_services_rounded;

    // Step 4: Create/Resume Treatment Plan + End Appointment
    //   Show only after consultation form is saved AND plan not yet fully linked
    final showPlanSection = apt.consultationFormSaved && apt.linkedTreatmentPlanId == null;
    final planLabel = apt.treatmentPlanPartial ? 'Resume Treatment Plan' : 'Create Plan';
    final planIcon = apt.treatmentPlanPartial ? Icons.restart_alt_rounded : Icons.add_chart_rounded;

    final isReceptionist = ref.read(authProvider).role == UserRole.receptionist;
    final effectiveShowStartConsultation = showStartConsultationBtn && !isReceptionist;
    final effectiveShowPlanSection = showPlanSection && !isReceptionist;
    final showEndedBtn = apt.consultationFormSaved && !isReceptionist;

    // Left accent color
    final accentColor = widget.isMissed || apt.status == AppointmentStatus.cancelled
        ? AppColors.error
        : widget.isLate
            ? AppColors.warning
            : isInProgress
                ? AppColors.warning
                : statusColor;

    final hasActions = showArrivedBtn || showRescheduleBtn || showFillDetailsBtn ||
        effectiveShowStartConsultation || effectiveShowPlanSection || showEndedBtn;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: apt.status == AppointmentStatus.cancelled ? null : () {
            HapticFeedback.mediumImpact();
            widget.onLongPress();
          },
          child: Opacity(
            opacity: widget.isMissed || apt.status == AppointmentStatus.cancelled ? 0.65 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left accent strip ──
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                          ),
                        ),
                      ),

                      // ── Card body ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar circle
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(typeIcon, color: typeColor, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name + meta
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          apt.displayName,
                                          style: AppTextStyles.h3.copyWith(fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            // Status pill
                                            _Pill(
                                              label: statusStr,
                                              icon: statusIcon,
                                              color: statusColor,
                                            ),
                                            // Type pill
                                            _Pill(
                                              label: typeLabel,
                                              icon: typeIcon,
                                              color: typeColor,
                                            ),
                                          ],
                                        ),
                                        // Workflow progress indicators
                                        if (apt.checkInTime != null) ...[
                                          const SizedBox(height: 5),
                                          _MetaRow(
                                            icon: Icons.login_rounded,
                                            label: 'Arrived ${DateFormat('h:mm a').format(apt.checkInTime!.toLocal())}',
                                            color: AppColors.success,
                                          ),
                                        ],
                                        if (apt.patientDetailsSaved) ...[
                                          const SizedBox(height: 3),
                                          _MetaRow(
                                            icon: Icons.badge_rounded,
                                            label: 'Patient details filled ✓',
                                            color: AppColors.success,
                                          ),
                                        ],
                                        if (apt.consultationStartTime != null) ...[
                                          const SizedBox(height: 3),
                                          _MetaRow(
                                            icon: Icons.medical_services_rounded,
                                            label: apt.consultationFormSaved
                                                ? 'Consultation recorded ✓'
                                                : 'Consultation started ${DateFormat('h:mm a').format(apt.consultationStartTime!.toLocal())}',
                                            color: apt.consultationFormSaved
                                                ? AppColors.success
                                                : AppColors.primary,
                                          ),
                                        ],
                                        if (apt.linkedTreatmentPlanId != null) ...[
                                          const SizedBox(height: 3),
                                          _MetaRow(
                                            icon: Icons.check_circle_rounded,
                                            label: 'Treatment plan created ✓',
                                            color: AppColors.success,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right column: time badge + phone
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Time badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          TimeUtils.formatStringTime(apt.time),
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      if (apt.patientPhone != null && apt.patientPhone!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () async {
                                            try { await launchUrl(Uri.parse('tel:${apt.patientPhone}')); } catch (_) {}
                                          },
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppColors.success.withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: const Icon(Icons.phone_rounded,
                                                color: AppColors.success, size: 16),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Banners
                            if (widget.isMissed)
                              _InfoBanner(Icons.event_busy_rounded,
                                  'Patient missed this appointment', AppColors.error),
                            if (widget.isLate && !widget.isMissed)
                              _InfoBanner(Icons.warning_amber_rounded,
                                  'Patient is late — hasn\'t arrived yet', AppColors.warning),

                            // Actions
                            if (hasActions) ...[
                              Divider(
                                  color: AppColors.border.withValues(alpha: 0.6),
                                  height: 1),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    // Row 1: Arrived / Reschedule / Fill Details / Start Consultation
                                    if (showArrivedBtn || showRescheduleBtn ||
                                        showFillDetailsBtn || effectiveShowStartConsultation)
                                      Row(children: [
                                        if (showArrivedBtn)
                                          Expanded(child: _ActionButton(
                                            label: 'Patient Arrived',
                                            icon: Icons.how_to_reg_rounded,
                                            color: AppColors.success,
                                            onTap: widget.onArrived,
                                          )),
                                        if (showRescheduleBtn)
                                          Expanded(child: _ActionButton(
                                            label: 'Reschedule',
                                            icon: Icons.event_repeat_rounded,
                                            color: AppColors.info,
                                            onTap: widget.onReschedule,
                                          )),
                                        if (showFillDetailsBtn)
                                          Expanded(child: _ActionButton(
                                            label: fillDetailsLabel,
                                            icon: fillDetailsIcon,
                                            color: apt.patientDetailsPartial
                                                ? AppColors.warning
                                                : AppColors.info,
                                            onTap: widget.onFillDetails,
                                          )),
                                        if (effectiveShowStartConsultation) ...[
                                          if (showFillDetailsBtn) const SizedBox(width: 7),
                                          Expanded(child: _ActionButton(
                                            label: consultationLabel,
                                            icon: consultationIcon,
                                            color: apt.consultationStartTime != null
                                                ? AppColors.warning
                                                : AppColors.primary,
                                            onTap: widget.onStartConsultation,
                                          )),
                                        ],
                                      ]),

                                    // Row 2: Undo Arrived (inline undo for inProgress with no details yet)
                                    if (isInProgress && apt.checkInTime != null &&
                                        !apt.patientDetailsSaved && !apt.consultationFormSaved) ...[
                                      const SizedBox(height: 7),
                                      Row(children: [
                                        Expanded(child: _ActionButton(
                                          label: 'Undo Arrival',
                                          icon: Icons.undo_rounded,
                                          color: AppColors.textSecondary,
                                          onTap: widget.onUndoArrived,
                                        )),
                                      ]),
                                    ],

                                    // Row 3: Create/Resume Treatment Plan + End Appointment
                                    if (effectiveShowPlanSection || showEndedBtn) ...[
                                      if (showArrivedBtn || showRescheduleBtn ||
                                          showFillDetailsBtn || effectiveShowStartConsultation)
                                        const SizedBox(height: 7),
                                      Row(children: [
                                        if (effectiveShowPlanSection) ...[
                                          Expanded(child: _ActionButton(
                                            label: planLabel,
                                            icon: planIcon,
                                            color: apt.treatmentPlanPartial
                                                ? AppColors.warning
                                                : AppColors.primary,
                                            onTap: () async {
                                              await Future.microtask(
                                                () => widget.onCreatePlan(
                                                    _consultationId ?? ''),
                                              );
                                              if (mounted) {
                                                setState(() {
                                                  _planInfoLoaded = false;
                                                  _hasPlan = false;
                                                });
                                                _loadPlanInfo();
                                              }
                                            },
                                          )),
                                          const SizedBox(width: 7),
                                        ],
                                        if (showEndedBtn)
                                          Expanded(child: _ActionButton(
                                            label: 'End Appointment',
                                            icon: Icons.check_circle_outline_rounded,
                                            color: AppColors.success,
                                            onTap: widget.onEnded,
                                          )),
                                      ]),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Treatment Session Card — distinct flow from consultation cards
// ════════════════════════════════════════════════════════════════════

class _SessionCard extends ConsumerStatefulWidget {
  final AppointmentModel apt;
  final int index;
  final bool isLate;
  final bool isFutureDate;
  final bool isMissed;
  final VoidCallback onArrived;
  final VoidCallback onStartSession;
  final VoidCallback onSessionEnded;
  final VoidCallback onReschedule;
  final VoidCallback onLongPress;

  const _SessionCard({
    super.key,
    required this.apt,
    required this.index,
    required this.isLate,
    required this.isFutureDate,
    required this.isMissed,
    required this.onArrived,
    required this.onStartSession,
    required this.onSessionEnded,
    required this.onReschedule,
    required this.onLongPress,
  });

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  int _sessionNumber = 0;
  bool _sessionNumLoaded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
    _loadSessionNumber();
  }

  Future<void> _loadSessionNumber() async {
    try {
      final service = ref.read(appointmentServiceProvider);
      final num = await service.getSessionNumberForAppointment(widget.apt);
      if (mounted && num > 0) setState(() => _sessionNumber = num);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.apt;
    final isScheduled = apt.status == AppointmentStatus.scheduled;
    final isWaiting = apt.status == AppointmentStatus.waiting;
    final isInProgress = apt.status == AppointmentStatus.inProgress;
    final bool isCancelled = apt.status == AppointmentStatus.cancelled;
    final bool isCompleted = apt.status == AppointmentStatus.completed;

    const kWaiting = Color(0xFFF59E0B);
    Color statusColor;
    String statusStr;
    IconData statusIcon;
    if (widget.isMissed) {
      statusColor = AppColors.error; statusStr = 'Missed'; statusIcon = Icons.event_busy_rounded;
    } else if (isCancelled) {
      statusColor = AppColors.error; statusStr = 'Cancelled'; statusIcon = Icons.cancel_rounded;
    } else if (isCompleted) {
      statusColor = AppColors.success; statusStr = 'Completed'; statusIcon = Icons.check_circle_rounded;
    } else if (isInProgress) {
      statusColor = AppColors.warning; statusStr = 'In Progress'; statusIcon = Icons.sync_rounded;
    } else if (isWaiting) {
      statusColor = kWaiting; statusStr = 'Patient Waiting'; statusIcon = Icons.hourglass_empty_rounded;
    } else {
      statusColor = const Color(0xFF7C3AED); statusStr = 'Scheduled'; statusIcon = Icons.healing_rounded;
    }

    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showStartBtn   = isWaiting && !widget.isFutureDate;
    final showEndedBtn   = isInProgress;
    final showRescheduleBtn = isScheduled && widget.isFutureDate;

    const sessionAccent = Color(0xFF7C3AED);
    final accentColor = widget.isMissed || isCancelled
        ? AppColors.error
        : widget.isLate
            ? AppColors.warning
            : isInProgress
                ? AppColors.warning
                : isWaiting
                    ? kWaiting
                    : sessionAccent;

    final hasActions = showArrivedBtn || showStartBtn || showEndedBtn || showRescheduleBtn;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: null,
          onLongPress: isCancelled ? null : () {
            HapticFeedback.mediumImpact();
            widget.onLongPress();
          },
          child: Opacity(
            opacity: (widget.isMissed || isCancelled || isCompleted) ? 0.65 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left accent strip ──
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                          ),
                        ),
                      ),

                      // ── Card body ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon avatar
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: sessionAccent.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.healing_rounded,
                                        color: sessionAccent, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name + meta
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          apt.displayName,
                                          style: AppTextStyles.h3.copyWith(fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _Pill(
                                              label: statusStr,
                                              icon: statusIcon,
                                              color: statusColor,
                                            ),
                                            _Pill(
                                              label: _sessionNumber > 0
                                                  ? 'Session #$_sessionNumber'
                                                  : 'Treatment',
                                              icon: Icons.healing_rounded,
                                              color: sessionAccent,
                                            ),
                                          ],
                                        ),
                                        if (apt.checkInTime != null) ...[
                                          const SizedBox(height: 5),
                                          _MetaRow(
                                            icon: Icons.login_rounded,
                                            label: 'Arrived ${DateFormat('h:mm a').format(apt.checkInTime!.toLocal())}',
                                            color: AppColors.success,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Time badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      TimeUtils.formatStringTime(apt.time),
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Banners
                            if (widget.isMissed)
                              _InfoBanner(Icons.event_busy_rounded,
                                  'Patient missed this session', AppColors.error),
                            if (widget.isLate && !widget.isMissed && isScheduled)
                              _InfoBanner(Icons.warning_amber_rounded,
                                  'Patient is late — hasn\'t arrived yet', AppColors.warning),
                            if (isWaiting)
                              _InfoBanner(Icons.hourglass_empty_rounded,
                                  'Patient waiting — tap Start Session when ready', kWaiting),
                            if (isInProgress)
                              _InfoBanner(Icons.sync_rounded,
                                  'Session in progress', AppColors.warning),

                            // Actions
                            if (hasActions) ...[
                              Divider(
                                  color: AppColors.border.withValues(alpha: 0.6),
                                  height: 1),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(children: [
                                  if (showArrivedBtn)
                                    Expanded(child: _ActionButton(
                                      label: 'Patient Arrived',
                                      icon: Icons.how_to_reg_rounded,
                                      color: AppColors.success,
                                      onTap: widget.onArrived,
                                    )),
                                  if (showStartBtn)
                                    Expanded(child: _ActionButton(
                                      label: 'Start Session',
                                      icon: Icons.play_arrow_rounded,
                                      color: AppColors.primary,
                                      onTap: widget.onStartSession,
                                    )),
                                  if (showEndedBtn)
                                    Expanded(child: _ActionButton(
                                      label: 'End Session',
                                      icon: Icons.check_circle_outline_rounded,
                                      color: AppColors.success,
                                      onTap: widget.onSessionEnded,
                                    )),
                                  if (showRescheduleBtn)
                                    Expanded(child: _ActionButton(
                                      label: 'Reschedule',
                                      icon: Icons.event_repeat_rounded,
                                      color: AppColors.info,
                                      onTap: widget.onReschedule,
                                    )),
                                ]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Pill({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _InfoBanner(this.icon, this.message, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.15), width: 0.8),
        ),
      ),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.caption.copyWith(
                color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
