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
import '../../../core/services/session_lifecycle_service.dart';
import 'patient_info_screen.dart';
import '../../patients/screens/patient_profile_screen.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../treatments/providers/treatment_provider.dart';
import '../../treatments/models/session_model.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import '../../../core/services/session_timer_service.dart';
import '../../../core/utils/whatsapp_helper.dart';


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

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
      _runLifecycleCheck();
      _checkMultipleDoctors();
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
      ref.read(appointmentListProvider.notifier).loadAppointments();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${allSummaries.length} session(s) auto-rescheduled:\n${allSummaries.take(3).join('\n')}'
          '${allSummaries.length > 3 ? '\n...and ${allSummaries.length - 3} more' : ''}',
        ),
        backgroundColor: context.colors.warning,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
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
          content: Text('${apt.displayName} — appointment ended ✓'),
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
            content: Text('${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} ✓'),
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
      // Uses getOne() via linkedConsultationId — no list query needed
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
            // Auto-end the consultation appointment — 1st session is being handled today
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
            // Don't auto-end — sessions start on a different day
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

  Future<void> _markStartSession(AppointmentModel apt, {String? preloadedSessionId}) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return;
    try {
      SessionModel? session;
      final treatmentService = ref.read(treatmentServiceProvider);

      if (preloadedSessionId != null) {
        // Card already resolved this — skip the PB query
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
        // Card already has the session ID — just check timer status
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
          content: Text('Session for ${apt.displayName} completed ✓'),
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
    // Block navigation for future/scheduled sessions — only reschedule is available
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
            content: Text('Session for ${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} ✓'),
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
      backgroundColor: context.colors.background,
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

            // ── Main Content ──
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
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                                children: [
                                  // ── Consultations Section ──
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
                                          showDoctorName: _hasMultipleDoctors,
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

                                  // ── Treatment Sessions Section ──
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
                                          showDoctorName: _hasMultipleDoctors,
                                          onArrived: () => _markSessionArrived(e.value),
                                          onStartSession: (sid) => _markStartSession(e.value, preloadedSessionId: sid),
                                          onSessionEnded: (sid) => _markSessionEnded(e.value, preloadedSessionId: sid),
                                          onReschedule: () => _rescheduleSession(e.value),
                                          onLongPress: () => _cancelSession(e.value),
                                          onTap: (sid) => _openSessionDirectly(e.value, preloadedSessionId: sid),
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
  final bool showDoctorName;

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
      statusColor = context.colors.info; statusStr = 'Scheduled'; statusIcon = Icons.access_time_filled;
    }

    final isCallBy = apt.type == AppointmentType.callBy;
    final typeColor = isCallBy ? context.colors.info : context.colors.accent;
    final typeLabel = isCallBy ? 'Call-By' : 'Walk-In';
    final typeIcon = isCallBy ? Icons.event_note_rounded : Icons.directions_walk_rounded;

    final isScheduled = apt.status == AppointmentStatus.scheduled;
    final isInProgress = apt.status == AppointmentStatus.inProgress;
    final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;

    // ── Workflow state flags ──────────────────────────────────────────────────

    // Step 1: Patient Arrived
    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showRescheduleBtn = isScheduled && widget.isFutureDate && !widget.isMissed;

    // Step 2: Fill Patient Details (only for call-by — walk-in details are collected at creation)
    final showFillDetailsBtn = isInProgress && !hasPatientLinked && isCallBy;
    // Once opened but not submitted → show "Resume"
    final fillDetailsLabel = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? 'Resume Filling Details'
        : 'Fill Patient Details';
    final fillDetailsIcon = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? Icons.edit_note_rounded
        : Icons.badge_rounded;

    // Walk-in: patient details were collected upfront in the creation form.
    // Treat as always saved when the patient is linked (covers legacy records too).
    final effectivePatientDetailsSaved = apt.patientDetailsSaved ||
        (!isCallBy && hasPatientLinked);

    // Step 3: Start/Resume Consultation (only after details saved)
    final showStartConsultationBtn = isInProgress &&
        hasPatientLinked &&
        effectivePatientDetailsSaved &&
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
    //   Also hide if _loadPlanInfo confirms a plan already exists (covers creation from patient profile)
    final showPlanSection = apt.consultationFormSaved &&
        apt.linkedTreatmentPlanId == null &&
        !(_planInfoLoaded && _hasPlan);
    final planLabel = apt.treatmentPlanPartial ? 'Resume Treatment Plan' : 'Create Plan';
    final planIcon = apt.treatmentPlanPartial ? Icons.restart_alt_rounded : Icons.add_chart_rounded;

    final isReceptionist = ref.read(authProvider).role == UserRole.receptionist;
    final effectiveShowStartConsultation = showStartConsultationBtn && !isReceptionist;
    final effectiveShowPlanSection = showPlanSection && !isReceptionist;
    // Show End Appointment button only when consultation is saved AND appointment is still active
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

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Opacity(
          opacity: widget.isMissed || apt.status == AppointmentStatus.cancelled ? 0.65 : 1.0,
            child: Container(
              decoration: BoxDecoration(
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
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onTap,
                              onLongPress: () {
                                // Fully-done appointments cannot be cancelled
                                final isFullyDone =
                                    apt.patientDetailsSaved &&
                                    apt.consultationFormSaved &&
                                    apt.linkedTreatmentPlanId != null;
                                if (apt.status == AppointmentStatus.cancelled || isFullyDone) return;
                                HapticFeedback.mediumImpact();
                                widget.onLongPress();
                              },
                              child: Padding(
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
                                            color: context.colors.success,
                                          ),
                                        ],
                                        if (effectivePatientDetailsSaved) ...[
                                          const SizedBox(height: 3),
                                          _MetaRow(
                                            icon: Icons.badge_rounded,
                                            label: 'Patient details filled ✓',
                                            color: context.colors.success,
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
                                                ? context.colors.success
                                                : context.colors.primary,
                                          ),
                                        ],
                                        if (apt.linkedTreatmentPlanId != null) ...[
                                          const SizedBox(height: 3),
                                          _MetaRow(
                                            icon: Icons.check_circle_rounded,
                                            label: 'Treatment plan created ✓',
                                            color: context.colors.success,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right column: time badge + contact icons
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
                                      // WhatsApp + Phone row
                                      if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => WhatsAppHelper.showMenu(
                                                context: context,
                                                phone: apt.effectivePhone!,
                                                patientName: apt.displayName,
                                                appointmentTime: apt.time,
                                                appointmentDate: apt.date,
                                                isEnded: isCompleted,
                                                isMissed: widget.isMissed,
                                              ),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(9),
                                                  border: Border.all(
                                                    color: const Color(0xFF25D366).withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: const Icon(Icons.chat_rounded,
                                                    color: Color(0xFF25D366), size: 15),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () async {
                                                try { await launchUrl(Uri.parse('tel:${apt.effectivePhone}')); } catch (_) {}
                                              },
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: context.colors.success.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(9),
                                                  border: Border.all(
                                                    color: context.colors.success.withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: Icon(Icons.phone_rounded,
                                                    color: context.colors.success, size: 15),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ),

                            // Banners
                            if (widget.isMissed)
                              _InfoBanner(Icons.event_busy_rounded,
                                  'Patient missed this appointment', context.colors.error),
                            if (widget.isLate && !widget.isMissed)
                              _InfoBanner(Icons.warning_amber_rounded,
                                  'Patient is late — hasn\'t arrived yet', context.colors.warning),

                            // Actions
                            if (hasActions) ...[
                              Divider(
                                  color: context.colors.border.withValues(alpha: 0.6),
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
                                            color: context.colors.success,
                                            onTap: widget.onArrived,
                                          )),
                                        if (showRescheduleBtn) ...[
                                          if (showArrivedBtn) const SizedBox(width: 7),
                                          Expanded(child: _ActionButton(
                                            label: 'Reschedule',
                                            icon: Icons.event_repeat_rounded,
                                            color: context.colors.info,
                                            onTap: widget.onReschedule,
                                          )),
                                        ],
                                        if (showFillDetailsBtn) ...[
                                          if (showArrivedBtn || showRescheduleBtn) const SizedBox(width: 7),
                                          Expanded(child: _ActionButton(
                                            label: fillDetailsLabel,
                                            icon: fillDetailsIcon,
                                            color: apt.patientDetailsPartial
                                                ? context.colors.warning
                                                : context.colors.info,
                                            onTap: widget.onFillDetails,
                                          )),
                                        ],
                                        if (effectiveShowStartConsultation) ...[
                                          if (showArrivedBtn || showRescheduleBtn || showFillDetailsBtn) const SizedBox(width: 7),
                                          Expanded(child: _ActionButton(
                                            label: consultationLabel,
                                            icon: consultationIcon,
                                            color: apt.consultationStartTime != null
                                                ? context.colors.warning
                                                : context.colors.primary,
                                            onTap: widget.onStartConsultation,
                                          )),
                                        ],
                                      ]),

                                    // Row 2: Undo Arrived (call-by only — walk-in can't undo arrival)
                                    if (isCallBy && isInProgress && apt.checkInTime != null &&
                                        !apt.patientDetailsSaved && !apt.consultationFormSaved) ...[
                                      const SizedBox(height: 7),
                                      Row(children: [
                                        Expanded(child: _ActionButton(
                                          label: 'Undo Arrival',
                                          icon: Icons.undo_rounded,
                                          color: context.colors.textSecondary,
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
                                                ? context.colors.warning
                                                : context.colors.primary,
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
                                            color: context.colors.success,
                                            onTap: widget.onEnded,
                                          )),
                                      ]),
                                    ],

                                    // Show "Appointment Ended" label when completed
                                    if (isCompleted && apt.consultationFormSaved && !isReceptionist) ...[
                                      const SizedBox(height: 7),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 14, color: context.colors.success),
                                          const SizedBox(width: 5),
                                          Text(
                                            apt.checkOutTime != null
                                                ? 'Appointment ended at ${DateFormat('h:mm a').format(apt.checkOutTime!.toLocal())}'
                                                : 'Appointment ended',
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
  final void Function(String? sessionId) onStartSession;
  final void Function(String? sessionId) onSessionEnded;
  final VoidCallback onReschedule;
  final VoidCallback onLongPress;
  final void Function(String? sessionId) onTap;
  final bool showDoctorName;
  /// Pre-loaded session info from parent batch-load — skips per-card PB query.
  final Map<String, dynamic>? preloadedSessionInfo;

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
    required this.onTap,
    this.showDoctorName = false,
    this.preloadedSessionInfo,
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
    // Use preloaded info from parent if available — avoids PB query
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
    final showRescheduleBtn = isScheduled && widget.isFutureDate;

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

      if (widget.isMissed) {
        items.add(textItem('Patient missed this session', Icons.event_busy_rounded, context.colors.error));
      } else if (isCancelled) {
        items.add(textItem('Session cancelled', Icons.cancel_rounded, context.colors.error));
      } else {
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
        if (isCompleted && apt.checkOutTime != null) {
          items.add(textItem(
            'Session ended at ${DateFormat('h:mm a').format(apt.checkOutTime!.toLocal())}',
            Icons.check_circle_outline_rounded,
            context.colors.success,
          ));
        }
        if (isScheduled && widget.isLate) {
          items.add(textItem('Patient is late — hasn\'t arrived', Icons.warning_amber_rounded, context.colors.warning));
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
            decoration: BoxDecoration(
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
                                  // Bold Session Number Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
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
                                  // Patient details
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
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              _sessionType == 'maintenance'
                                                  ? Icons.autorenew_rounded
                                                  : Icons.healing_rounded,
                                              size: 13,
                                              color: _sessionType == 'maintenance'
                                                  ? context.colors.success
                                                  : sessionAccent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _sessionType == 'maintenance' ? 'Maintenance Session' : 'Treatment Session',
                                              style: context.textStyles.caption.copyWith(
                                                fontSize: 11,
                                                color: context.colors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (widget.showDoctorName && apt.doctorName != null && apt.doctorName!.isNotEmpty) ...[
                                              Text(
                                                '  ·  ',
                                                style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                                              ),
                                              Icon(Icons.person_outline_rounded, size: 12, color: context.colors.textHint),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  'Dr. ${apt.doctorName}',
                                                  style: context.textStyles.caption.copyWith(
                                                    fontSize: 11,
                                                    color: context.colors.textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                   const SizedBox(width: 8),
                                   // Time badge + status chip + contact icons
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          TimeUtils.formatStringTime(apt.time),
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                                        ),
                                        child: Text(
                                          statusStr,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      // WhatsApp + Phone row
                                      if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => WhatsAppHelper.showMenu(
                                                context: context,
                                                phone: apt.effectivePhone!,
                                                patientName: apt.displayName,
                                                appointmentTime: apt.time,
                                                appointmentDate: apt.date,
                                                isEnded: isCompleted,
                                                isMissed: widget.isMissed,
                                              ),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(9),
                                                  border: Border.all(
                                                    color: const Color(0xFF25D366).withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: const Icon(Icons.chat_rounded,
                                                    color: Color(0xFF25D366), size: 15),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () async {
                                                try { await launchUrl(Uri.parse('tel:${apt.effectivePhone}')); } catch (_) {}
                                              },
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: context.colors.success.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(9),
                                                  border: Border.all(
                                                    color: context.colors.success.withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: Icon(Icons.phone_rounded,
                                                    color: context.colors.success, size: 15),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Systematic timeline metadata
                          buildTimelineInfo(),

                          // Actions
                          // Timer countdown (if active for this patient)
                          Builder(builder: (context) {
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
                                          ? '\u23f8 ${mins}m ${secs.toString().padLeft(2, '0')}s (Paused)'
                                          : '\u23f1 ${mins}m ${secs.toString().padLeft(2, '0')}s remaining',
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
                                  if (showArrivedBtn) const SizedBox(width: 7),
                                  Expanded(child: _ActionButton(
                                    label: 'Start Session',
                                    icon: Icons.play_arrow_rounded,
                                    color: const Color(0xFFDC2626),
                                    onTap: () => widget.onStartSession(_sessionId),
                                  )),
                                ],
                                if (showResumeBtn) ...[
                                  if (showArrivedBtn || showStartBtn) const SizedBox(width: 7),
                                  Expanded(child: _ActionButton(
                                    label: 'Session Details',
                                    icon: Icons.restart_alt_rounded,
                                    color: const Color(0xFF7C3AED),
                                    onTap: () => widget.onStartSession(_sessionId),
                                  )),
                                ],
                                if (showEndedBtn) ...[
                                  if (showArrivedBtn || showStartBtn || showResumeBtn) const SizedBox(width: 7),
                                  Expanded(child: _ActionButton(
                                    label: 'End Session',
                                    icon: Icons.check_circle_outline_rounded,
                                    color: context.colors.success,
                                    onTap: () => widget.onSessionEnded(_sessionId),
                                  )),
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