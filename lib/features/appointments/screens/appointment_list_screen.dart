// AUTO-GENERATED â€” Web-only layout.
import 'package:flutter/material.dart';
import 'dart:ui';
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
import '../../../core/services/session_lifecycle_service.dart';
import 'patient_info_screen.dart';
import '../../patients/screens/patient_profile_screen.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../treatments/providers/treatment_provider.dart';
import '../../treatments/models/session_model.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import '../../../core/services/session_timer_service.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/widgets/responsive_wrapper.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

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
  bool _hasMultipleDoctors = false;
  bool _lifecycleChecked = false;
  String? _clinicLocation;
  String _selectedListFilter = 'all'; // 'all', 'consultations', 'sessions'
  String _activeQuickFilter = 'today'; // 'today', 'tomorrow', 'this_week', 'all'
  int? _todayCount;
  int? _tomorrowCount;
  int? _thisWeekCount;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
      _runLifecycleCheck();
      _checkMultipleDoctors();
      _loadClinicLocation();
      _loadQuickLinkCounts();
    });
  }

  /// Auto-mark missed sessions from past days and show rescheduling summary.
  Future<void> _runLifecycleCheck() async {
    if (_lifecycleChecked) return;
    _lifecycleChecked = true;

    final auth = ref.read(authProvider);
    final pb = ref.read(pocketbaseProvider);
    final lifecycle = SessionLifecycleService(pb);

    List<String> allSummaries = [];

    if (auth.role == UserRole.clinic && auth.clinicId != null) {
      // Clinic: check for all doctors in the clinic
      try {
        final docs = await pb.collection('doctors').getList(
          filter: 'clinic = "${auth.clinicId}"',
          perPage: 50,
        );
        for (final doc in docs.items) {
          final sums = await lifecycle.checkAndMarkMissedSessions(doc.id);
          allSummaries.addAll(sums);
        }
      } catch (_) {}
    } else if (auth.userId != null) {
      allSummaries = await lifecycle.checkAndMarkMissedSessions(auth.userId!);
    }

    if (allSummaries.isNotEmpty && mounted) {
      // Separate pause prompts from regular rescheduling summaries
      final pausePrompts = allSummaries.where((s) => s.startsWith('PAUSE_PROMPT:')).toList();
      final rescheduleSummaries = allSummaries.where((s) => !s.startsWith('PAUSE_PROMPT:')).toList();

      ref.read(appointmentListProvider.notifier).loadAppointments();

      // Show rescheduling notification
      if (rescheduleSummaries.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${rescheduleSummaries.length} session(s) auto-rescheduled:\n${rescheduleSummaries.take(3).join('\n')}'
            '${rescheduleSummaries.length > 3 ? '\n...and ${rescheduleSummaries.length - 3} more' : ''}',
          ),
          backgroundColor: context.colors.warning,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }

      // Show pause dialogs for plans that hit the 3-miss limit
      for (final prompt in pausePrompts) {
        if (!mounted) break;
        final parts = prompt.split(':');
        if (parts.length < 4) continue;
        final planId = parts[1];
        final patientName = parts[2];
        final missCount = parts[3];
        await _showPausePromptDialog(planId, patientName, int.tryParse(missCount) ?? 3);
      }
    }
  }

  /// Show dialog when a plan hits the 3-consecutive-miss limit.
  Future<void> _showPausePromptDialog(String planId, String patientName, int missCount) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.colors.surface,
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('$missCount Consecutive Misses', style: context.textStyles.h3)),
        ]),
        content: Text(
          '$patientName has missed $missCount consecutive sessions.\n\nWould you like to pause their sessions or continue auto-rescheduling?',
          style: context.textStyles.bodyMedium,
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'pause'),
            icon: Icon(Icons.pause_circle_rounded, color: context.colors.error, size: 18),
            label: Text('Pause Sessions', style: TextStyle(color: context.colors.error, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            icon: const Icon(Icons.fast_forward_rounded, size: 18),
            label: const Text('Continue Rescheduling'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == 'pause') {
      try {
        final service = ref.read(treatmentServiceProvider);
        await service.pauseSessions(planId);
        ref.read(appointmentListProvider.notifier).loadAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sessions for $patientName have been paused'),
            backgroundColor: context.colors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (mounted) _showError('Failed to pause: $e');
      }
    } else if (result == 'continue') {
      // Reset the consecutive miss counter and let auto-reschedule continue
      try {
        final pb = ref.read(pocketbaseProvider);
        await pb.collection('treatment_plans').update(planId, body: {
          'consecutive_misses': 0,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Auto-rescheduling will continue for $patientName'),
            backgroundColor: context.colors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (mounted) _showError('Failed: $e');
      }
    }
  }

  /// Check if the clinic has multiple doctors (for showing doctor name on cards).
  Future<void> _checkMultipleDoctors() async {
    final auth = ref.read(authProvider);
    if (auth.role != UserRole.clinic || auth.clinicId == null) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      final docs = await pb.collection('doctors').getList(
        filter: 'clinic = "${auth.clinicId}"',
        perPage: 2,
      );
      if (mounted && docs.items.length > 1) {
        setState(() => _hasMultipleDoctors = true);
      }
    } catch (_) {}
  }

  /// Load the clinic's location for WhatsApp "Send Location" feature.
  /// Works for all roles: clinic admin, doctor, and receptionist.
  Future<void> _loadClinicLocation() async {
    final auth = ref.read(authProvider);

    // For clinic admin, use auth.clinic directly
    if (auth.clinic?.location != null && auth.clinic!.location!.isNotEmpty) {
      _clinicLocation = auth.clinic!.location;
      return;
    }

    // For doctor/receptionist, fetch clinic from PB using clinicId
    final clinicId = auth.clinicId;
    if (clinicId == null || clinicId.isEmpty) return;

    try {
      final pb = ref.read(pocketbaseProvider);
      final rec = await pb.collection('clinics').getOne(clinicId);
      final location = rec.getStringValue('location');
      if (location.isNotEmpty && mounted) {
        setState(() => _clinicLocation = location);
      }
    } catch (_) {}
  }

  Future<void> _loadQuickLinkCounts() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      final userId = auth.userId;
      if (userId == null || userId.isEmpty) return;

      final filterPrefix = auth.role == UserRole.clinic
          ? 'clinic = "$userId"'
          : 'doctor = "$userId"';

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final mondayStr = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final sundayStr = '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';

      final todayRes = await pb.collection('appointments').getList(
        filter: '$filterPrefix && date = "$todayStr"',
        perPage: 1,
        fields: 'id',
      );
      final tomorrowRes = await pb.collection('appointments').getList(
        filter: '$filterPrefix && date = "$tomorrowStr"',
        perPage: 1,
        fields: 'id',
      );
      final weekRes = await pb.collection('appointments').getList(
        filter: '$filterPrefix && date >= "$mondayStr" && date <= "$sundayStr"',
        perPage: 1,
        fields: 'id',
      );

      if (mounted) {
        setState(() {
          _todayCount = todayRes.totalItems;
          _tomorrowCount = tomorrowRes.totalItems;
          _thisWeekCount = weekRes.totalItems;
        });
      }
    } catch (e) {
      debugPrint('Error loading quick link counts: $e');
    }
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

  // Ã¢â€â‚¬Ã¢â€â‚¬ Consultation card actions Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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
      // Audit log for receptionist actions
      final auth = ref.read(authProvider);
      if (auth.role == UserRole.receptionist) {
        ref.read(auditServiceProvider).log(
          userId: auth.userId ?? '',
          userRole: 'receptionist',
          action: AuditAction.markArrived,
          targetId: apt.id,
          details: 'Marked ${apt.displayName} as arrived',
        );
      }
      ref.read(appointmentListProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${apt.displayName} marked as arrived \u2713'),
          backgroundColor: context.colors.success,
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
          content: Text('${apt.displayName} \u2014 consultation ended \u2713'),
          backgroundColor: context.colors.success,
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
        backgroundColor: context.colors.surface,
        title: Text('Cancel Appointment?', style: TextStyle(color: context.colors.error)),
        content: Text('Cancel for ${apt.displayName} at ${TimeUtils.formatStringTime(apt.time)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Cancel', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(appointmentListProvider.notifier).updateStatus(apt.id, AppointmentStatus.cancelled);
      // Audit log for receptionist actions
      final auth = ref.read(authProvider);
      if (auth.role == UserRole.receptionist) {
        ref.read(auditServiceProvider).log(
          userId: auth.userId ?? '',
          userRole: 'receptionist',
          action: AuditAction.cancelAppointment,
          targetId: apt.id,
          details: 'Cancelled appointment for ${apt.displayName}',
        );
      }
    }
  }

  Future<void> _undoArrived(AppointmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Row(children: [
          Icon(Icons.undo_rounded, color: context.colors.warning, size: 22),
          const SizedBox(width: 10),
          const Text('Undo Arrival?'),
        ]),
        content: Text('Revert ${apt.displayName}\'s arrival back to scheduled?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.warning, foregroundColor: Colors.white),
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
            content: Text('${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} \u2713'),
            backgroundColor: context.colors.success,
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
    if (!apt.patientDetailsSaved) {
      if (mounted) _showError('Please fill and submit patient details before starting a consultation.');
      return;
    }
    if (apt.consultationFormSaved) return;
    try {
      final service = ref.read(appointmentServiceProvider);
      // Uses getOne() via linkedConsultationId Ã¢â‚¬â€ no list query needed
      final (consultationId, isNew) = await service.getOrCreateConsultationForAppointment(apt);
      // Fire-and-forget: stamp start time without blocking navigation
      if (isNew || apt.consultationStartTime == null) {
        service.setConsultationStartTime(apt.id);
      }
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationScreen(
              patientId: apt.patientId!,
              patientName: apt.displayName,
              doctorId: apt.doctorId,
              consultationId: consultationId,
              appointmentId: apt.id,
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
      final patientName = apt.displayName;
      if (mounted) {
        final result = await Navigator.push<dynamic>(
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

        // Handle both old `true` return and new map return
        final bool planCreated;
        final bool firstSessionToday;
        if (result is Map) {
          planCreated = result['success'] == true;
          firstSessionToday = result['firstSessionToday'] == true;
        } else {
          planCreated = result == true;
          firstSessionToday = false;
        }

        if (planCreated) {
          ref.read(analyticsProvider.notifier).load();

          if (firstSessionToday) {
            // Auto-end the consultation appointment Ã¢â‚¬â€ 1st session is being handled today
            final service = ref.read(appointmentServiceProvider);
            await service.markEnded(apt.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text(
                  'Treatment plan created & consultation ended. Session 1 is waiting on today\'s schedule.'),
                backgroundColor: context.colors.success,
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            }
          } else {
            // Don't auto-end Ã¢â‚¬â€ sessions start on a different day
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text(
                  'Treatment plan created & sessions scheduled! You may end this appointment now or keep it open.'),
                backgroundColor: context.colors.success,
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            }
          }
        }
        ref.read(appointmentListProvider.notifier).loadAppointments();
      }
    } catch (e) {
      if (mounted) _showError('Failed to open plan creator: $e');
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Session card actions Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<void> _markSessionArrived(AppointmentModel apt) async {
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.markSessionArrived(apt.id);
      // Audit log for receptionist actions
      final auth = ref.read(authProvider);
      if (auth.role == UserRole.receptionist) {
        ref.read(auditServiceProvider).log(
          userId: auth.userId ?? '',
          userRole: 'receptionist',
          action: AuditAction.markArrived,
          targetId: apt.id,
          details: 'Marked ${apt.displayName} session as arrived',
        );
      }
      // Reset consecutive miss counter since patient showed up
      if (apt.patientId != null && apt.patientId!.isNotEmpty) {
        try {
          final treatmentService = ref.read(treatmentServiceProvider);
          final sess = await treatmentService.findSessionForAppointment(
            patientId: apt.patientId!, date: apt.date, time: apt.time, doctorId: apt.doctorId,
          );
          if (sess != null) {
            final pb = ref.read(pocketbaseProvider);
            await pb.collection(PBCollections.treatmentPlans).update(
              sess.treatmentPlanId, body: {'consecutive_misses': 0},
            );
          }
        } catch (_) {}
      }
      ref.read(appointmentListProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${apt.displayName} is now waiting for session \u2713'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  Future<void> _markStartSession(AppointmentModel apt, {String? preloadedSessionId}) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return;
    try {
      SessionModel? session;
      final treatmentService = ref.read(treatmentServiceProvider);

      if (preloadedSessionId != null) {
        // Card already resolved this Ã¢â‚¬â€ skip the PB query
        try {
          final pb = ref.read(pocketbaseProvider);
          final rec = await pb.collection(PBCollections.sessions).getOne(preloadedSessionId);
          session = SessionModel.fromRecord(rec);
        } catch (_) {}
      }

      if (session == null) {
        // Fallback: lookup via cascading query
        session = await treatmentService.findSessionForAppointment(
          patientId: apt.patientId!,
          date: apt.date,
          time: apt.time,
          doctorId: apt.doctorId,
        );
      }

      // Fire-and-forget: start session status updates without blocking navigation
      final service = ref.read(appointmentServiceProvider);
      service.startSession(apt.id);
      if (session != null) {
        treatmentService.startSessionRecord(session.id);
      }
      ref.read(appointmentListProvider.notifier).loadAppointments();

      // Navigate immediately
      if (session != null && mounted) {
        await Navigator.pushNamed(
          context,
          '/sessions/record',
          arguments: {
            'session': session,
            'patientName': apt.displayName,
          },
        );
        ref.read(appointmentListProvider.notifier).loadAppointments();
      } else if (mounted) {
        // Fallback: try broader lookup
        await _openSessionDirectly(apt);
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  Future<void> _markSessionEnded(AppointmentModel apt, {String? preloadedSessionId}) async {
    String? resolvedSessionId = preloadedSessionId;
    SessionModel? resolvedSession;
    bool hasTimer = false;
    try {
      if (resolvedSessionId != null) {
        // Card already has the session ID Ã¢â‚¬â€ just check timer status
        hasTimer = SessionTimerService.instance.hasActiveTimer(resolvedSessionId);
      } else {
        final treatmentService = ref.read(treatmentServiceProvider);
        final session = await treatmentService.findSessionForAppointment(
          patientId: apt.patientId!,
          date: apt.date,
          time: apt.time,
          doctorId: apt.doctorId,
        );
        if (session != null) {
          resolvedSession = session;
          resolvedSessionId = session.id;
          hasTimer = SessionTimerService.instance.hasActiveTimer(session.id);
        }
      }
    } catch (_) {}

    // Fallback: check by patient name if session lookup failed or returned no active timer
    TimerSnapshot? fallbackTimer;
    if (!hasTimer) {
      fallbackTimer = SessionTimerService.instance.getActiveTimerByPatientName(apt.displayName);
      if (fallbackTimer != null) {
        hasTimer = true;
        resolvedSessionId = fallbackTimer.sessionId;
      }
    }

    if (hasTimer && resolvedSessionId != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: context.colors.surface,
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 24),
            const SizedBox(width: 10),
            Text('Timer Still Running', style: context.textStyles.h4),
          ]),
          content: Text(
            'A session timer is still active for ${apt.displayName}.',
            style: context.textStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.colors.textHint)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.error),
              child: const Text('Stop Timer & End Session', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      // Stop the timer
      SessionTimerService.instance.endTimer(resolvedSessionId);
    }
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.markSessionEnded(apt.id, sessionId: resolvedSessionId);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      ref.read(analyticsProvider.notifier).load(); // background refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session for ${apt.displayName} completed \u2713'),
          backgroundColor: context.colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  /// Fetch the session model for [apt] and push RecordSessionScreen.
  Future<void> _openSessionDirectly(AppointmentModel apt, {String? preloadedSessionId}) async {
    // Block navigation for future/scheduled sessions Ã¢â‚¬â€ only reschedule is available
    if (apt.status == AppointmentStatus.scheduled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Session hasn\'t started yet. Only reschedule is available.'),
          backgroundColor: context.colors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      return;
    }
    if (apt.patientId == null || apt.patientId!.isEmpty) return;
    try {
      SessionModel? session;
      final treatmentService = ref.read(treatmentServiceProvider);

      if (preloadedSessionId != null) {
        try {
          final pb = ref.read(pocketbaseProvider);
          final rec = await pb.collection(PBCollections.sessions).getOne(preloadedSessionId);
          session = SessionModel.fromRecord(rec);
        } catch (_) {}
      }

      if (session == null) {
        session = await treatmentService.findSessionForAppointment(
          patientId: apt.patientId!,
          date: apt.date,
          time: apt.time,
          doctorId: apt.doctorId,
        );
      }
      if (!mounted) return;
      if (session == null) {
        // Fallback: open patient profile on Treatments tab
        final pb = ref.read(pocketbaseProvider);
        final pRec = await pb.collection(PBCollections.patients).getOne(apt.patientId!);
        final p = PatientModel.fromRecord(pRec);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientProfileScreen(patient: p, initialTabIndex: 0),
            ),
          );
        }
        return;
      }
      if (mounted) {
        await Navigator.pushNamed(
          context,
          '/sessions/record',
          arguments: {
            'session': session,
            'patientName': apt.displayName,
          },
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
            content: Text('Session for ${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} \u2713'),
            backgroundColor: context.colors.success,
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
        backgroundColor: context.colors.surface,
        title: Text('Cancel Session?', style: TextStyle(color: context.colors.error)),
        content: Text('Cancel session for ${apt.displayName} at ${TimeUtils.formatStringTime(apt.time)}?\n\nThis will also remove it from the treatment plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Cancel', style: TextStyle(color: context.colors.error)),
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
      backgroundColor: context.colors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _buildNewAppointmentButton({bool compact = false}) {
    return PopupMenuButton<bool>(
      onSelected: (isCallBy) {
        Navigator.pushNamed(
          context,
          '/appointments/create',
          arguments: {'isCallBy': isCallBy},
        ).then((_) {
          ref.read(appointmentListProvider.notifier).loadAppointments();
          _loadQuickLinkCounts();
        });
      },
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: context.colors.surface,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: true,
          child: Row(
            children: [
              Icon(Icons.event_note_rounded, color: context.colors.info, size: 18),
              const SizedBox(width: 10),
              Text('Call-By Appointment', style: context.textStyles.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          value: false,
          child: Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: context.colors.accent, size: 18),
              const SizedBox(width: 10),
              Text('Walk-In Appointment', style: context.textStyles.bodyMedium),
            ],
          ),
        ),
      ],
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                'New Appointment',
                style: context.textStyles.buttonMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(width: 8),
              const VerticalDivider(
                color: Colors.white24,
                width: 1,
                indent: 10,
                endIndent: 10,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  void _showAppointmentTypeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Appointment',
                      style: context.textStyles.h3.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSelectorTile(
                  context: context,
                  icon: Icons.event_note_rounded,
                  color: context.colors.info,
                  title: 'Call-By Appointment',
                  subtitle: 'Schedule a pre-booked time slot via phone call',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreateAppointment(true);
                  },
                ),
                const SizedBox(height: 12),
                _buildSelectorTile(
                  context: context,
                  icon: Icons.directions_walk_rounded,
                  color: context.colors.accent,
                  title: 'Walk-In Appointment',
                  subtitle: 'Register a patient waiting at the clinic',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreateAppointment(false);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectorTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateAppointment(bool isCallBy) {
    Navigator.pushNamed(
      context,
      '/appointments/create',
      arguments: {'isCallBy': isCallBy},
    ).then((_) {
      ref.read(appointmentListProvider.notifier).loadAppointments();
      _loadQuickLinkCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentListProvider);
    final all = state.appointments;

    ref.listen<AppointmentListState>(appointmentListProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false) {
        _loadQuickLinkCounts();
      }
    });

    final activeConsultationPatientIds = all
        .where((a) => a.type != AppointmentType.session && a.status != AppointmentStatus.completed && a.status != AppointmentStatus.cancelled)
        .map((a) => a.patientId)
        .toSet();

    final consultations = all.where((a) => a.type != AppointmentType.session).toList();
    final sessions = all.where((a) => a.type == AppointmentType.session && !activeConsultationPatientIds.contains(a.patientId)).toList();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    // Build header dates/titles dynamically
    String headerTitle = '';
    bool showHeaderBadge = false;
    if (_activeQuickFilter == 'today') {
      headerTitle = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
      showHeaderBadge = DateUtils.isSameDay(_selectedDate, DateTime.now());
    } else if (_activeQuickFilter == 'tomorrow') {
      headerTitle = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
      showHeaderBadge = true;
    } else if (_activeQuickFilter == 'this_week') {
      headerTitle = 'This Week';
    } else if (_activeQuickFilter == 'all') {
      headerTitle = 'All Appointments';
    } else {
      headerTitle = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
      showHeaderBadge = DateUtils.isSameDay(_selectedDate, DateTime.now());
    }

    String headerSubtitle = 'Showing schedule for selected date \u2022 ${consultations.length + sessions.length} total events';
    if (_activeQuickFilter == 'this_week') {
      headerSubtitle = 'Showing weekly appointments \u2022 ${consultations.length + sessions.length} total events';
    } else if (_activeQuickFilter == 'all') {
      headerSubtitle = 'Showing all appointments \u2022 ${consultations.length + sessions.length} total events';
    }

    return Scaffold(
      backgroundColor: isDesktop ? Colors.transparent : context.colors.background,
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              shape: const CircleBorder(),
              backgroundColor: context.colors.primary,
              onPressed: () => _showAppointmentTypeSelector(context),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: isDesktop
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header spanning full width
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appointments',
                                style: context.textStyles.h1.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage your clinic schedule and appointments',
                                style: context.textStyles.bodyMedium.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          _buildNewAppointmentButton(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WebGlassCard(
                              borderRadius: 26,
                              child: Container(
                                width: 300,
                                child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Title & Header inside card
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: context.colors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.calendar_today_rounded,
                                            color: context.colors.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Calendar',
                                          style: context.textStyles.h3.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Sleek Mini Calendar (Integrated flat inside the panel)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: SleekMiniCalendar(
                                      selectedDate: _selectedDate,
                                      flat: true,
                                      onDateChanged: (date) {
                                        setState(() {
                                          _activeQuickFilter = 'custom';
                                          _selectedDate = date;
                                        });
                                        ref.read(appointmentListProvider.notifier).changeDate(_formatDate(date));
                                      },
                                    ),
                                  ),
                                  
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Divider(
                                      color: context.colors.border.withValues(alpha: 0.3),
                                      height: 1,
                                    ),
                                  ),
                                  
                                  // Quick links header
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                                    child: Text(
                                      'QUICK FILTERS',
                                      style: context.textStyles.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: context.colors.textSecondary.withValues(alpha: 0.6),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  
                                  // Quick filters list
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                    child: Column(
                                      children: [
                                        _quickLinkRow(
                                          label: 'Today',
                                          icon: Icons.today_rounded,
                                          isActive: _activeQuickFilter == 'today',
                                          onTap: () {
                                            setState(() {
                                              _activeQuickFilter = 'today';
                                              _selectedDate = DateTime.now();
                                            });
                                            ref.read(appointmentListProvider.notifier).changeDate(_formatDate(DateTime.now()));
                                          },
                                          count: _todayCount,
                                        ),
                                        const SizedBox(height: 6),
                                        _quickLinkRow(
                                          label: 'Tomorrow',
                                          icon: Icons.wb_sunny_rounded,
                                          isActive: _activeQuickFilter == 'tomorrow',
                                          onTap: () {
                                            setState(() {
                                              _activeQuickFilter = 'tomorrow';
                                              _selectedDate = DateTime.now().add(const Duration(days: 1));
                                            });
                                            ref.read(appointmentListProvider.notifier).changeDate(_formatDate(DateTime.now().add(const Duration(days: 1))));
                                          },
                                          count: _tomorrowCount,
                                        ),
                                        const SizedBox(height: 6),
                                        _quickLinkRow(
                                          label: 'This Week',
                                          icon: Icons.date_range_rounded,
                                          isActive: _activeQuickFilter == 'this_week',
                                          onTap: () {
                                            setState(() {
                                              _activeQuickFilter = 'this_week';
                                            });
                                            final now = DateTime.now();
                                            final monday = now.subtract(Duration(days: now.weekday - 1));
                                            final sunday = monday.add(const Duration(days: 6));
                                            ref.read(appointmentListProvider.notifier).changeDate('range:${_formatDate(monday)}:${_formatDate(sunday)}');
                                          },
                                          count: _thisWeekCount,
                                        ),

                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                            const SizedBox(width: 24),
                            // Right Column: Appointments List with Filter Tabs
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: context.colors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.event_note_rounded,
                                          color: context.colors.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  headerTitle,
                                                  style: context.textStyles.h2.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                  ),
                                                ),
                                                if (showHeaderBadge) ...[
                                                  const SizedBox(width: 12),
                                                  _buildRelativeDateBadge(_selectedDate),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              headerSubtitle,
                                              style: context.textStyles.caption.copyWith(
                                                color: context.colors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      _filterTabItem('All', 'all', consultations.length + sessions.length),
                                      const SizedBox(width: 6),
                                      _filterTabItem('Consultations', 'consultations', consultations.length, color: context.colors.info),
                                      const SizedBox(width: 6),
                                      _filterTabItem('Sessions', 'sessions', sessions.length, color: context.colors.primary),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: state.isLoading
                                        ? Center(child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 3))
                                        : state.error != null
                                            ? _errorView(state.error!)
                                            : (consultations.isEmpty && sessions.isEmpty)
                                                ? _emptyView()
                                                : RefreshIndicator(
                                                    color: context.colors.primary,
                                                    onRefresh: () => ref.read(appointmentListProvider.notifier).loadAppointments(),
                                                    child: _buildAppointmentsListFiltered(
                                                      consultations,
                                                      sessions,
                                                      _hasMultipleDoctors,
                                                      _clinicLocation,
                                                      padding: const EdgeInsets.only(bottom: 100),
                                                    ),
                                                  ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // Ã¢â€â‚¬Ã¢â€â‚¬ Header Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Schedule', style: context.textStyles.h1),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedDate),
                                style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary),
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
                                    gradient: context.colors.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.primary.withValues(alpha: 0.2),
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
                              SizedBox(width: 8),
                              // Calendar button
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.calendar_month_rounded, size: 20, color: context.colors.primary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ã¢â€â‚¬Ã¢â€â‚¬ Horizontal Date Strip Ã¢â€â‚¬Ã¢â€â‚¬
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
                                color: isSelected ? context.colors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(dayLabel, style: context.textStyles.caption.copyWith(
                                    color: isSelected ? Colors.white : context.colors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  )),
                                  const SizedBox(height: 6),
                                  Text(d.day.toString(), style: context.textStyles.h2.copyWith(
                                    color: isSelected ? Colors.white : context.colors.textPrimary,
                                    height: 1,
                                  )),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 4, height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : isToday ? context.colors.primary : Colors.transparent,
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
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: context.colors.border, height: 1),
                    ),
                    SizedBox(height: 8),

                    // Ã¢â€â‚¬Ã¢â€â‚¬ Main Content Ã¢â€â‚¬Ã¢â€â‚¬
                    Expanded(
                      child: state.isLoading
                          ? Center(child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 3))
                          : state.error != null
                              ? _errorView(state.error!)
                              : (consultations.isEmpty && sessions.isEmpty)
                                  ? _emptyView()
                                  : RefreshIndicator(
                                      color: context.colors.primary,
                                      onRefresh: () => ref.read(appointmentListProvider.notifier).loadAppointments(),
                                      child: _buildAppointmentsList(
                                        consultations,
                                        sessions,
                                        _hasMultipleDoctors,
                                        _clinicLocation,
                                      ),
                                    ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(
    List<AppointmentModel> consultations,
    List<AppointmentModel> sessions,
    bool showDoctorName,
    String? clinicLocation, {
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 8, 24, 100),
  }) {
    return ListView(
      padding: padding,
      children: [
        // Ã¢â€â‚¬Ã¢â€â‚¬ Consultations Section Ã¢â€â‚¬Ã¢â€â‚¬
        _sectionHeader('Consultations', Icons.assignment_ind_rounded, consultations.length, context.colors.info),
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
                showDoctorName: showDoctorName,
                clinicLocation: clinicLocation,
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

        SizedBox(height: 24),
        Divider(color: context.colors.border),
        const SizedBox(height: 16),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Treatment Sessions Section Ã¢â€â‚¬Ã¢â€â‚¬
        _sectionHeader('Treatment Sessions', Icons.healing_rounded, sessions.length, context.colors.primary),
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
                showDoctorName: showDoctorName,
                clinicLocation: clinicLocation,
                onArrived: () => _markSessionArrived(e.value),
                onStartSession: (sid) => _markStartSession(e.value, preloadedSessionId: sid),
                onSessionEnded: (sid) => _markSessionEnded(e.value, preloadedSessionId: sid),
                onReschedule: () => _rescheduleSession(e.value),
                onUndoArrived: () => _undoArrived(e.value),
                onLongPress: () => _cancelSession(e.value),
                onTap: (sid) => _openSessionDirectly(e.value, preloadedSessionId: sid),
              ),
            ),
          ),
      ],
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
        Text(title, style: context.textStyles.h3),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: context.textStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _emptySectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(text, style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint))),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: context.colors.textHint.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No appointments today', style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap the + button to create one.', style: context.textStyles.caption),
        ],
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: context.colors.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Desktop Appt List View Helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _quickLinkRow({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    int? count,
  }) {
    final color = isActive ? context.colors.primary : context.colors.textSecondary;
    final bgColor = isActive ? context.colors.primary.withValues(alpha: 0.08) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: context.colors.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (isActive) ...[
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: context.textStyles.bodyMedium.copyWith(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive 
                            ? Colors.white.withValues(alpha: 0.25)
                            : context.colors.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelativeDateBadge(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = target.difference(today).inDays;

    String label = '';
    Color badgeColor;
    
    if (difference == 0) {
      label = 'Today';
      badgeColor = context.colors.success;
    } else if (difference == 1) {
      label = 'Tomorrow';
      badgeColor = context.colors.info;
    } else if (difference == -1) {
      label = 'Yesterday';
      badgeColor = context.colors.error;
    } else if (difference > 1) {
      label = 'Upcoming';
      badgeColor = context.colors.primary;
    } else {
      label = 'Past';
      badgeColor = context.colors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _filterTabItem(String label, String value, int count, {Color? color}) {
    final isActive = _selectedListFilter == value;
    final themeColor = color ?? context.colors.primary;
    
    return _FilterTabButton(
      label: label,
      value: value,
      count: count,
      isActive: isActive,
      themeColor: themeColor,
      onTap: () => setState(() => _selectedListFilter = value),
    );
  }

  Widget _buildAppointmentsListFiltered(
    List<AppointmentModel> consultations,
    List<AppointmentModel> sessions,
    bool showDoctorName,
    String? clinicLocation, {
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 8, 24, 100),
  }) {
    final showConsults = _selectedListFilter == 'all' || _selectedListFilter == 'consultations';
    final showSessions = _selectedListFilter == 'all' || _selectedListFilter == 'sessions';

    return ListView(
      padding: padding,
      children: [
        if (showConsults) ...[
          // Ã¢â€â‚¬Ã¢â€â‚¬ Consultations Section Ã¢â€â‚¬Ã¢â€â‚¬
          _sectionHeader('Consultations', Icons.assignment_ind_rounded, consultations.length, context.colors.info),
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
                  showDoctorName: showDoctorName,
                  clinicLocation: clinicLocation,
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
        ],

        if (_selectedListFilter == 'all' && showConsults && showSessions && consultations.isNotEmpty && sessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Divider(color: context.colors.border),
          const SizedBox(height: 16),
        ],

        if (showSessions) ...[
          // Ã¢â€â‚¬Ã¢â€â‚¬ Treatment Sessions Section Ã¢â€â‚¬Ã¢â€â‚¬
          _sectionHeader('Treatment Sessions', Icons.healing_rounded, sessions.length, context.colors.primary),
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
                  showDoctorName: showDoctorName,
                  clinicLocation: clinicLocation,
                  onArrived: () => _markSessionArrived(e.value),
                  onStartSession: (sid) => _markStartSession(e.value, preloadedSessionId: sid),
                  onSessionEnded: (sid) => _markSessionEnded(e.value, preloadedSessionId: sid),
                  onReschedule: () => _rescheduleSession(e.value),
                  onUndoArrived: () => _undoArrived(e.value),
                  onLongPress: () => _cancelSession(e.value),
                  onTap: (sid) => _openSessionDirectly(e.value, preloadedSessionId: sid),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _FilterTabButton extends StatefulWidget {
  final String label;
  final String value;
  final int count;
  final bool isActive;
  final Color themeColor;
  final VoidCallback onTap;

  const _FilterTabButton({
    required this.label,
    required this.value,
    required this.count,
    required this.isActive,
    required this.themeColor,
    required this.onTap,
  });

  @override
  State<_FilterTabButton> createState() => _FilterTabButtonState();
}

class _FilterTabButtonState extends State<_FilterTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeBgColor = widget.themeColor;
    
    final bgColor = widget.isActive 
        ? activeBgColor 
        : (_isHovered ? context.colors.surface.withValues(alpha: 0.8) : context.colors.surface);

    final textColor = widget.isActive 
        ? Colors.white 
        : (_isHovered ? context.colors.textPrimary : context.colors.textSecondary);

    final countBgColor = widget.isActive 
        ? Colors.white.withValues(alpha: 0.2) 
        : Colors.black.withValues(alpha: 0.2);

    final countTextColor = widget.isActive 
        ? Colors.white 
        : context.colors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.isActive 
                  ? Colors.transparent 
                  : context.colors.border.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: activeBgColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: context.textStyles.caption.copyWith(
                  fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w600,
                  color: textColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: countBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: countTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
// Consultation Schedule Card (call_by + walk_in)
// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

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
  final bool showDoctorName;
  final String? clinicLocation;

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
    this.showDoctorName = false,
    this.clinicLocation,
  });

  @override
  ConsumerState<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<_ScheduleCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Plan info Ã¢â‚¬â€ only loaded when consultation has started (consultationStartTime != null)
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

  Widget _buildMiddleIndicator(BuildContext context, AppointmentModel apt, Color statusColor) {
    if (widget.isMissed) {
      return _indicatorItem(
        context: context,
        icon: Icons.event_busy_rounded,
        iconColor: context.colors.error,
        title: 'Missed',
        subtitle: 'Patient missed appointment',
      );
    } else if (apt.status == AppointmentStatus.cancelled) {
      return _indicatorItem(
        context: context,
        icon: Icons.cancel_rounded,
        iconColor: context.colors.error,
        title: 'Cancelled',
        subtitle: 'Appointment cancelled',
      );
    } else if (widget.isLate && !widget.isMissed && apt.status == AppointmentStatus.scheduled) {
      return _indicatorItem(
        context: context,
        icon: Icons.warning_amber_rounded,
        iconColor: context.colors.warning,
        title: 'Patient is late',
        subtitle: 'Haven\'t arrived yet',
      );
    } else {
      final checkedIn = apt.checkInTime != null;
      return _indicatorItem(
        context: context,
        icon: Icons.circle,
        iconColor: context.colors.success,
        title: 'On time',
        subtitle: checkedIn ? 'Arrived' : 'Arrived on time',
        isDot: true,
      );
    }
  }

  Widget _indicatorItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isDot = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDot
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              )
            : Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: context.textStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.textStyles.caption.copyWith(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactButtons(BuildContext context, AppointmentModel apt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => WhatsAppHelper.showMenu(
            context: context,
            phone: apt.effectivePhone!,
            patientName: apt.displayName,
            appointmentTime: apt.time,
            appointmentDate: apt.date,
            isEnded: apt.status == AppointmentStatus.completed,
            isMissed: widget.isMissed,
            clinicLocation: widget.clinicLocation,
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF25D366).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.chat_rounded,
                color: Color(0xFF25D366), size: 18),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            if (apt.effectivePhone == null || apt.effectivePhone!.isEmpty) return;
            final url = Uri.parse('tel:${apt.effectivePhone}');
            try {
              await launchUrl(url);
            } catch (e) {
              debugPrint('Could not launch phone call: $e');
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.phone_rounded,
                color: Color(0xFF00BFA5), size: 18),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.apt;

    Color statusColor = context.colors.success;
    String statusStr = 'Completed';
    IconData statusIcon = Icons.check_circle_rounded;

    if (widget.isMissed) {
      statusColor = context.colors.error; statusStr = 'Missed'; statusIcon = Icons.event_busy_rounded;
    } else if (apt.status == AppointmentStatus.cancelled) {
      statusColor = context.colors.error; statusStr = 'Cancelled'; statusIcon = Icons.cancel_rounded;
    } else if (apt.status == AppointmentStatus.inProgress) {
      statusColor = context.colors.warning; statusStr = 'In Progress'; statusIcon = Icons.sync_rounded;
    } else if (apt.status == AppointmentStatus.scheduled) {
      statusColor = const Color(0xFF7C3AED); statusStr = 'Scheduled'; statusIcon = Icons.access_time_filled;
    }

    final isCallBy = apt.type == AppointmentType.callBy;
    final typeColor = isCallBy ? context.colors.info : context.colors.accent;
    final typeLabel = isCallBy ? 'Call-By' : 'Walk-In';
    final typeIcon = isCallBy ? Icons.event_note_rounded : Icons.directions_walk_rounded;

    final isScheduled = apt.status == AppointmentStatus.scheduled;
    final isInProgress = apt.status == AppointmentStatus.inProgress;
    final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;

    // Step 1: Patient Arrived
    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showRescheduleBtn = isScheduled && (widget.isFutureDate || !widget.isMissed) || widget.isMissed && !isInProgress;

    // Step 2: Fill Patient Details
    final showFillDetailsBtn = isInProgress && !hasPatientLinked && isCallBy;
    final fillDetailsLabel = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? 'Resume Filling Details'
        : 'Fill Patient Details';
    final fillDetailsIcon = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? Icons.edit_note_rounded
        : Icons.badge_rounded;

    final effectivePatientDetailsSaved = apt.patientDetailsSaved ||
        (!isCallBy && hasPatientLinked);

    // Step 3: Start/Resume Consultation
    final showStartConsultationBtn = isInProgress &&
        hasPatientLinked &&
        effectivePatientDetailsSaved &&
        !apt.consultationFormSaved;
    final consultationLabel = apt.consultationStartTime != null && !apt.consultationFormSaved
        ? 'Resume Consultation'
        : 'Start Consultation';
    final consultationIcon = apt.consultationStartTime != null && !apt.consultationFormSaved
        ? Icons.restart_alt_rounded
        : Icons.medical_services_rounded;

    // Step 4: Create/Resume Treatment Plan + End Appointment
    final showPlanSection = apt.consultationFormSaved &&
        apt.linkedTreatmentPlanId == null &&
        !(_planInfoLoaded && _hasPlan);
    final planLabel = apt.treatmentPlanPartial ? 'Resume Treatment Plan' : 'Create Plan';
    final planIcon = apt.treatmentPlanPartial ? Icons.restart_alt_rounded : Icons.add_chart_rounded;

    final isReceptionist = ref.read(authProvider).role == UserRole.receptionist;
    final effectiveShowStartConsultation = showStartConsultationBtn && !isReceptionist;
    final effectiveShowPlanSection = showPlanSection && !isReceptionist;
    final isCompleted = apt.status == AppointmentStatus.completed;
    final showEndedBtn = apt.consultationFormSaved && !isReceptionist && !isCompleted;

    // Left accent color
    final accentColor = widget.isMissed || apt.status == AppointmentStatus.cancelled
        ? context.colors.error
        : widget.isLate
            ? context.colors.warning
            : isInProgress
                ? context.colors.warning
                : statusColor;

    final showEndedLabel = isCompleted && apt.consultationFormSaved && !isReceptionist;
    final hasActions = showArrivedBtn || showRescheduleBtn || showFillDetailsBtn ||
        effectiveShowStartConsultation || effectiveShowPlanSection || showEndedBtn || showEndedLabel;

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Opacity(
          opacity: widget.isMissed || apt.status == AppointmentStatus.cancelled ? 0.65 : 1.0,
          child: Container(
            decoration: isDesktop
                ? BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: context.colors.surface,
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
              borderRadius: BorderRadius.circular(isDesktop ? 24 : 18),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isDesktop ? 10 : 0,
                  sigmaY: isDesktop ? 10 : 0,
                ),
                child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left accent strip
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

                    // Card body
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onTap,
                            onLongPress: () {
                              final isFullyDone =
                                  apt.patientDetailsSaved &&
                                  apt.consultationFormSaved &&
                                  apt.linkedTreatmentPlanId != null;
                              if (apt.status == AppointmentStatus.cancelled || isFullyDone) return;
                              HapticFeedback.mediumImpact();
                              widget.onLongPress();
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                              child: isDesktop
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Column 0: Circular Index Badge
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${widget.index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Column 1: Patient details (Name, Doctor, Pills)
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                apt.displayName,
                                                style: context.textStyles.h3.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (widget.showDoctorName && apt.doctorName != null && apt.doctorName!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.person_outline_rounded, size: 12, color: context.colors.textHint),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Dr. ${apt.doctorName}',
                                                      style: context.textStyles.caption.copyWith(fontSize: 11, color: context.colors.textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 6),
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
                                                    label: typeLabel,
                                                    icon: typeIcon,
                                                    color: typeColor,
                                                  ),
                                                  if (apt.isRescheduled)
                                                    _Pill(
                                                      label: 'Rescheduled',
                                                      icon: Icons.event_repeat_rounded,
                                                      color: const Color(0xFFF59E0B),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Column 2: Status/Warning Indicators
                                        Expanded(
                                          flex: 3,
                                          child: _buildMiddleIndicator(context, apt, statusColor),
                                        ),

                                        // Column 3: Time badge + Call/Message buttons
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
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
                                              if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty &&
                                                  !(isInProgress && apt.checkInTime != null && apt.consultationStartTime != null && !apt.consultationFormSaved)) ...[
                                                const SizedBox(height: 8),
                                                _buildContactButtons(context, apt),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
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
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                apt.displayName,
                                                style: context.textStyles.h3.copyWith(fontSize: 16),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (widget.showDoctorName && apt.doctorName != null && apt.doctorName!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(Icons.person_outline_rounded, size: 12, color: context.colors.textHint),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Dr. ${apt.doctorName}',
                                                      style: context.textStyles.caption.copyWith(fontSize: 11, color: context.colors.textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ],
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
                                                    label: typeLabel,
                                                    icon: typeIcon,
                                                    color: typeColor,
                                                  ),
                                                  if (apt.isRescheduled)
                                                    _Pill(
                                                      label: 'Rescheduled',
                                                      icon: Icons.event_repeat_rounded,
                                                      color: const Color(0xFFF59E0B),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
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
                                            if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty &&
                                                !(isInProgress && apt.checkInTime != null && apt.consultationStartTime != null && !apt.consultationFormSaved)) ...[
                                              const SizedBox(height: 8),
                                              _buildContactButtons(context, apt),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Banners only for mobile layout (since desktop has them inside Column 2)
                          if (!isDesktop) ...[
                            if (widget.isMissed)
                              _InfoBanner(Icons.event_busy_rounded,
                                  'Patient missed this appointment', context.colors.error),
                            if (widget.isLate && !widget.isMissed)
                              _InfoBanner(Icons.warning_amber_rounded,
                                  'Patient is late \u2014 hasn\'t arrived yet', context.colors.warning),
                          ],

                          // Actions section
                          if (hasActions) ...[
                            Divider(
                              color: context.colors.border.withValues(alpha: 0.6),
                              height: 1,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  // Scheduled: Patient Arrived & Reschedule
                                  if (showArrivedBtn || showRescheduleBtn)
                                    Row(
                                      children: [
                                        if (showArrivedBtn)
                                          Expanded(
                                            child: _ActionButton(
                                              label: 'Patient Arrived',
                                              icon: Icons.how_to_reg_rounded,
                                              color: context.colors.success,
                                              onTap: widget.onArrived,
                                            ),
                                          ),
                                        if (showRescheduleBtn) ...[
                                          if (showArrivedBtn) const SizedBox(width: 8),
                                          Expanded(
                                            child: _ActionButton(
                                              label: 'Reschedule',
                                              icon: Icons.event_repeat_rounded,
                                              color: context.colors.info,
                                              onTap: widget.onReschedule,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                  // Checked In (Fill Details)
                                  if (showFillDetailsBtn)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ActionButton(
                                            label: 'Mark as No Show',
                                            icon: Icons.cancel_outlined,
                                            color: context.colors.error,
                                            onTap: widget.onLongPress,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ActionButton(
                                            label: fillDetailsLabel,
                                            icon: fillDetailsIcon,
                                            color: context.colors.primary,
                                            onTap: widget.onFillDetails,
                                            isSolid: true,
                                            showTrailingChevron: true,
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Checked In (Start Consultation)
                                  if (effectiveShowStartConsultation)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ActionButton(
                                            label: 'Mark as No Show',
                                            icon: Icons.cancel_outlined,
                                            color: context.colors.error,
                                            onTap: widget.onLongPress,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ActionButton(
                                            label: consultationLabel,
                                            icon: consultationIcon,
                                            color: context.colors.primary,
                                            onTap: widget.onStartConsultation,
                                            isSolid: true,
                                            showTrailingChevron: true,
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Undo Arrival
                                  if (isCallBy && isInProgress && apt.checkInTime != null &&
                                      !apt.patientDetailsSaved && !apt.consultationFormSaved) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ActionButton(
                                            label: 'Undo Arrival',
                                            icon: Icons.undo_rounded,
                                            color: context.colors.textSecondary,
                                            onTap: widget.onUndoArrived,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Plan Section & End Appointment
                                  if (effectiveShowPlanSection || showEndedBtn) ...[
                                    if (showArrivedBtn || showRescheduleBtn || showFillDetailsBtn || effectiveShowStartConsultation)
                                      const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (effectiveShowPlanSection) ...[
                                          Expanded(
                                            child: _ActionButton(
                                              label: planLabel,
                                              icon: planIcon,
                                              color: context.colors.primary,
                                              onTap: () async {
                                                await Future.microtask(() => widget.onCreatePlan(_consultationId ?? ''));
                                                if (mounted) {
                                                  setState(() {
                                                    _planInfoLoaded = false;
                                                    _hasPlan = false;
                                                  });
                                                  _loadPlanInfo();
                                                }
                                              },
                                              isSolid: true,
                                              showTrailingChevron: true,
                                            ),
                                          ),
                                          if (showEndedBtn) const SizedBox(width: 8),
                                        ],
                                        if (showEndedBtn)
                                          Expanded(
                                            child: _ActionButton(
                                              label: 'End Appointment',
                                              icon: Icons.check_circle_outline_rounded,
                                              color: context.colors.success,
                                              onTap: widget.onEnded,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],

                                  // Completed Text Indicator
                                  if (isCompleted && apt.consultationFormSaved && !isReceptionist) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 14, color: context.colors.success),
                                        const SizedBox(width: 5),
                                        Text(
                                          apt.checkOutTime != null
                                              ? 'Consultation ended at ${DateFormat('h:mm a').format(apt.checkOutTime!.toLocal())}'
                                              : 'Consultation ended',
                                          style: context.textStyles.caption.copyWith(
                                            color: context.colors.success,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
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

// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
// Treatment Session Card Ã¢â‚¬â€ distinct flow from consultation cards
// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

class _SessionCard extends ConsumerStatefulWidget {
  final AppointmentModel apt;
  final int index;
  final bool isLate;
  final bool isFutureDate;
  final bool isMissed;
  final VoidCallback onArrived;
  final void Function(String? sessionId) onStartSession;
  final void Function(String? sessionId) onSessionEnded;
  final VoidCallback onReschedule;
  final VoidCallback onUndoArrived;
  final VoidCallback onLongPress;
  final void Function(String? sessionId) onTap;
  final bool showDoctorName;
  /// Pre-loaded session info from parent batch-load Ã¢â‚¬â€ skips per-card PB query.
  final Map<String, dynamic>? preloadedSessionInfo;
  final String? clinicLocation;

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
    required this.onUndoArrived,
    required this.onLongPress,
    required this.onTap,
    this.showDoctorName = false,
    this.preloadedSessionInfo,
    this.clinicLocation,
  });

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  int _sessionNumber = 0;
  String _sessionType = 'treatment'; // 'treatment' or 'maintenance'
  String? _sessionId;
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
    _loadSessionInfo();
    SessionTimerService.instance.addGlobalListener(_onTimerChanged);
  }

  Future<void> _loadSessionInfo() async {
    // Use preloaded info from parent if available Ã¢â‚¬â€ avoids PB query
    if (widget.preloadedSessionInfo != null) {
      final info = widget.preloadedSessionInfo!;
      setState(() {
        _sessionNumber = info['number'] as int? ?? 0;
        _sessionType = info['type'] as String? ?? 'treatment';
        _sessionId = info['id'] as String?;
        _sessionNumLoaded = true;
      });
      return;
    }
    try {
      final service = ref.read(appointmentServiceProvider);
      final info = await service.getSessionInfoForAppointment(widget.apt);
      if (mounted && info != null) {
        setState(() {
          _sessionNumber = info['number'] as int;
          _sessionType = info['type'] as String;
          _sessionId = info['id'] as String?;
          _sessionNumLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    SessionTimerService.instance.removeGlobalListener(_onTimerChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTimerChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildMiddleIndicator(BuildContext context, AppointmentModel apt, Color statusColor) {
    if (widget.isMissed) {
      return _indicatorItem(
        context: context,
        icon: Icons.event_busy_rounded,
        iconColor: context.colors.error,
        title: 'Missed',
        subtitle: 'Patient missed session',
      );
    } else if (apt.status == AppointmentStatus.cancelled) {
      return _indicatorItem(
        context: context,
        icon: Icons.cancel_rounded,
        iconColor: context.colors.error,
        title: 'Cancelled',
        subtitle: 'Session cancelled',
      );
    } else if (apt.status == AppointmentStatus.completed) {
      return _indicatorItem(
        context: context,
        icon: Icons.check_circle_rounded,
        iconColor: context.colors.success,
        title: 'Completed',
        subtitle: 'Session completed',
      );
    } else if (apt.status == AppointmentStatus.inProgress) {
      return _indicatorItem(
        context: context,
        icon: Icons.sync_rounded,
        iconColor: context.colors.warning,
        title: 'In Progress',
        subtitle: 'Session started',
      );
    } else if (apt.status == AppointmentStatus.waiting) {
      return _indicatorItem(
        context: context,
        icon: Icons.hourglass_empty_rounded,
        iconColor: const Color(0xFFF59E0B),
        title: 'Waiting',
        subtitle: 'Checked in',
      );
    } else if (widget.isLate && apt.status == AppointmentStatus.scheduled) {
      return _indicatorItem(
        context: context,
        icon: Icons.warning_amber_rounded,
        iconColor: context.colors.warning,
        title: 'Patient is late',
        subtitle: 'Haven\'t arrived yet',
      );
    } else {
      return _indicatorItem(
        context: context,
        icon: Icons.circle,
        iconColor: context.colors.success,
        title: 'On time',
        subtitle: 'Arrived on time',
        isDot: true,
      );
    }
  }

  Widget _indicatorItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isDot = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDot
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              )
            : Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: context.textStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.textStyles.caption.copyWith(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactButtons(BuildContext context, AppointmentModel apt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => WhatsAppHelper.showMenu(
            context: context,
            phone: apt.effectivePhone!,
            patientName: apt.displayName,
            appointmentTime: apt.time,
            appointmentDate: apt.date,
            isEnded: apt.status == AppointmentStatus.completed,
            isMissed: widget.isMissed,
            clinicLocation: widget.clinicLocation,
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF25D366).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.chat_rounded,
                color: Color(0xFF25D366), size: 18),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            if (apt.effectivePhone == null || apt.effectivePhone!.isEmpty) return;
            final url = Uri.parse('tel:${apt.effectivePhone}');
            try {
              await launchUrl(url);
            } catch (e) {
              debugPrint('Could not launch phone call: $e');
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.phone_rounded,
                color: Color(0xFF00BFA5), size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopActions(BuildContext context) {
    final apt = widget.apt;
    final isScheduled = apt.status == AppointmentStatus.scheduled;
    final isWaiting = apt.status == AppointmentStatus.waiting;
    final isInProgress = apt.status == AppointmentStatus.inProgress;
    final isCancelled = apt.status == AppointmentStatus.cancelled;
    final isCompleted = apt.status == AppointmentStatus.completed;

    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showStartBtn   = isWaiting && !widget.isFutureDate;
    final showResumeBtn  = isInProgress; 
    final showEndedBtn   = isInProgress;
    final showRescheduleBtn = isScheduled && (widget.isFutureDate || !widget.isMissed) || widget.isMissed && !isInProgress;
    final showUndoArrived = isWaiting && apt.checkInTime != null;
    final showCancelBtn = !isCancelled && !isCompleted && !widget.isMissed;

    final List<Widget> buttons = [];

    if (showCancelBtn) {
      buttons.add(_ActionButton(
        label: 'Cancel',
        icon: Icons.cancel_outlined,
        color: context.colors.error,
        onTap: widget.onLongPress,
      ));
    }

    if (showArrivedBtn) {
      buttons.add(_ActionButton(
        label: 'Arrived',
        icon: Icons.how_to_reg_rounded,
        color: context.colors.success,
        onTap: widget.onArrived,
      ));
    }

    if (showStartBtn) {
      buttons.add(_ActionButton(
        label: 'Start Session',
        icon: Icons.play_arrow_rounded,
        color: context.colors.primary,
        onTap: () => widget.onStartSession(_sessionId),
        isSolid: true,
        showTrailingChevron: true,
      ));
    }

    if (showUndoArrived) {
      buttons.add(_ActionButton(
        label: 'Undo Arrival',
        icon: Icons.undo_rounded,
        color: context.colors.textSecondary,
        onTap: widget.onUndoArrived,
      ));
    }

    if (showResumeBtn) {
      buttons.add(_ActionButton(
        label: 'Resume Session',
        icon: Icons.play_circle_outline_rounded,
        color: context.colors.primary,
        onTap: () => widget.onStartSession(_sessionId),
        isSolid: true,
        showTrailingChevron: true,
      ));
    }

    if (showEndedBtn) {
      buttons.add(_ActionButton(
        label: 'End Session',
        icon: Icons.check_circle_outline_rounded,
        color: context.colors.success,
        onTap: () => widget.onSessionEnded(_sessionId),
      ));
    }

    if (showRescheduleBtn) {
      buttons.add(_ActionButton(
        label: 'Reschedule',
        icon: Icons.event_repeat_rounded,
        color: context.colors.info,
        onTap: widget.onReschedule,
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: buttons,
    );
  }

  Widget _buildDesktopTimelineInfo(BuildContext context) {
    final apt = widget.apt;
    final isCancelled = apt.status == AppointmentStatus.cancelled;
    final isCompleted = apt.status == AppointmentStatus.completed;

    if (widget.isMissed || isCancelled || isCompleted) return const SizedBox.shrink();

    final List<Widget> items = [];

    Widget tagItem(String text, IconData icon, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.textStyles.caption.copyWith(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (apt.checkInTime != null) {
      items.add(tagItem(
        'Arrived: ${DateFormat('h:mm a').format(apt.checkInTime!.toLocal())}',
        Icons.how_to_reg_rounded,
        context.colors.success,
      ));
    }
    if (apt.consultationStartTime != null) {
      items.add(tagItem(
        'Started: ${DateFormat('h:mm a').format(apt.consultationStartTime!.toLocal())}',
        Icons.play_circle_outline_rounded,
        context.colors.primary,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }

  Widget _buildDesktopTimer(BuildContext context) {
    if (widget.isFutureDate) return const SizedBox.shrink();

    final apt = widget.apt;
    TimerSnapshot? timerEntry;
    if (_sessionId != null) {
      final entry = SessionTimerService.instance.getEntry(_sessionId!);
      if (entry != null) {
        timerEntry = TimerSnapshot(
          sessionId: entry.sessionId,
          patientName: entry.patientName,
          remainingSeconds: entry.remainingSeconds,
          totalSeconds: entry.totalSeconds,
          isPaused: entry.isPaused,
          isActive: entry.isActive,
          isRunning: entry.isRunning,
          timerHistory: entry.timerHistory,
        );
      }
    }
    if (timerEntry == null) {
      timerEntry = SessionTimerService.instance.getActiveTimerByPatientName(apt.displayName);
    }
    if (timerEntry == null || !timerEntry.isActive) return const SizedBox.shrink();

    final mins = timerEntry.remainingSeconds ~/ 60;
    final secs = timerEntry.remainingSeconds % 60;
    final timeStr = timerEntry.isPaused
        ? '${mins}m ${secs.toString().padLeft(2, '0')}s (Paused)'
        : '${mins}m ${secs.toString().padLeft(2, '0')}s remaining';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 12, color: context.colors.warning),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: context.textStyles.caption.copyWith(
              color: context.colors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

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
      statusColor = context.colors.error; statusStr = 'Missed'; statusIcon = Icons.event_busy_rounded;
    } else if (isCancelled) {
      statusColor = context.colors.error; statusStr = 'Cancelled'; statusIcon = Icons.cancel_rounded;
    } else if (isCompleted) {
      statusColor = context.colors.success; statusStr = 'Completed'; statusIcon = Icons.check_circle_rounded;
    } else if (isInProgress) {
      statusColor = context.colors.warning; statusStr = 'In Progress'; statusIcon = Icons.sync_rounded;
    } else if (isWaiting) {
      statusColor = kWaiting; statusStr = 'Waiting'; statusIcon = Icons.hourglass_empty_rounded;
    } else {
      statusColor = const Color(0xFF7C3AED); statusStr = 'Scheduled'; statusIcon = Icons.healing_rounded;
    }

    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showStartBtn   = isWaiting && !widget.isFutureDate;
    final showResumeBtn  = isInProgress; 
    final showEndedBtn   = isInProgress;
    final showRescheduleBtn = isScheduled && (widget.isFutureDate || !widget.isMissed) || widget.isMissed && !isInProgress;

    const sessionAccent = Color(0xFF7C3AED);
    final accentColor = widget.isMissed || isCancelled
        ? context.colors.error
        : widget.isLate
            ? context.colors.warning
            : isInProgress
                ? context.colors.warning
                : isWaiting
                    ? kWaiting
                    : sessionAccent;

    final hasActions = showArrivedBtn || showStartBtn || showResumeBtn || showEndedBtn || showRescheduleBtn;

    // Helper to build the timeline log items
    Widget buildTimelineInfo() {
      final List<Widget> items = [];

      Widget textItem(String text, IconData icon, Color color) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: context.textStyles.caption.copyWith(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }

      if (!widget.isMissed && !isCancelled) {
        if (!isCompleted) {
          if (apt.checkInTime != null) {
            items.add(textItem(
              'Patient arrived at ${DateFormat('h:mm a').format(apt.checkInTime!.toLocal())}',
              Icons.how_to_reg_rounded,
              context.colors.success,
            ));
          }
          if (apt.consultationStartTime != null) {
            items.add(textItem(
              'Session started at ${DateFormat('h:mm a').format(apt.consultationStartTime!.toLocal())}',
              Icons.play_circle_outline_rounded,
              context.colors.primary,
            ));
          }
        }
      }

      if (items.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(top: 8, left: 14, right: 14, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: items,
        ),
      );
    }

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Opacity(
          opacity: (widget.isMissed || isCancelled || isCompleted) ? 0.65 : 1.0,
          child: Container(
            decoration: isDesktop
                ? BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: context.colors.surface,
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
              borderRadius: BorderRadius.circular(isDesktop ? 24 : 18),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isDesktop ? 10 : 0,
                  sigmaY: isDesktop ? 10 : 0,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left accent strip
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isDesktop ? 24 : 18),
                            bottomLeft: Radius.circular(isDesktop ? 24 : 18),
                          ),
                        ),
                      ),

                      // Card body
                      Expanded(
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left section: Patient Details & Status indicators (flex 7)
                                  Expanded(
                                    flex: 7,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => widget.onTap(_sessionId),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Column 0: Circular Index Badge
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${widget.index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),

                                            // Column 1: Patient details (Name, Doctor, Pills)
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    apt.displayName,
                                                    style: context.textStyles.h3.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (widget.showDoctorName && apt.doctorName != null && apt.doctorName!.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.person_outline_rounded, size: 12, color: context.colors.textHint),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Dr. ${apt.doctorName}',
                                                          style: context.textStyles.caption.copyWith(fontSize: 11, color: context.colors.textSecondary),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      _Pill(
                                                        label: statusStr,
                                                        icon: statusIcon,
                                                        color: statusColor,
                                                      ),
                                                      if (_sessionNumLoaded)
                                                        _Pill(
                                                          label: _sessionType == 'maintenance'
                                                              ? 'Maintenance $_sessionNumber'
                                                              : 'Session $_sessionNumber',
                                                          icon: _sessionType == 'maintenance'
                                                              ? Icons.settings_suggest_rounded
                                                              : Icons.healing_rounded,
                                                          color: _sessionType == 'maintenance'
                                                              ? context.colors.success
                                                              : sessionAccent,
                                                        ),
                                                      if (apt.isRescheduled)
                                                        _Pill(
                                                          label: 'Rescheduled',
                                                          icon: Icons.event_repeat_rounded,
                                                          color: const Color(0xFFF59E0B),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Column 2: Status/Warning Indicator + Timeline info + Timer
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _buildMiddleIndicator(context, apt, statusColor),
                                                  _buildDesktopTimelineInfo(context),
                                                  _buildDesktopTimer(context),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Vertical Divider
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: context.colors.border.withValues(alpha: 0.6),
                                  ),

                                  // Right section: Time, contact, and action buttons (flex 5)
                                  Expanded(
                                    flex: 5,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
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
                                              if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty &&
                                                  !(isInProgress && apt.checkInTime != null)) ...[
                                                const SizedBox(height: 8),
                                                _buildContactButtons(context, apt),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _buildDesktopActions(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => widget.onTap(_sessionId),
                                    onLongPress: (isCancelled || isCompleted || widget.isMissed) ? null : () {
                                      HapticFeedback.mediumImpact();
                                      widget.onLongPress();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left session number badge (same design on mobile)
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              color: (_sessionType == 'maintenance'
                                                  ? context.colors.success
                                                  : sessionAccent).withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: (_sessionType == 'maintenance'
                                                    ? context.colors.success
                                                    : sessionAccent).withValues(alpha: 0.2),
                                                width: 1.5,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _sessionNumLoaded
                                                  ? '${_sessionType == 'maintenance' ? 'M' : ''}$_sessionNumber'
                                                  : '-',
                                              style: TextStyle(
                                                color: _sessionType == 'maintenance'
                                                    ? context.colors.success
                                                    : sessionAccent,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  apt.displayName,
                                                  style: context.textStyles.h3.copyWith(fontSize: 16),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (widget.showDoctorName && apt.doctorName != null && apt.doctorName!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person_outline_rounded, size: 12, color: context.colors.textHint),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Dr. ${apt.doctorName}',
                                                        style: context.textStyles.caption.copyWith(fontSize: 11, color: context.colors.textSecondary),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ],
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
                                                    if (apt.isRescheduled)
                                                      _Pill(
                                                        label: 'Rescheduled',
                                                        icon: Icons.event_repeat_rounded,
                                                        color: const Color(0xFFF59E0B),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
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
                                              if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty &&
                                                  !(isInProgress && apt.checkInTime != null)) ...[
                                                const SizedBox(height: 8),
                                                _buildContactButtons(context, apt),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  if (widget.isMissed)
                                    _InfoBanner(Icons.event_busy_rounded,
                                        'Patient missed this session', context.colors.error),
                                  if (isCancelled)
                                    _InfoBanner(Icons.cancel_rounded,
                                        'Session cancelled', context.colors.error),
                                  if (isCompleted)
                                    _InfoBanner(Icons.check_circle_rounded,
                                        'Session completed', context.colors.success),
                                  if (widget.isLate && !widget.isMissed && isScheduled)
                                    _InfoBanner(Icons.warning_amber_rounded,
                                        'Patient is late — hasn\'t arrived yet', context.colors.warning),

                                  buildTimelineInfo(),

                                  // Timer countdown (if active for this patient — only for today's cards)
                                  if (!widget.isFutureDate) Builder(builder: (context) {
                                    TimerSnapshot? timerEntry;
                                    if (_sessionId != null) {
                                      final entry = SessionTimerService.instance.getEntry(_sessionId!);
                                      if (entry != null) {
                                        timerEntry = TimerSnapshot(
                                          sessionId: entry.sessionId,
                                          patientName: entry.patientName,
                                          remainingSeconds: entry.remainingSeconds,
                                          totalSeconds: entry.totalSeconds,
                                          isPaused: entry.isPaused,
                                          isActive: entry.isActive,
                                          isRunning: entry.isRunning,
                                          timerHistory: entry.timerHistory,
                                        );
                                      }
                                    }
                                    if (timerEntry == null) {
                                      timerEntry = SessionTimerService.instance.getActiveTimerByPatientName(apt.displayName);
                                    }
                                    if (timerEntry == null || !timerEntry.isActive) return const SizedBox.shrink();
                                    final mins = timerEntry.remainingSeconds ~/ 60;
                                    final secs = timerEntry.remainingSeconds % 60;
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: context.colors.warning.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.timer_rounded, size: 16, color: context.colors.warning),
                                            const SizedBox(width: 8),
                                            Text(
                                              timerEntry.isPaused
                                                  ? '${mins}m ${secs.toString().padLeft(2, '0')}s (Paused)'
                                                  : '${mins}m ${secs.toString().padLeft(2, '0')}s remaining',
                                              style: context.textStyles.caption.copyWith(
                                                color: context.colors.warning,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  if (hasActions) ...[
                                    const SizedBox(height: 6),
                                    Divider(
                                        color: context.colors.border.withValues(alpha: 0.6),
                                        height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(children: [
                                        if (showArrivedBtn)
                                          Expanded(child: _ActionButton(
                                            label: 'Patient Arrived',
                                            icon: Icons.how_to_reg_rounded,
                                            color: context.colors.success,
                                            onTap: widget.onArrived,
                                          )),
                                        if (showStartBtn) ...[
                                          Expanded(
                                            child: _ActionButton(
                                              label: 'Start Session',
                                              icon: Icons.play_arrow_rounded,
                                              color: context.colors.primary,
                                              onTap: () => widget.onStartSession(_sessionId),
                                              isSolid: true,
                                              showTrailingChevron: true,
                                            ),
                                          ),
                                        ],
                                        if (isWaiting && apt.checkInTime != null) ...[
                                          const SizedBox(width: 7),
                                          Expanded(child: _ActionButton(
                                            label: 'Undo Arrival',
                                            icon: Icons.undo_rounded,
                                            color: context.colors.textSecondary,
                                            onTap: widget.onUndoArrived,
                                          )),
                                        ],
                                        if (showResumeBtn) ...[
                                          Expanded(
                                            child: _ActionButton(
                                              label: 'Resume Session',
                                              icon: Icons.play_circle_outline_rounded,
                                              color: context.colors.primary,
                                              onTap: () => widget.onStartSession(_sessionId),
                                              isSolid: true,
                                              showTrailingChevron: true,
                                            ),
                                          ),
                                        ],
                                        if (showEndedBtn) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _ActionButton(
                                              label: 'End Session',
                                              icon: Icons.check_circle_outline_rounded,
                                              color: context.colors.success,
                                              onTap: () => widget.onSessionEnded(_sessionId),
                                            ),
                                          ),
                                        ],
                                        if (showRescheduleBtn) ...[
                                          if (showArrivedBtn || showStartBtn || showResumeBtn || showEndedBtn) const SizedBox(width: 7),
                                          Expanded(child: _ActionButton(
                                            label: 'Reschedule',
                                            icon: Icons.event_repeat_rounded,
                                            color: context.colors.info,
                                            onTap: widget.onReschedule,
                                          )),
                                        ],
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

// Ã¢â€â‚¬Ã¢â€â‚¬ Shared helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
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
            style: context.textStyles.caption.copyWith(
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
  final bool isSolid;
  final bool showTrailingChevron;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSolid = false,
    this.showTrailingChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSolid ? color : color.withValues(alpha: 0.09);
    final borderColor = isSolid ? Colors.transparent : color.withValues(alpha: 0.22);
    final foregroundColor = isSolid ? Colors.white : color;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: borderColor,
              width: isSolid ? 0 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!showTrailingChevron) ...[
                Icon(icon, size: 15, color: foregroundColor),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showTrailingChevron) ...[
                const SizedBox(width: 7),
                Icon(Icons.chevron_right_rounded, size: 15, color: foregroundColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Sleek Mini Month Calendar Widget Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class SleekMiniCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool flat;

  const SleekMiniCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.flat = false,
  });

  @override
  State<SleekMiniCalendar> createState() => _SleekMiniCalendarState();
}

class _SleekMiniCalendarState extends State<SleekMiniCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
  }

  @override
  void didUpdateWidget(SleekMiniCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.month != widget.selectedDate.month ||
        oldWidget.selectedDate.year != widget.selectedDate.year) {
      _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOfWeek = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1 = Monday, 7 = Sunday
    final offset = firstDayOfWeek - 1; // 0 to 6 days offset

    final totalCells = daysInMonth + offset;
    final rowCount = (totalCells / 7).ceil();

    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    final prevMonthDays = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

    final List<DateTime> calendarDays = [];

    // Add days from previous month
    for (int i = offset - 1; i >= 0; i--) {
      calendarDays.add(DateTime(prevMonth.year, prevMonth.month, prevMonthDays - i));
    }

    // Add days of current month
    for (int i = 1; i <= daysInMonth; i++) {
      calendarDays.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    // Add days of next month to complete the grid
    final remainingCells = rowCount * 7 - calendarDays.length;
    for (int i = 1; i <= remainingCells; i++) {
      final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      calendarDays.add(DateTime(nextMonth.year, nextMonth.month, i));
    }

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: widget.flat ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : const EdgeInsets.all(16),
      decoration: widget.flat
          ? null
          : BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: context.colors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
      child: Column(
        children: [
          // Header: Month / Year + Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: context.textStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: context.colors.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    onPressed: _prevMonth,
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      backgroundColor: context.colors.border.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    onPressed: _nextMonth,
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      backgroundColor: context.colors.border.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekday labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekdays.map((day) {
              return SizedBox(
                width: 32,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: context.textStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: context.colors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: calendarDays.length,
            itemBuilder: (context, index) {
              final date = calendarDays[index];
              final isSelected = date.day == widget.selectedDate.day &&
                  date.month == widget.selectedDate.month &&
                  date.year == widget.selectedDate.year;
              final isCurrentMonth = date.month == _currentMonth.month;
              final now = DateTime.now();
              final isToday = date.day == now.day && date.month == now.month && date.year == now.year;

              Color txtColor = isSelected
                  ? Colors.white
                  : (isCurrentMonth
                      ? context.colors.textPrimary
                      : context.colors.textSecondary.withValues(alpha: 0.4));
              
              return _CalendarDayCell(
                date: date,
                isSelected: isSelected,
                isToday: isToday,
                isCurrentMonth: isCurrentMonth,
                txtColor: txtColor,
                onTap: () {
                  widget.onDateChanged(date);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatefulWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isCurrentMonth;
  final Color txtColor;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isCurrentMonth,
    required this.txtColor,
    required this.onTap,
  });

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget cell = Center(
      child: Text(
        '${widget.date.day}',
        style: context.textStyles.bodySmall.copyWith(
          fontWeight: widget.isSelected || widget.isToday ? FontWeight.bold : FontWeight.w500,
          color: widget.isSelected
              ? Colors.white
              : (widget.isToday
                  ? context.colors.primary
                  : (widget.isCurrentMonth
                      ? context.colors.textPrimary
                      : context.colors.textSecondary.withValues(alpha: 0.4))),
          fontSize: 11,
        ),
      ),
    );

    Decoration? decoration;
    if (widget.isSelected) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary,
            context.colors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else if (widget.isToday) {
      decoration = BoxDecoration(
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.7), width: 1.5),
        shape: BoxShape.circle,
      );
    } else if (_isHovered) {
      decoration = BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: _isHovered && !widget.isSelected
              ? Matrix4.diagonal3Values(1.08, 1.08, 1.0)
              : Matrix4.identity(),
          decoration: decoration,
          child: cell,
        ),
      ),
    );
  }
}

class WebGlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final bool animateHover;

  const WebGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
    this.glowColor,
    this.animateHover = true,
  });

  @override
  State<WebGlassCard> createState() => _WebGlassCardState();
}

class _WebGlassCardState extends State<WebGlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (!isDesktop) {
      return Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      );
    }

    final translationY = widget.animateHover && _isHovered ? -3.0 : 0.0;
    final hoverGlowOpacity = widget.animateHover && _isHovered ? 0.08 : 0.04;
    final mainShadowOpacity = widget.animateHover && _isHovered ? 0.40 : 0.35;
    final activeGlowColor = widget.glowColor ?? const Color(0xFF3B82F6);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0.0, translationY, 0.0),
        decoration: BoxDecoration(
          color: const Color(0xFF131A26).withOpacity(0.07),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(mainShadowOpacity),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: activeGlowColor.withOpacity(hoverGlowOpacity),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}





