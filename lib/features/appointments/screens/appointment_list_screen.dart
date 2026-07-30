// AUTO-GENERATED â€” Web-only layout.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/core/utils/time_utils.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import 'package:pms_app/core/services/scheduling_service.dart';
import 'package:pms_app/features/scheduling/screens/available_slots_screen.dart';
import 'package:pms_app/features/consultations/screens/consultation_screen.dart';
import 'package:pms_app/features/treatments/screens/create_treatment_plan_screen.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/features/appointments/screens/patient_info_screen.dart';
import 'package:pms_app/features/appointments/screens/auto_scheduling_dashboard.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/features/analytics/providers/analytics_provider.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/date_picker_helper.dart';
import 'package:pms_app/core/services/session_timer_service.dart';
import 'package:pms_app/core/utils/whatsapp_helper.dart';
import 'package:pms_app/core/services/audit_service.dart';
import 'package:pms_app/core/widgets/responsive_wrapper.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart' show RescheduleMode;
import 'package:pms_app/features/treatments/widgets/cascade_preview_sheet.dart';
import 'package:pms_app/features/appointments/widgets/conflict_warning_dialog.dart';

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
  List<TreatmentPlanModel> _pendingAutoSchedulingPlans = [];
  bool _didAutoPopupDashboard = false;
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
    final lifecycle = ref.read(sessionLifecycleServiceProvider);

    int totalAutoRescheduled = 0;

    if (auth.role == UserRole.clinic && auth.clinicId != null) {
      // Clinic: check for all doctors in the clinic
      try {
        final docs = await pb.collection('doctors').getList(
          filter: 'clinic = "${auth.clinicId}"',
          perPage: 50,
        );
        for (final doc in docs.items) {
          totalAutoRescheduled += await lifecycle.checkAndMarkMissedSessions(doc.id);
        }
      } catch (_) {}
    } else if (auth.userId != null) {
      totalAutoRescheduled = await lifecycle.checkAndMarkMissedSessions(auth.userId!);
    }

    // Load any pending auto-scheduling plans (from DB, including any newly detected)
    await _loadPendingAutoScheduling();

    if (mounted) {
      ref.read(appointmentListProvider.notifier).loadAppointments();

      if (totalAutoRescheduled > 0) {
        AppToast.show(
          'Scheduling was automatically updated for $totalAutoRescheduled missed session(s). Review the Auto Scheduling dashboard for details.',
          type: ToastType.info,
          duration: const Duration(seconds: 8),
          actionLabel: 'View Changes',
          onAction: () {
            if (mounted) {
              AutoSchedulingDashboard.show(
                context,
                plans: _pendingAutoSchedulingPlans,
                onRefresh: () {
                  _loadPendingAutoScheduling();
                  ref.read(appointmentListProvider.notifier).loadAppointments();
                },
              );
            }
          },
        );
      }

      // Auto-popup the dashboard if there are pending plans and we haven't popped up yet
      if (_pendingAutoSchedulingPlans.isNotEmpty && !_didAutoPopupDashboard) {
        _didAutoPopupDashboard = true;
        // Delay slightly to let the UI finish mounting and rendering
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            AutoSchedulingDashboard.show(
              context,
              plans: _pendingAutoSchedulingPlans,
              onRefresh: () {
                _loadPendingAutoScheduling();
                ref.read(appointmentListProvider.notifier).loadAppointments();
              },
            );
          }
        });
      }
    }
  }

  /// Loads the pending auto-scheduling plans for the current doctor/clinic
  Future<void> _loadPendingAutoScheduling() async {
    final auth = ref.read(authProvider);
    final lifecycle = ref.read(sessionLifecycleServiceProvider);

    List<TreatmentPlanModel> pending = [];
    try {
      if (auth.role == UserRole.clinic && auth.clinicId != null) {
        pending = await lifecycle.getPendingMissedPlans(auth.clinicId!, isClinic: true);
      } else if (auth.userId != null) {
        pending = await lifecycle.getPendingMissedPlans(auth.userId!, isClinic: false);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _pendingAutoSchedulingPlans = pending;
      });
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
    final picked = await showAppDatePicker(
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
    return now.difference(aptTime).inMinutes >= 1;
  }

  bool _isMissed(AppointmentModel apt) {
    return apt.status == AppointmentStatus.missed;
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
      
      bool proceed = true;
      if (daySchedule == null) {
        if (mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: context.colors.surface,
              title: Row(children: [
                Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 22),
                const SizedBox(width: 10),
                const Text('Doctor Not Scheduled'),
              ]),
              content: Text('Doctor is not scheduled to work today. Do you want to mark ${apt.displayName} as arrived anyway?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.warning, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Mark Arrived'),
                ),
              ],
            ),
          );
          proceed = confirm == true;
        } else {
          proceed = false;
        }
      } else {
        final now = DateTime.now();
        final nowStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
        if (!schedService.isWithinWorkingHours(daySchedule, nowStr)) {
          if (mounted) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: context.colors.surface,
                title: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 22),
                  const SizedBox(width: 10),
                  const Text('Outside Working Hours'),
                ]),
                content: Text('Patient arrival is outside the doctor\'s working hours today. Do you want to mark ${apt.displayName} as arrived anyway?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: context.colors.warning, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Mark Arrived'),
                  ),
                ],
              ),
            );
            proceed = confirm == true;
          } else {
            proceed = false;
          }
        }
      }

      if (!proceed) return;

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
        AppToast.show('${apt.displayName} marked as arrived \u2713', type: ToastType.success);
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
        AppToast.show('${apt.displayName} \u2014 consultation ended \u2713', type: ToastType.success);
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
          AppToast.show('${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} \u2713', type: ToastType.success);
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
      // Option A — Pre-flight guard: verify the consultation still exists in the
      // database before opening the plan creator. Protects against the stale-state
      // bug where a consultation was deleted externally (e.g. from patient profile)
      // but the appointment card hasn't refreshed yet.
      final pb = ref.read(pocketbaseProvider);
      try {
        await pb.collection(PBCollections.consultations).getOne(consultationId);
      } catch (_) {
        // Consultation record is gone — refresh appointments and bail out.
        if (mounted) {
          AppToast.show(
            'This consultation no longer exists. Refreshing data...',
            type: ToastType.error,
          );
          ref.read(appointmentListProvider.notifier).loadAppointments();
        }
        return;
      }

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
            // Auto-end the consultation appointment Ã¢â‚¬â€  1st session is being handled today
            final service = ref.read(appointmentServiceProvider);
            await service.markEnded(apt.id);
            if (mounted) {
              AppToast.show('Treatment plan created & consultation ended. Session 1 is waiting on today\'s schedule.', type: ToastType.success, duration: const Duration(seconds: 5));
            }
          } else {
            // Don't auto-end Ã¢â‚¬â€  sessions start on a different day
            if (mounted) {
              AppToast.show('Treatment plan created & sessions scheduled! You may end this appointment now or keep it open.', type: ToastType.success, duration: const Duration(seconds: 5));
            }
          }
        }
        ref.read(appointmentListProvider.notifier).loadAppointments();
      }
    } catch (e) {
      if (mounted) _showError('Failed to open plan creator: $e');
    }
  }

  // Ã¢â€ â‚¬Ã¢â€ â‚¬ Session card actions Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬

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
        AppToast.show('${apt.displayName} is now waiting for session \u2713');
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
      if (!mounted) return;
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
              child: Text('Stop Timer & End Session', style: TextStyle(color: context.colors.textPrimary)),
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
        AppToast.show('Session for ${apt.displayName} completed \u2713', type: ToastType.success);
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
        AppToast.show('Session hasn\'t started yet. Only reschedule is available.', type: ToastType.info);
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
    DateTime? minDate;
    String? minTime;
    try {
      final pb = ref.read(pocketbaseProvider);
      final service = ref.read(appointmentServiceProvider);
      final s = await service.findSessionForAppointment(apt);
      if (s != null && s['sessionId'] != null) {
        final sessionRec = await pb.collection(PBCollections.sessions).getOne(s['sessionId']!);
        final session = SessionModel.fromRecord(sessionRec);
        if (session.sessionNumber > 1) {
          final allSessRes = await pb.collection(PBCollections.sessions).getList(
            filter: 'treatment_plan = "${session.treatmentPlanId}" && session_number = ${session.sessionNumber - 1}',
            perPage: 1,
          );
          if (allSessRes.items.isNotEmpty) {
            final prevSess = SessionModel.fromRecord(allSessRes.items.first);
            final prevDate = DateTime.tryParse(prevSess.scheduledDate);
            if (prevDate != null) {
              minDate = DateTime(prevDate.year, prevDate.month, prevDate.day);
              minTime = prevSess.scheduledTime;
            }
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: apt.doctorId,
          clinicId: (apt.clinicId != null && apt.clinicId!.isNotEmpty) ? apt.clinicId : null,
          treatmentDuration: 30,
          minDate: minDate,
          minTime: minTime,
        ),
      ),
    );
    if (result != null && mounted) {
      final newDate = DateFormat('yyyy-MM-dd').format(result['date'] as DateTime);
      final newTime = result['time'] as String;
      
      final mode = await _askCascadeMode();
      if (mode == null || !mounted) return;
      
      try {
        final auth = ref.read(authProvider);
        final currentUserId = auth.userId ?? 'system';
        
        final sessionInfo = await ref.read(appointmentServiceProvider).findSessionForAppointment(apt);
        if (sessionInfo == null || sessionInfo['sessionId'] == null) {
          throw Exception('Could not resolve linked session.');
        }
        final sessionId = sessionInfo['sessionId']!;

        if (mode == RescheduleMode.cascadeAll) {
          final lifecycle = ref.read(sessionLifecycleServiceProvider);
          final preview = await lifecycle.previewRescheduleSessionAndCascade(
            sessionId: sessionId,
            newDate: newDate,
            newTime: newTime,
            performedBy: currentUserId,
          );
          
          if (!mounted) return;
          
          final confirmed = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight),
              child: CascadePreviewSheet(
                preview: preview,
                onConfirm: () => Navigator.pop(ctx, true),
                onCancel: () => Navigator.pop(ctx, false),
              ),
            ),
          );
          
          if (confirmed != true || !mounted) return;
          
          await lifecycle.commitRescheduleProposal(preview);
          
          if (mounted) {
            final conflicts = preview.proposal.totalExpected - preview.proposal.slots.where((s) => !s.wasPinned).length;
            if (conflicts > 0) {
              showDialog(
                context: context,
                builder: (ctx) => ConflictWarningDialog(
                  successfulMoves: preview.proposal.slots.where((s) => s.oldDate != s.newDate && !s.wasPinned).length,
                  skippedSessions: preview.proposal.slots.where((s) => s.wasPinned && !s.isTarget).length,
                  totalConflicts: conflicts,
                ),
              );
            } else {
              AppToast.show('Reschedule cascade complete ✓', type: ToastType.success);
            }
          }
        } else {
          // Fallback to "this session only" logic
          final service = ref.read(appointmentServiceProvider);
          await service.rescheduleSessionAppointment(
            apt.id,
            apt,
            newDate,
            newTime,
            performedBy: currentUserId,
          );
          if (mounted) {
            AppToast.show('Session for ${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} ✓', type: ToastType.success);
          }
        }
        ref.read(appointmentListProvider.notifier).loadAppointments();
      } catch (e) {
        if (mounted) _showError('$e');
      }
    }
  }

  Future<RescheduleMode?> _askCascadeMode() => showDialog<RescheduleMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: context.colors.surface,
      title: Text('Reschedule Scope', style: context.textStyles.h3),
      content: Text(
        'How should this reschedule affect other sessions?',
        style: context.textStyles.bodyMedium,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, RescheduleMode.cascadeAll),
          child: const Text('Cascade All'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, RescheduleMode.missedOnly),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('This Session Only'),
        ),
      ],
    ),
  );

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
    AppToast.show(msg, type: ToastType.error);
  }

  Widget _buildAutoSchedulingButton({bool desktop = false}) {
    final hasPending = _pendingAutoSchedulingPlans.isNotEmpty;

    if (desktop) {
      return GestureDetector(
        onTap: () {
          AutoSchedulingDashboard.show(
            context,
            plans: _pendingAutoSchedulingPlans,
            onRefresh: () {
              _loadPendingAutoScheduling();
              ref.read(appointmentListProvider.notifier).loadAppointments();
            },
          );
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: hasPending ? context.colors.warning.withValues(alpha: 0.1) : context.colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasPending ? context.colors.warning : context.colors.border.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasPending ? Icons.sync_problem_rounded : Icons.sync_rounded,
                size: 18,
                color: hasPending ? context.colors.warning : context.colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-Scheduling',
                style: context.textStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: hasPending ? context.colors.warning : context.colors.textSecondary,
                ),
              ),
              if (hasPending) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_pendingAutoSchedulingPlans.length}',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          AutoSchedulingDashboard.show(
            context,
            plans: _pendingAutoSchedulingPlans,
            onRefresh: () {
              _loadPendingAutoScheduling();
              ref.read(appointmentListProvider.notifier).loadAppointments();
            },
          );
        },
        child: hasPending
            ? Badge(
                label: Text('${_pendingAutoSchedulingPlans.length}'),
                backgroundColor: context.colors.error,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.colors.warning.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.sync_problem_rounded,
                    size: 20,
                    color: context.colors.warning,
                  ),
                ),
              )
            : Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sync_rounded,
                  size: 20,
                  color: context.colors.textSecondary,
                ),
              ),
      );
    }
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
              VerticalDivider(
                color: Colors.white.withValues(alpha: 0.5),
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
                      style: context.textStyles.h3,
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
              heroTag: null,
              shape: const CircleBorder(),
              backgroundColor: context.colors.primary,
              onPressed: () => _showAppointmentTypeSelector(context),
              child: Icon(Icons.add, color: context.colors.textPrimary, size: 24),
            ),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: isDesktop
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header spanning full width
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 20, 36, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appointments',
                                style: context.textStyles.h1,
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
                          Row(
                            children: [
                              _buildAutoSchedulingButton(desktop: true),
                              const SizedBox(width: 12),
                              _buildNewAppointmentButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(36, 12, 36, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WebGlassCard(
                              borderRadius: 26,
                              child: Container(
                                width: 300,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
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
                                          style: context.textStyles.h3,
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
                                  Builder(
                                    builder: (context) {
                                      final arrivedCount = (consultations.where((a) => a.status == AppointmentStatus.waiting || a.status == AppointmentStatus.inProgress).length) +
                                          (sessions.where((a) => a.status == AppointmentStatus.waiting || a.status == AppointmentStatus.inProgress).length);
                                      final completedCount = (consultations.where((a) => a.status == AppointmentStatus.completed).length) +
                                          (sessions.where((a) => a.status == AppointmentStatus.completed).length);
                                      final missedCount = (consultations.where((a) => a.status == AppointmentStatus.missed || _isMissed(a)).length) +
                                          (sessions.where((a) => a.status == AppointmentStatus.missed || _isMissed(a)).length);
                                          
                                      return Wrap(
                                        spacing: 6,
                                        runSpacing: 8,
                                        children: [
                                          _filterTabItem('All', 'all', consultations.length + sessions.length),
                                          _filterTabItem('Consultations', 'consultations', consultations.length, color: context.colors.info),
                                          _filterTabItem('Sessions', 'sessions', sessions.length, color: context.colors.primary),
                                          _filterTabItem('Arrived', 'arrived', arrivedCount, color: context.colors.warning),
                                          _filterTabItem('Completed', 'completed', completedCount, color: context.colors.success),
                                          _filterTabItem('Missed', 'missed', missedCount, color: context.colors.error),
                                        ],
                                      );
                                    },
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
                                  child: Center(
                                    child: Text('Today',
                                        style: TextStyle(
                                          color: context.colors.textPrimary,
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
                              const SizedBox(width: 8),
                              _buildAutoSchedulingButton(desktop: false),
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
                    MaterialPageRoute(
                      builder: (_) => PatientInfoScreen(
                        appointment: e.value,
                        allowSkipRetroactive: e.value.requiresPatientDetailsUpdate,
                        onSkipRetroactive: () async {
                          try {
                            final pb = ref.read(pocketbaseProvider);
                            final apt = e.value;
                            final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;
                            if (hasPatientLinked) {
                              await pb.collection('patients').update(apt.patientId!, body: {'requires_patient_details_update': true});
                            }
                          } catch (_) {}
                          if (mounted) {
                            Navigator.pop(context);
                            _startConsultation(e.value);
                          }
                        },
                      ),
                    ),
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
    if (_selectedListFilter == 'arrived') {
      consultations = consultations.where((a) => a.status == AppointmentStatus.waiting || a.status == AppointmentStatus.inProgress).toList();
      sessions = sessions.where((a) => a.status == AppointmentStatus.waiting || a.status == AppointmentStatus.inProgress).toList();
    } else if (_selectedListFilter == 'completed') {
      consultations = consultations.where((a) => a.status == AppointmentStatus.completed).toList();
      sessions = sessions.where((a) => a.status == AppointmentStatus.completed).toList();
    } else if (_selectedListFilter == 'missed') {
      consultations = consultations.where((a) => a.status == AppointmentStatus.missed || _isMissed(a)).toList();
      sessions = sessions.where((a) => a.status == AppointmentStatus.missed || _isMissed(a)).toList();
    }

    final showConsults = _selectedListFilter != 'sessions';
    final showSessions = _selectedListFilter != 'consultations';

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
                      MaterialPageRoute(
                        builder: (_) => PatientInfoScreen(
                          appointment: e.value,
                          allowSkipRetroactive: e.value.requiresPatientDetailsUpdate,
                          onSkipRetroactive: () async {
                            try {
                              final pb = ref.read(pocketbaseProvider);
                              final apt = e.value;
                              final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;
                              if (hasPatientLinked) {
                                await pb.collection('patients').update(apt.patientId!, body: {'requires_patient_details_update': true});
                              }
                            } catch (_) {}
                            if (mounted) {
                              Navigator.pop(context);
                              _startConsultation(e.value);
                            }
                          },
                        ),
                      ),
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
        : context.colors.shadowColor.withValues(alpha: 0.2);

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

  void _handleRetroactiveEntry(AppointmentModel apt) async {
    // 1. Reopen appointment behind the scenes
    await ref.read(appointmentListProvider.notifier).reopenMissedAppointment(apt.id);

    // 2. Check if patient details are required
    final effectivePatientDetailsSaved = apt.isEffectivePatientDetailsSaved;

    if (!effectivePatientDetailsSaved) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientInfoScreen(
            appointment: apt,
            allowSkipRetroactive: true,
            onSkipRetroactive: () async {
              try {
                final pb = ref.read(pocketbaseProvider);
                final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;
                if (hasPatientLinked) {
                  await pb.collection('patients').update(apt.patientId!, body: {'requires_patient_details_update': true});
                }
              } catch (_) {}
              if (mounted) {
                Navigator.pop(context); // Pop PatientInfoScreen
                widget.onStartConsultation();
              }
            },
          ),
        ),
      ).then((_) {
        ref.read(appointmentListProvider.notifier).loadAppointments();
      });
    } else {
      widget.onStartConsultation();
    }
  }

  Widget _buildMiddleIndicator(BuildContext context, AppointmentModel apt, Color statusColor) {
    if (widget.isMissed) {
      return _indicatorItem(
        context: context,
        icon: Icons.event_busy_rounded,
        iconColor: context.colors.error,
        title: 'Missed',
        subtitle: 'Patient missed appointment',
        action: _buildForgotDetailsButton(context, () {
          _handleRetroactiveEntry(apt);
        }),
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
      final now = DateTime.now();
      final parts = apt.time.split(':');
      int minsLate = 1;
      if (parts.length == 2) {
        final aptTime = DateTime(now.year, now.month, now.day, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
        minsLate = now.difference(aptTime).inMinutes;
        if (minsLate < 1) minsLate = 1;
      }

      return _indicatorItem(
        context: context,
        icon: Icons.warning_amber_rounded,
        iconColor: context.colors.warning,
        title: 'Patient is late',
        subtitle: '${minsLate}m past schedule',
      );
    } else {
      final checkedIn = apt.checkInTime != null;
      
      if (checkedIn) {
        final effectivePatientDetailsSaved = apt.isEffectivePatientDetailsSaved;

        if (effectivePatientDetailsSaved) {
          return _indicatorItem(
            context: context,
            icon: Icons.check_circle_rounded,
            iconColor: context.colors.success,
            title: 'Details Filled',
            subtitle: 'Completed',
          );
        } else if (apt.patientDetailsPartial) {
          return _indicatorItem(
            context: context,
            icon: Icons.assignment_late_outlined,
            iconColor: context.colors.warning,
            title: 'Form Pending',
            subtitle: 'In Progress',
          );
        } else {
          return _indicatorItem(
            context: context,
            icon: Icons.assignment_late_outlined,
            iconColor: context.colors.warning,
            title: 'Form Pending',
            subtitle: 'Action required',
          );
        }
      }

      return _indicatorItem(
        context: context,
        icon: Icons.radio_button_unchecked,
        iconColor: context.colors.textSecondary,
        title: 'Pending',
        subtitle: widget.isFutureDate ? 'Upcoming' : 'Awaiting arrival',
        isDot: false,
      );
    }
  }

  Widget _buildForgotDetailsButton(BuildContext context, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 14,
                color: context.colors.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Forgot to fill details?',
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
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

  Widget _indicatorItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isDot = false,
    Widget? action,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isDot)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
          )
        else
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
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
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (action != null) action,
            ],
          ),
        ),
      ],
    );
  }

  void _showPhoneDialog(BuildContext context, String phone, String patientName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded, color: Color(0xFF00BFA5), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              _toTitleCase(patientName),
              style: context.textStyles.h3.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            SelectableText(
              phone,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF00BFA5), letterSpacing: 0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      Navigator.of(ctx).pop();
                      AppToast.show('Phone number copied to clipboard', type: ToastType.success);
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final url = Uri.parse('tel:$phone');
                      try {
                        await launchUrl(url);
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF25D366).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: const Icon(Icons.chat_rounded,
                color: Color(0xFF25D366), size: 16),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            if (apt.effectivePhone == null || apt.effectivePhone!.isEmpty) return;
            if (kIsWeb) {
              _showPhoneDialog(context, apt.effectivePhone!, apt.displayName);
            } else {
              final url = Uri.parse('tel:${apt.effectivePhone}');
              try {
                await launchUrl(url);
              } catch (_) {
                _showPhoneDialog(context, apt.effectivePhone!, apt.displayName);
              }
            }
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: const Icon(Icons.phone_rounded,
                color: Color(0xFF00BFA5), size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildConsultationStatus(BuildContext context, AppointmentModel apt, bool isCompleted) {
    if (isCompleted && apt.consultationFormSaved) {
      String timeStr = '';
      if (apt.consultationEndTime != null) {
        try {
          final dt = apt.consultationEndTime!.toLocal();
          timeStr = 'at ${DateFormat('h:mm a').format(dt)}';
        } catch (_) {}
      }
      return _indicatorItem(
        context: context,
        icon: Icons.check_circle_outline_rounded,
        iconColor: context.colors.success,
        title: 'Consultation Ended',
        subtitle: timeStr,
      );
    } else if (apt.status == AppointmentStatus.inProgress) {
      return _indicatorItem(
        context: context,
        icon: Icons.sync_rounded,
        iconColor: context.colors.warning,
        title: 'Consultation',
        subtitle: 'In Progress',
      );
    } else if (apt.status == AppointmentStatus.waiting || apt.checkInTime != null) {
      return _indicatorItem(
        context: context,
        icon: Icons.medical_services_outlined,
        iconColor: context.colors.textSecondary,
        title: 'Not Started',
        subtitle: 'In Waiting Queue',
      );
    } else {
      return _indicatorItem(
        context: context,
        icon: Icons.medical_services_outlined,
        iconColor: context.colors.textSecondary,
        title: 'Not Started',
        subtitle: 'Awaiting patient check-in',
      );
    }
  }

  Widget _buildDesktopSecondaryActions({
    required BuildContext context,
    required bool showRescheduleBtn,
    required bool showCancelBtn,
    required bool showUndoArrivalBtn,
  }) {
    final items = <PopupMenuEntry<String>>[];
    if (showRescheduleBtn) items.add(const PopupMenuItem(value: 'reschedule', child: Text('Reschedule')));
    if (showUndoArrivalBtn) items.add(const PopupMenuItem(value: 'undo', child: Text('Undo Arrival')));
    if (showCancelBtn) items.add(const PopupMenuItem(value: 'cancel', child: Text('Cancel Appointment', style: TextStyle(color: Colors.red))));

    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert_rounded, color: context.colors.textSecondary),
      onSelected: (value) {
        if (value == 'reschedule') widget.onReschedule();
        else if (value == 'undo') widget.onUndoArrived();
        else if (value == 'cancel') widget.onLongPress();
      },
      itemBuilder: (context) => items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: context.colors.surface,
    );
  }

  Widget _buildDesktopPrimaryAction({
    required BuildContext context,
    required bool effectiveShowPlanSection,
    required bool isCompleted,
    required bool showEndedBtn,
    required bool effectiveShowStartConsultation,
    required bool showFillDetailsBtn,
    required bool showArrivedBtn,
    required String planLabel,
    required IconData planIcon,
    required String consultationLabel,
    required IconData consultationIcon,
    required String fillDetailsLabel,
    required IconData fillDetailsIcon,
    required String? consultationId,
  }) {
    final buttons = <Widget>[];

    if (effectiveShowPlanSection && !isCompleted) {
      buttons.add(_ActionButton(
        label: planLabel,
        icon: planIcon,
        color: context.colors.primary,
        onTap: () async {
          await Future.microtask(() => widget.onCreatePlan(consultationId ?? ''));
          if (mounted) {
            setState(() {
              _planInfoLoaded = false;
              _hasPlan = false;
            });
            _loadPlanInfo();
          }
        },
        isSolid: true,
      ));
    }
    
    if (showEndedBtn) {
      buttons.add(_ActionButton(
        label: 'End Session',
        icon: Icons.check_circle_outline_rounded,
        color: context.colors.success,
        onTap: widget.onEnded,
      ));
    }
    
    if (effectiveShowStartConsultation) {
      buttons.add(_ActionButton(
        label: consultationLabel,
        icon: consultationIcon,
        color: context.colors.primary,
        onTap: widget.onStartConsultation,
        isSolid: true,
      ));
    } else if (showFillDetailsBtn) {
      buttons.add(_ActionButton(
        label: fillDetailsLabel,
        icon: fillDetailsIcon,
        color: context.colors.primary,
        onTap: widget.onFillDetails,
        isSolid: true,
      ));
    } else if (showArrivedBtn) {
      buttons.add(_ActionButton(
        label: 'Patient Arrived',
        icon: Icons.how_to_reg_rounded,
        color: context.colors.success,
        onTap: widget.onArrived,
        isSolid: true,
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < buttons.length; i++) {
      children.add(buttons[i]);
      if (i < buttons.length - 1) children.add(const SizedBox(height: 8));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
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
    } else if (apt.status == AppointmentStatus.waiting) {
      statusColor = const Color(0xFFF59E0B); statusStr = 'Waiting'; statusIcon = Icons.hourglass_empty_rounded;
    } else if (apt.status == AppointmentStatus.scheduled) {
      statusColor = const Color(0xFF7C3AED); statusStr = 'Scheduled'; statusIcon = Icons.access_time_filled;
    }

    final isCallBy = apt.type == AppointmentType.callBy;
    final typeColor = isCallBy ? context.colors.info : context.colors.accent;
    final typeLabel = isCallBy ? 'Call-By' : 'Walk-In';
    final typeIcon = isCallBy ? Icons.event_note_rounded : Icons.directions_walk_rounded;

    final isScheduled = apt.status == AppointmentStatus.scheduled;
    final isWaiting = apt.status == AppointmentStatus.waiting;
    final isInProgress = apt.status == AppointmentStatus.inProgress;
    // Treat waiting + inProgress together as the "active" post-arrival state
    final isActive = isWaiting || isInProgress;
    final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;

    // Step 1: Patient Arrived
    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showRescheduleBtn = isScheduled && (widget.isFutureDate || !widget.isMissed) || widget.isMissed && !isInProgress;

    final effectivePatientDetailsSaved = apt.isEffectivePatientDetailsSaved;

    // Step 2: Fill Patient Details
    final showFillDetailsBtn = isActive && (!hasPatientLinked || !effectivePatientDetailsSaved);
    final fillDetailsLabel = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? 'Resume Filling Details'
        : 'Fill Patient Details';
    final fillDetailsIcon = apt.patientDetailsPartial && !apt.patientDetailsSaved
        ? Icons.edit_note_rounded
        : Icons.badge_rounded;


    // Step 3: Start/Resume Consultation
    final showStartConsultationBtn = isActive &&
        hasPatientLinked &&
        effectivePatientDetailsSaved &&
        !apt.consultationFormSaved;
    final consultationLabel = apt.consultationStartTime != null && !apt.consultationFormSaved
        ? 'Resume Consult'
        : 'Start Consult';
    final consultationIcon = apt.consultationStartTime != null && !apt.consultationFormSaved
        ? Icons.arrow_forward_rounded
        : Icons.medical_services_rounded;

    // Step 4: Create/Resume Treatment Plan + End Appointment
    // Guard: require _consultationId to be live (non-null) before showing this.
    // If the consultation was deleted externally, _loadPlanInfo() returns null
    // and this button correctly stays hidden. (Option B — stale-state guard)
    final showPlanSection = apt.consultationFormSaved &&
        apt.linkedTreatmentPlanId == null &&
        !(_planInfoLoaded && _hasPlan) &&
        _consultationId != null;
    final planLabel = apt.treatmentPlanPartial ? 'Resume Treatment Plan' : 'Create Plan';
    final planIcon = apt.treatmentPlanPartial ? Icons.restart_alt_rounded : Icons.add_chart_rounded;

    final isReceptionist = ref.read(authProvider).role == UserRole.receptionist;
    final effectiveShowStartConsultation = showStartConsultationBtn && !isReceptionist;
    final effectiveShowPlanSection = showPlanSection && !isReceptionist;
    final isCompleted = apt.status == AppointmentStatus.completed;
    final showEndedBtn = apt.consultationFormSaved && !isReceptionist && !isCompleted && !isWaiting;

    // Left accent color
    final accentColor = widget.isMissed || apt.status == AppointmentStatus.cancelled
        ? context.colors.error
        : widget.isLate
            ? context.colors.warning
            : isActive
                ? context.colors.warning
                : statusColor;

    final showEndedLabel = isCompleted && apt.consultationFormSaved && !isReceptionist;
    final hasActions = showArrivedBtn || showRescheduleBtn || showFillDetailsBtn ||
        effectiveShowStartConsultation || effectiveShowPlanSection || showEndedBtn || showEndedLabel;
    
    final hasPrimaryActions = effectiveShowPlanSection || showEndedBtn || effectiveShowStartConsultation || showFillDetailsBtn || showArrivedBtn;

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
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadowColor.withValues(alpha: 0.1),
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
                  sigmaX: 0,
                  sigmaY: 0,
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
                                  ? IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Column 1: Time
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      TimeUtils.formatStringTime(apt.time).split(' ')[0],
                                                      style: context.textStyles.h2.copyWith(color: accentColor, fontWeight: FontWeight.bold, fontSize: 22, height: 1.1),
                                                    ),
                                                  ),
                                                  if (TimeUtils.formatStringTime(apt.time).split(' ').length > 1)
                                                    Text(
                                                      TimeUtils.formatStringTime(apt.time).split(' ')[1],
                                                      style: context.textStyles.h3.copyWith(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14, height: 1.1),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                          // Column 2: Patient details (Name, Doctor, Pills)
                                          Expanded(
                                            flex: 4,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _toTitleCase(apt.displayName),
                                                    style: context.textStyles.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (widget.showDoctorName && apt.doctorName != null && apt.doctorName!.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.person_outline_rounded, size: 12, color: context.colors.textHint),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            'Dr. ${_toTitleCase(apt.doctorName!)}',
                                                            style: context.textStyles.caption.copyWith(fontSize: 11, color: context.colors.textSecondary),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      if (apt.status != AppointmentStatus.scheduled)
                                                        _Pill(label: statusStr, icon: statusIcon, color: statusColor),
                                                      _Pill(label: typeLabel, icon: typeIcon, color: typeColor),
                                                      if (apt.isRescheduled)
                                                        _Pill(label: 'Rescheduled', icon: Icons.event_repeat_rounded, color: const Color(0xFFF59E0B)),
                                                      if (apt.isPinned)
                                                        _Pill(label: 'Pinned', icon: Icons.push_pin_rounded, color: const Color(0xFF8B5CF6)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                          // Column 3: Arrival Status
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Center(
                                                child: _buildMiddleIndicator(context, apt, statusColor),
                                              ),
                                            ),
                                          ),
                                          VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                          // Column 4: Consultation Status
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Center(
                                                child: _buildConsultationStatus(context, apt, apt.status == AppointmentStatus.completed),
                                              ),
                                            ),
                                          ),
                                          VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                          // Column 5: Actions
                                          Expanded(
                                            flex: 4,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  if (!isActive) ...[
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty) ...[
                                                          _buildContactButtons(context, apt),
                                                          const SizedBox(width: 6),
                                                        ],
                                                        _buildDesktopSecondaryActions(
                                                          context: context,
                                                          showRescheduleBtn: showRescheduleBtn,
                                                          showCancelBtn: !widget.isMissed && apt.status != AppointmentStatus.cancelled,
                                                          showUndoArrivalBtn: isCallBy && isActive && apt.checkInTime != null && !apt.patientDetailsSaved && !apt.consultationFormSaved,
                                                        ),
                                                      ],
                                                    ),
                                                    if (hasPrimaryActions) ...[
                                                      const SizedBox(height: 8),
                                                      _buildDesktopPrimaryAction(
                                                        context: context,
                                                        effectiveShowPlanSection: effectiveShowPlanSection,
                                                        isCompleted: apt.status == AppointmentStatus.completed,
                                                        showEndedBtn: showEndedBtn,
                                                        effectiveShowStartConsultation: effectiveShowStartConsultation,
                                                        showFillDetailsBtn: showFillDetailsBtn,
                                                        showArrivedBtn: showArrivedBtn,
                                                        planLabel: planLabel,
                                                        planIcon: planIcon,
                                                        consultationLabel: consultationLabel,
                                                        consultationIcon: consultationIcon,
                                                        fillDetailsLabel: fillDetailsLabel,
                                                        fillDetailsIcon: fillDetailsIcon,
                                                        consultationId: _consultationId,
                                                      ),
                                                    ],
                                                  ] else ...[
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (hasPrimaryActions)
                                                          Expanded(
                                                            child: _buildDesktopPrimaryAction(
                                                              context: context,
                                                              effectiveShowPlanSection: effectiveShowPlanSection,
                                                              isCompleted: apt.status == AppointmentStatus.completed,
                                                              showEndedBtn: showEndedBtn,
                                                              effectiveShowStartConsultation: effectiveShowStartConsultation,
                                                              showFillDetailsBtn: showFillDetailsBtn,
                                                              showArrivedBtn: showArrivedBtn,
                                                              planLabel: planLabel,
                                                              planIcon: planIcon,
                                                              consultationLabel: consultationLabel,
                                                              consultationIcon: consultationIcon,
                                                              fillDetailsLabel: fillDetailsLabel,
                                                              fillDetailsIcon: fillDetailsIcon,
                                                              consultationId: _consultationId,
                                                            ),
                                                          ),
                                                        if (hasPrimaryActions)
                                                          const SizedBox(width: 8),
                                                        _buildDesktopSecondaryActions(
                                                          context: context,
                                                          showRescheduleBtn: showRescheduleBtn,
                                                          showCancelBtn: !widget.isMissed && apt.status != AppointmentStatus.cancelled,
                                                          showUndoArrivalBtn: isCallBy && isActive && apt.checkInTime != null && !apt.patientDetailsSaved && !apt.consultationFormSaved,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                                                  if (apt.isPinned)
                                                    _Pill(
                                                      label: 'Pinned',
                                                      icon: Icons.push_pin_rounded,
                                                      color: const Color(0xFF8B5CF6),
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
                                            if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty && !isActive) ...[
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
                              _InfoBanner(
                                Icons.event_busy_rounded,
                                'Patient missed this appointment',
                                context.colors.error,
                                actionLabel: 'Forgot to fill details?',
                                onActionTap: () {
                                  _handleRetroactiveEntry(apt);
                                },
                              ),
                            if (widget.isLate && !widget.isMissed)
                              _InfoBanner(Icons.warning_amber_rounded,
                                  'Patient is late \u2014 hasn\'t arrived yet', context.colors.warning),
                          ],

                          // Actions section
                          if (!isDesktop && hasActions) ...[
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
                                  if (isCallBy && isActive && apt.checkInTime != null &&
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (effectiveShowPlanSection) ...[
                                          _ActionButton(
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
                                          if (showEndedBtn) const SizedBox(height: 8),
                                        ],
                                        if (showEndedBtn)
                                          _ActionButton(
                                            label: 'End Appointment',
                                            icon: Icons.check_circle_outline_rounded,
                                            color: context.colors.success,
                                            onTap: widget.onEnded,
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

// ------------------------------------------------------------------------------------------------------------------------------------------------------
// Treatment Session Card — distinct flow from consultation cards
// ------------------------------------------------------------------------------------------------------------------------------------------------------

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
  /// Pre-loaded session info from parent batch-load — skips per-card PB query.
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
  String? _treatmentModality; // resolved: session.treatment_type OR plan.treatment_type
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
      final sessionId = info['id'] as String?;
      final rawModality = info['treatmentModality'] as String? ?? '';
      final planId = info['planId'] as String? ?? '';
      String resolvedModality = rawModality;
      if (resolvedModality.isEmpty && planId.isNotEmpty) {
        try {
          final pb = ref.read(pocketbaseProvider);
          final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
          resolvedModality = planRec.getStringValue('treatment_type');
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _sessionNumber = info['number'] as int? ?? 0;
          _sessionType = info['type'] as String? ?? 'treatment';
          _sessionId = sessionId;
          _treatmentModality = resolvedModality;
          _sessionNumLoaded = true;
        });
        if (sessionId != null) _subscribeToSession(sessionId);
      }
      return;
    }
    try {
      final service = ref.read(appointmentServiceProvider);
      final info = await service.getSessionInfoForAppointment(widget.apt);
      if (mounted && info != null) {
        final sessionId = info['id'] as String?;
        final rawModality = info['treatmentModality'] as String? ?? '';
        final planId = info['planId'] as String? ?? '';
        String resolvedModality = rawModality;
        if (resolvedModality.isEmpty && planId.isNotEmpty) {
          try {
            final pb = ref.read(pocketbaseProvider);
            final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
            resolvedModality = planRec.getStringValue('treatment_type');
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _sessionNumber = info['number'] as int;
            _sessionType = info['type'] as String;
            _sessionId = sessionId;
            _treatmentModality = resolvedModality;
            _sessionNumLoaded = true;
          });
          if (sessionId != null) _subscribeToSession(sessionId);
        }
      }
    } catch (_) {}
  }

  void _subscribeToSession(String sessionId) {
    try {
      final pb = ref.read(pocketbaseProvider);
      pb.collection(PBCollections.sessions).subscribe(sessionId, (event) {
        if (!mounted) return;
        final newModality = event.record?.getStringValue('treatment_type') ?? '';
        if (newModality.isNotEmpty && newModality != (_treatmentModality ?? '')) {
          setState(() => _treatmentModality = newModality);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    SessionTimerService.instance.removeGlobalListener(_onTimerChanged);
    if (_sessionId != null) {
      try {
        final pb = ref.read(pocketbaseProvider);
        pb.collection(PBCollections.sessions).unsubscribe(_sessionId!);
      } catch (_) {}
    }
    _ctrl.dispose();
    super.dispose();
  }

  void _onTimerChanged() {
    if (mounted) setState(() {});
  }

  void _handleRetroactiveEntry(AppointmentModel apt) async {
    // 1. Reopen appointment behind the scenes
    await ref.read(appointmentListProvider.notifier).reopenMissedAppointment(apt.id);

    // 2. Check if patient details are required
    final effectivePatientDetailsSaved = apt.isEffectivePatientDetailsSaved;

    if (!effectivePatientDetailsSaved) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientInfoScreen(
            appointment: apt,
            allowSkipRetroactive: true,
            onSkipRetroactive: () async {
              try {
                final pb = ref.read(pocketbaseProvider);
                final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;
                if (hasPatientLinked) {
                  await pb.collection('patients').update(apt.patientId!, body: {'requires_patient_details_update': true});
                }
              } catch (_) {}
              if (mounted) {
                Navigator.pop(context); // Pop PatientInfoScreen
                widget.onStartSession(_sessionId);
              }
            },
          ),
        ),
      ).then((_) {
        ref.read(appointmentListProvider.notifier).loadAppointments();
      });
    } else {
      widget.onStartSession(_sessionId);
    }
  }



  Widget _buildSessionStatus(BuildContext context, AppointmentModel apt, bool isCompleted) {
    if (widget.isMissed) {
      return _indicatorItem(
        context: context,
        icon: Icons.event_busy_rounded,
        iconColor: context.colors.error,
        title: 'Missed',
        subtitle: 'Patient missed session',
        action: _buildForgotDetailsButton(context, () {
          _handleRetroactiveEntry(apt);
        }),
      );
    } else if (apt.status == AppointmentStatus.cancelled) {
      return _indicatorItem(
        context: context,
        icon: Icons.cancel_rounded,
        iconColor: context.colors.error,
        title: 'Cancelled',
        subtitle: 'Session cancelled',
      );
    } else if (isCompleted) {
      String timeStr = '';
      if (apt.consultationEndTime != null) {
        timeStr = 'at ${DateFormat('h:mm a').format(apt.consultationEndTime!.toLocal())}';
      }
      return _indicatorItem(
        context: context,
        icon: Icons.check_circle_outline_rounded,
        iconColor: context.colors.success,
        title: 'Session Ended',
        subtitle: timeStr,
      );
    } else if (apt.status == AppointmentStatus.inProgress) {
      return _indicatorItem(
        context: context,
        icon: Icons.sync_rounded,
        iconColor: context.colors.warning,
        title: 'Session',
        subtitle: 'In Progress',
      );
    } else if (apt.status == AppointmentStatus.waiting || apt.checkInTime != null) {
      return _indicatorItem(
        context: context,
        icon: Icons.healing_outlined,
        iconColor: context.colors.textSecondary,
        title: 'Not Started',
        subtitle: 'In Waiting Queue',
      );
    } else {
      return _indicatorItem(
        context: context,
        icon: Icons.healing_outlined,
        iconColor: context.colors.textSecondary,
        title: 'Not Started',
        subtitle: 'Session pending',
      );
    }
  }

  Widget _buildForgotDetailsButton(BuildContext context, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 14,
                color: context.colors.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Forgot to fill details?',
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
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

  IconData _treatmentTypeIcon(String type) {
    switch (type) {
      case 'Acupuncture':
        return Icons.medical_information_outlined;
      case 'Acupressure':
        return Icons.touch_app_rounded;
      case 'Cupping Therapy':
        return Icons.spa_outlined;
      case 'Physiotherapy':
        return Icons.accessibility_new_rounded;
      case 'Foot Reflexology':
        return Icons.directions_walk_rounded;
      default:
        return Icons.healing_outlined;
    }
  }

  Widget _indicatorItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isDot = false,
    Widget? action,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isDot)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
          )
        else
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
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
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (action != null) action,
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

    final showArrivedBtn = isScheduled && !widget.isFutureDate && !widget.isMissed;
    final showStartBtn   = isWaiting && !widget.isFutureDate;
    final showResumeBtn  = isInProgress; 
    final showEndedBtn   = isInProgress;

    final List<Widget> buttons = [];

    if (showArrivedBtn) {
      buttons.add(_ActionButton(
        label: 'Patient Arrived',
        icon: Icons.how_to_reg_rounded,
        color: context.colors.success,
        onTap: widget.onArrived,
      ));
    }

    if (showStartBtn) {
      final needsDetails = !apt.isEffectivePatientDetailsSaved;
      buttons.add(_ActionButton(
        label: needsDetails ? 'Fill Patient Details' : 'Start Session',
        icon: needsDetails ? Icons.badge_rounded : Icons.play_arrow_rounded,
        color: context.colors.primary,
        onTap: () => needsDetails ? _handleRetroactiveEntry(apt) : widget.onStartSession(_sessionId),
        isSolid: true,
        showTrailingChevron: true,
      ));
    }

    if (showResumeBtn) {
      final needsDetails = !apt.isEffectivePatientDetailsSaved;
      buttons.add(_ActionButton(
        label: needsDetails ? 'Fill Patient Details' : 'Resume Session',
        icon: needsDetails ? Icons.badge_rounded : Icons.play_circle_outline_rounded,
        color: context.colors.primary,
        onTap: () => needsDetails ? _handleRetroactiveEntry(apt) : widget.onStartSession(_sessionId),
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

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          buttons[i],
        ],
      ],
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
    if (timerEntry == null || !timerEntry.isActive) return _buildSessionStatus(context, apt, widget.apt.status == AppointmentStatus.completed);

    final mins = timerEntry.remainingSeconds ~/ 60;
    final secs = timerEntry.remainingSeconds % 60;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.warning.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SESSION TIMER',
              style: context.textStyles.caption.copyWith(
                color: context.colors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: context.colors.warning,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (timerEntry.isPaused)
              Text(
                'Paused',
                style: context.textStyles.caption.copyWith(
                  color: context.colors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              )
            else
              Text(
                'remaining',
                style: context.textStyles.caption.copyWith(
                  color: context.colors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
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
    final bool isActive = isWaiting || isInProgress;
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
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadowColor.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.03),
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
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                                child: isDesktop
                                    ? IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Col 1: Time (flex 2) - Hidden if in progress
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                TimeUtils.formatStringTime(apt.time).replaceAll(' AM', '').replaceAll(' PM', ''),
                                                style: TextStyle(
                                                  color: accentColor,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              Text(
                                                TimeUtils.formatStringTime(apt.time).contains('AM') ? 'AM' : 'PM',
                                                style: TextStyle(
                                                  color: accentColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                    
                                    // Col 2: Patient details
                                    Expanded(
                                      flex: 4,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _toTitleCase(apt.displayName),
                                              style: context.textStyles.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (widget.showDoctorName && apt.doctorName != null && apt.doctorName!.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Icon(Icons.person_outline_rounded, size: 12, color: context.colors.textHint),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Dr. ${apt.doctorName != null ? _toTitleCase(apt.doctorName!) : ''}',
                                                      style: context.textStyles.caption.copyWith(fontSize: 11, color: context.colors.textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (_treatmentModality != null && _treatmentModality!.isNotEmpty)
                                                  _Pill(
                                                    label: _treatmentModality!,
                                                    icon: _treatmentTypeIcon(_treatmentModality!),
                                                    color: sessionAccent,
                                                  ),
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
                                                if (apt.isPinned)
                                                  _Pill(
                                                    label: 'Pinned',
                                                    icon: Icons.push_pin_rounded,
                                                    color: const Color(0xFF8B5CF6),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                    
                                    // Col 3: Session Status
                                    Expanded(
                                      flex: 6,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Center(
                                          child: isInProgress ? _buildDesktopTimer(context) : _buildSessionStatus(context, apt, isCompleted),
                                        ),
                                      ),
                                    ),
                                    VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                    
                                    // Col 4: Actions
                                    Expanded(
                                      flex: 4,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (!isActive) ...[
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty)
                                                    _buildContactButtons(context, apt)
                                                  else
                                                    const SizedBox.shrink(),
                                                  PopupMenuButton<String>(
                                                    padding: EdgeInsets.zero,
                                                    icon: Icon(Icons.more_vert_rounded, color: context.colors.textSecondary),
                                                    onSelected: (value) {
                                                      if (value == 'reschedule') widget.onReschedule();
                                                      else if (value == 'undo') widget.onUndoArrived();
                                                      else if (value == 'cancel') widget.onLongPress();
                                                    },
                                                    itemBuilder: (BuildContext context) {
                                                      final items = <PopupMenuEntry<String>>[];
                                                      if (showRescheduleBtn) {
                                                        items.add(const PopupMenuItem<String>(value: 'reschedule', child: Text('Reschedule')));
                                                      }
                                                      final showUndoArrivedBtn = isWaiting && apt.checkInTime != null;
                                                      if (showUndoArrivedBtn) {
                                                        items.add(const PopupMenuItem<String>(value: 'undo', child: Text('Undo Arrival')));
                                                      }
                                                      final showCancelBtn = !isCancelled && !isCompleted && !widget.isMissed;
                                                      if (showCancelBtn) {
                                                        items.add(const PopupMenuItem<String>(value: 'cancel', child: Text('Cancel Session')));
                                                      }
                                                      return items;
                                                    },
                                                  ),
                                                ],
                                              ),
                                              if (hasActions) ...[
                                                const SizedBox(height: 8),
                                                _buildDesktopActions(context),
                                              ],
                                            ] else ...[
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (hasActions)
                                                    Expanded(
                                                      child: _buildDesktopActions(context),
                                                    ),
                                                  if (hasActions)
                                                    const SizedBox(width: 8),
                                                  PopupMenuButton<String>(
                                                    padding: EdgeInsets.zero,
                                                    icon: Icon(Icons.more_vert_rounded, color: context.colors.textSecondary),
                                                    onSelected: (value) {
                                                      if (value == 'reschedule') widget.onReschedule();
                                                      else if (value == 'undo') widget.onUndoArrived();
                                                      else if (value == 'cancel') widget.onLongPress();
                                                    },
                                                    itemBuilder: (BuildContext context) {
                                                      final items = <PopupMenuEntry<String>>[];
                                                      if (showRescheduleBtn) {
                                                        items.add(const PopupMenuItem<String>(value: 'reschedule', child: Text('Reschedule')));
                                                      }
                                                      final showUndoArrivedBtn = isWaiting && apt.checkInTime != null;
                                                      if (showUndoArrivedBtn) {
                                                        items.add(const PopupMenuItem<String>(value: 'undo', child: Text('Undo Arrival')));
                                                      }
                                                      final showCancelBtn = !isCancelled && !isCompleted && !widget.isMissed;
                                                      if (showCancelBtn) {
                                                        items.add(const PopupMenuItem<String>(value: 'cancel', child: Text('Cancel Session')));
                                                      }
                                                      return items;
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                        ],
                                      ),
                                    )
                                  : Row(
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
                                                  _toTitleCase(apt.displayName),
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
                                                    if (_treatmentModality != null && _treatmentModality!.isNotEmpty)
                                                      _Pill(
                                                        label: _treatmentModality!,
                                                        icon: _treatmentTypeIcon(_treatmentModality!),
                                                        color: sessionAccent,
                                                      ),
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
                                                    if (apt.isPinned)
                                                      _Pill(
                                                        label: 'Pinned',
                                                        icon: Icons.push_pin_rounded,
                                                        color: const Color(0xFF8B5CF6),
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
                                              if (apt.effectivePhone != null && apt.effectivePhone!.isNotEmpty && !isActive) ...[
                                                const SizedBox(height: 8),
                                                _buildContactButtons(context, apt),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            // Banners and actions only for mobile layout
                            if (!isDesktop) ...[
                              if (widget.isMissed)
                                    _InfoBanner(
                                      Icons.event_busy_rounded,
                                      'Patient missed this session',
                                      context.colors.error,
                                      actionLabel: 'Forgot to fill details?',
                                      onActionTap: () {
                                        _handleRetroactiveEntry(apt);
                                      },
                                    ),
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
                                              label: !apt.isEffectivePatientDetailsSaved ? 'Fill Patient Details' : 'Start Session',
                                              icon: !apt.isEffectivePatientDetailsSaved ? Icons.badge_rounded : Icons.play_arrow_rounded,
                                              color: context.colors.primary,
                                              onTap: () => !apt.isEffectivePatientDetailsSaved ? _handleRetroactiveEntry(apt) : widget.onStartSession(_sessionId),
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
                                              label: !apt.isEffectivePatientDetailsSaved ? 'Fill Patient Details' : 'Resume Session',
                                              icon: !apt.isEffectivePatientDetailsSaved ? Icons.badge_rounded : Icons.play_circle_outline_rounded,
                                              color: context.colors.primary,
                                              onTap: () => !apt.isEffectivePatientDetailsSaved ? _handleRetroactiveEntry(apt) : widget.onStartSession(_sessionId),
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
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _InfoBanner(
    this.icon,
    this.message,
    this.color, {
    this.actionLabel,
    this.onActionTap,
  });

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
        if (actionLabel != null && onActionTap != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_note_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    actionLabel!,
                    style: context.textStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

String _toTitleCase(String text) {
  if (text.trim().isEmpty) return text;
  return text.trim().split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                  ),
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
              color: context.colors.shadowColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationY = widget.animateHover && _isHovered ? -3.0 : 0.0;
    final hoverGlowOpacity = widget.animateHover && _isHovered ? 0.08 : 0.04;
    
    // Soften shadows in light mode to prevent muddy translucent bleeding
    final mainShadowOpacity = isDark
        ? (widget.animateHover && _isHovered ? 0.40 : 0.35)
        : (widget.animateHover && _isHovered ? 0.08 : 0.05);
    final secondShadowOpacity = isDark ? 0.15 : 0.02;

    final activeGlowColor = widget.glowColor ?? const Color(0xFF3B82F6);
    
    // In light mode, use a clean, highly opaque white background (alpha 0.90).
    // In dark mode, keep the translucent glassmorphic look (alpha 0.07).
    final cardBgColor = isDark
        ? context.colors.cardBackground.withValues(alpha: 0.07)
        : context.colors.cardBackground.withValues(alpha: 0.90);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0.0, translationY, 0.0),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: context.colors.border.withValues(alpha: isDark ? 0.4 : 0.6),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadowColor.withValues(alpha: mainShadowOpacity),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: context.colors.shadowColor.withValues(alpha: secondShadowOpacity),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (isDark)
              BoxShadow(
                color: activeGlowColor.withValues(alpha: hoverGlowOpacity),
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





