import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/core/widgets/patient_details_form.dart';
import 'package:pms_app/core/utils/time_utils.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import 'package:pms_app/core/services/scheduling_service.dart';
import 'package:pms_app/features/scheduling/screens/available_slots_screen.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/services/audit_service.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/widgets/responsive_wrapper.dart';
import 'package:pms_app/features/patients/screens/family_member_selection_screen.dart';


class CreateAppointmentScreen extends ConsumerStatefulWidget {
  final bool initialIsCallBy;

  const CreateAppointmentScreen({super.key, this.initialIsCallBy = true});

  @override
  ConsumerState<CreateAppointmentScreen> createState() =>
      _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState
    extends ConsumerState<CreateAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isCallBy = true;
  bool _forceWalkIn = false;
  bool _isSubmitting = false;
  Timer? _phoneDebounce;
  bool _isCheckingPhone = false;

  // Patient fields (shared by both call-by and walk-in)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Extended Patient fields (for walk-in only)
  // Walk-in extended patient fields (shared via PatientDetailsForm)
  final _dobCtrl = TextEditingController();   // YYYY-MM-DD
  final _pincodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  String? _selectedGender;
  bool _dataConsentGiven = false;
  bool _privacyPolicyAccepted = false;

  String? _howDidYouHear;

  // Slot selection
  DateTime? _selectedDate;
  String? _selectedTimeStr; // e.g. "09:00" — raw string from AvailableSlotsScreen
  String? _selectedDoctorId;
  List<Map<String, String>> _doctors = [];

  // Phone lookup state
  PatientModel? _existingPatient; // non-null if phone matched a patient record
  bool _isRegisteredPatient = false; // true when walk-in phone matches existing
  bool _isNewFamilyMember = false;  // true when adding a new family member
  String? _selectedRelation;        // relation for new family member
  String? _handledPhone;
  List<PatientModel> _matchingPatients = [];
  String _selectedPhoneCode = '+91';

  @override
  void initState() {
    super.initState();
    _isCallBy = widget.initialIsCallBy;
    _loadDoctors();
    _phoneCtrl.addListener(_onPhoneChanged);
    // Pre-fill city from clinic profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final city = ref.read(authProvider).clinic?.city;
      if (city != null && city.isNotEmpty && _cityCtrl.text.isEmpty) {
        _cityCtrl.text = city;
      }
    });
  }

  Future<void> _loadDoctors() async {
    final auth = ref.read(authProvider);
    if (auth.role == UserRole.clinic && auth.userId != null) {
      final service = ref.read(appointmentServiceProvider);
      final docs = await service.getClinicDoctors(auth.userId!);
      setState(() {
        _doctors = docs;
        if (_doctors.length == 1) {
          _selectedDoctorId = _doctors.first['id'];
        }
      });
    } else {
      // Doctor role — only themselves
      setState(() {
        _selectedDoctorId = auth.userId;
      });
    }
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _pincodeCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _occupationCtrl.dispose();
    _emailCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    _phoneDebounce?.cancel();
    final phone = _phoneCtrl.text.trim();
    final expectedLength = Validators.countryPhoneCodes[_selectedPhoneCode] ?? 10;
    
    // Concatenate code + national number for comparison & lookup
    final combined = '$_selectedPhoneCode$phone';
    if (combined == _handledPhone) return;

    if (phone.length < expectedLength) {
      if (_handledPhone != null) {
        setState(() {
          _handledPhone = null;
          _existingPatient = null;
          _isRegisteredPatient = false;
          _isNewFamilyMember = false;
          _selectedRelation = null;
          _matchingPatients = [];
        });
      }
      return;
    }
    _phoneDebounce = Timer(const Duration(milliseconds: 600), () => _checkPhone(combined));
  }

  Future<void> _checkPhone(String phone, {bool forceShowScreen = false}) async {
    if (_isCheckingPhone) return;
    if (!forceShowScreen && phone == _handledPhone) return;

    setState(() => _isCheckingPhone = true);

    final auth = ref.read(authProvider);
    final doctorId = _selectedDoctorId ?? auth.userId;
    if (doctorId == null) {
      setState(() => _isCheckingPhone = false);
      return;
    }

    final service = ref.read(appointmentServiceProvider);
    final allPatients = await service.findAllPatientsByPhone(
      phone,
      doctorId,
      clinicId: auth.clinicId,
    );

    if (mounted) setState(() => _isCheckingPhone = false);
    if (!mounted) return;

    _handledPhone = phone;
    _matchingPatients = allPatients;

    if (allPatients.isEmpty) {
      setState(() {
        _existingPatient = null;
        _isRegisteredPatient = false;
        _isNewFamilyMember = false;
        _selectedRelation = null;
      });
      return;
    }

    // If 1 patient found and not forced, auto-select them immediately
    if (allPatients.length == 1 && !forceShowScreen) {
      _applySelectedPatient(allPatients.first);
      return;
    }

    // 2+ patients OR forced: show FamilyMemberSelectionScreen modal
    final result = await Navigator.push<FamilySelectionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyMemberSelectionScreen(
          patients: allPatients,
          phone: phone,
        ),
      ),
    );

    if (!mounted) return;

    if (result == null) {
      // Dismissed without selection — keep current state if already set, else default
      return;
    }

    if (result.isNew) {
      _applyNewFamilyMemberMode(allPatients.first);
    } else if (result.selected != null) {
      _applySelectedPatient(result.selected!);
    }
  }

  void _applySelectedPatient(PatientModel existing) {
    _nameCtrl.text = existing.fullName;
    final parsed = PhoneParser.parse(existing.phone);
    _selectedPhoneCode = parsed.$1;
    _phoneCtrl.text = parsed.$2;
    if (existing.dateOfBirth != null && existing.dateOfBirth!.isNotEmpty) _dobCtrl.text = existing.dateOfBirth!;
    if (existing.city != null && existing.city!.isNotEmpty) _cityCtrl.text = existing.city!;
    if (existing.area != null && existing.area!.isNotEmpty) _areaCtrl.text = existing.area!;
    if (existing.occupation != null && existing.occupation!.isNotEmpty) _occupationCtrl.text = existing.occupation!;
    if (existing.email != null && existing.email!.isNotEmpty) _emailCtrl.text = existing.email!;
    if (existing.gender != null && existing.gender!.isNotEmpty) _selectedGender = existing.gender;
    setState(() {
      _existingPatient = existing;
      _isRegisteredPatient = !_isCallBy;
      _isNewFamilyMember = false;
      _selectedRelation = null;
    });
  }

  void _applyNewFamilyMemberMode(PatientModel primary) {
    if (primary.city != null && primary.city!.isNotEmpty) _cityCtrl.text = primary.city!;
    if (primary.area != null && primary.area!.isNotEmpty) _areaCtrl.text = primary.area!;
    if (primary.pincode != null && primary.pincode!.isNotEmpty) _pincodeCtrl.text = primary.pincode!;
    _nameCtrl.clear();
    _dobCtrl.clear();
    _occupationCtrl.clear();
    _emailCtrl.clear();
    setState(() {
      _existingPatient = null;
      _isRegisteredPatient = false;
      _isNewFamilyMember = true;
      _selectedRelation = null;
      _selectedGender = null;
    });
  }

  Widget _buildRelationDropdown() {
    final relations = ['Spouse', 'Child', 'Parent', 'Sibling', 'Other'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Relation to Primary Patient', style: context.textStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRelation,
              isExpanded: true,
              hint: Text('Select relation (e.g. Spouse, Child)',
                  style: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textHint)),
              items: relations
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: context.textStyles.bodyMedium),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedRelation = v),
            ),
          ),
        ),
      ],
    );
  }


  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickSlot() async {
    // Dismiss keyboard to prevent cursor jumping back after navigation
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));

    final auth = ref.read(authProvider);
    final isClinic = auth.role == UserRole.clinic;
    final doctorId = isClinic ? _selectedDoctorId : auth.userId;

    if (doctorId == null) {
      AppToast.show('Please select a doctor first');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: doctorId,
          clinicId: auth.clinicId,
          treatmentDuration: 30,
          allowFutureDates: _isCallBy, // call-by allows future; walk-in = today only
          initialDate: DateTime.now(),  // slot screen calendar handles date picking
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedDate = result['date'] as DateTime;
        _selectedTimeStr = result['time'] as String;
      });
    }
  }


  bool get _hasSlotSelected {
    if (!_isCallBy && _forceWalkIn) return true;
    return _selectedDate != null && _selectedTimeStr != null;
  }

  String get _slotDisplayText {
    if (!_hasSlotSelected) return 'Tap to select a slot';
    return '${DateFormat('MMM d, yyyy').format(_selectedDate!)} at ${TimeUtils.formatStringTime(_selectedTimeStr!)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture navigator before async gap — fixes Vivo/iQOO devices
    final navigator = Navigator.of(context);

    // Gender is mandatory for walk-in
    if (!_isCallBy && _selectedGender == null) {
      AppToast.show('Please select the patient\'s gender', type: ToastType.error);
      return;
    }

    // Both consent checkboxes are mandatory for walk-in
    if (!_isCallBy && (!_dataConsentGiven || !_privacyPolicyAccepted)) {
      AppToast.show('Both consent checkboxes are required to proceed.', type: ToastType.error);
      return;
    }

    if (!_hasSlotSelected) {
      AppToast.show('Please select a time slot first', type: ToastType.error);
      return;
    }
    final auth = ref.read(authProvider);
    final doctorId = _selectedDoctorId ?? auth.userId;
    if (doctorId == null) return;

    // --- Duplicate Appointment Check (same-date scheduled) ---
    final service = ref.read(appointmentServiceProvider);
    final phone = '$_selectedPhoneCode${_phoneCtrl.text.trim()}';
    final checkDate = _formatDate(_selectedDate ?? DateTime.now());

    // For walk-ins: block if same phone already has any active appointment today (prevents
    // dual registration of the same patient under a different name).
    if (!_isCallBy) {
      final todayDuplicate = await service.findAnyActiveTodayByPhone(phone, doctorId);
      if (todayDuplicate != null && mounted) {
        final existingName = todayDuplicate.displayName;
        AppToast.show('This phone number is already registered today as "$existingName". '
              'A patient can only have one consultation per day. '
              'Please find the existing appointment in the schedule.', type: ToastType.error, duration: const Duration(seconds: 6));
        return;
      }
    }

    final existingAppt = await service.findExistingAppointment(phone, doctorId, date: checkDate);
    if (existingAppt != null && mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: context.colors.surface,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text('Slot Already Booked')),
            ],
          ),
          content: Text('This patient already has a scheduled appointment on ${existingAppt.date} at ${TimeUtils.formatStringTime(existingAppt.time)}.\n\nDo you want to keep the old appointment or replace it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), 
              child: const Text('Keep Old')
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.warning, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (replace != true) {
        // Keep old, abort form submission
        return;
      }

      // If Replace, ask for secondary confirmation
      if (mounted) {
        final confirmReplace = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: context.colors.surface,
            title: const Text('Confirm Reschedule'),
            content: Text('The old appointment on ${existingAppt.date} at ${TimeUtils.formatStringTime(existingAppt.time)} will be deleted and rescheduled to ${_formatDate(_selectedDate!)} at ${TimeUtils.formatStringTime(_selectedTimeStr!)}.\n\nProceed?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Replace'),
              ),
            ],
          ),
        );

        if (confirmReplace != true) {
          return; // Abort
        }

        // Delete the old appointment first
        setState(() => _isSubmitting = true);
        try {
          await ref.read(pocketbaseProvider).collection(PBCollections.appointments).delete(existingAppt.id);
        } catch (e) {
          if (mounted) {
            AppToast.show('Failed to delete old appointment: $e', type: ToastType.error);
          }
          setState(() => _isSubmitting = false);
          return;
        }
        setState(() => _isSubmitting = false);
      }
    }
    // --- End Duplicate Check ---

    setState(() => _isSubmitting = true);

    final notifier = ref.read(appointmentListProvider.notifier);
    final clinicId = auth.clinicId;

    bool success;
    if (_isCallBy) {
      final result = await notifier.createCallBy(
        doctorId: doctorId,
        clinicId: clinicId,
        patientName: _nameCtrl.text.trim(),
        patientPhone: _phoneCtrl.text.trim(),
        date: _formatDate(_selectedDate!),
        time: _selectedTimeStr!,
        existingPatientId: _existingPatient?.id,
        isNewFamilyMember: _isNewFamilyMember,
        intendedRelation: _isNewFamilyMember ? _selectedRelation : null,
      );
      success = result != null;
    } else {
      // For Walk-In, override the strict interval string and save as the exact submission time
      final now = DateTime.now();
      final exactTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      if (_forceWalkIn) {
        final pb = ref.read(pocketbaseProvider);
        final docRec = await pb.collection('doctors').getOne(doctorId);
        final doctor = DoctorModel.fromRecord(docRec);
        
        final schedService = SchedulingService(pb);
        final daySchedule = schedService.getScheduleForDay(doctor.workingSchedule, DateTime.now().weekday);
        if (daySchedule == null) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: context.colors.surface,
              title: Row(children: [
                Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 24),
                const SizedBox(width: 10),
                Text('No Working Schedule', style: context.textStyles.h4),
              ]),
              content: Text(
                'Doctor is not scheduled to work today. Do you still want to proceed?',
                style: context.textStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Cancel', style: TextStyle(color: context.colors.textHint)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.warning),
                  child: Text('Proceed Anyway', style: TextStyle(color: context.colors.textPrimary)),
                ),
              ],
            ),
          );
          if (proceed != true) {
            setState(() => _isSubmitting = false);
            return;
          }
        } else if (!schedService.isWithinWorkingHours(daySchedule, exactTimeStr)) {
          // Show confirmation dialog instead of hard-blocking
          final proceed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: context.colors.surface,
              title: Row(children: [
                Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 24),
                const SizedBox(width: 10),
                Text('Outside Working Hours', style: context.textStyles.h4),
              ]),
              content: Text(
                'The current time is outside the doctor\'s working hours.\nDo you still want to proceed with the walk-in?',
                style: context.textStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Cancel', style: TextStyle(color: context.colors.textHint)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.warning),
                  child: Text('Proceed Anyway', style: TextStyle(color: context.colors.textPrimary)),
                ),
              ],
            ),
          );
          if (proceed != true) {
            setState(() => _isSubmitting = false);
            return;
          }
        }

        _selectedDate = now;
        _selectedTimeStr = exactTimeStr;
      }

      // Auto-calculate age from DoB
      final dob = DateTime.tryParse(_dobCtrl.text);
      int? calculatedAge;
      if (dob != null) {
        final today = DateTime.now();
        calculatedAge = today.year - dob.year;
        if (today.month < dob.month ||
            (today.month == dob.month && today.day < dob.day)) {
          calculatedAge--;
        }
        if (calculatedAge < 0) calculatedAge = null;
      }

      final result = await notifier.createWalkIn(
        doctorId: doctorId,
        clinicId: clinicId,
        date: _formatDate(_selectedDate!),
        time: exactTimeStr,
        patientName: _nameCtrl.text.trim(),
        patientPhone: _phoneCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.isNotEmpty ? _dobCtrl.text : null,
        city: _cityCtrl.text.isNotEmpty ? _cityCtrl.text : null,
        area: _areaCtrl.text.isNotEmpty ? _areaCtrl.text : null,
        pincode: _pincodeCtrl.text.isNotEmpty ? _pincodeCtrl.text : null,
        gender: _selectedGender,
        occupation: _occupationCtrl.text.isNotEmpty ? _occupationCtrl.text : null,
        email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
        age: calculatedAge,
        existingPatientId: _existingPatient?.id,
        reference: _referenceCtrl.text.isNotEmpty ? _referenceCtrl.text : null,
        relationToPrimary: _isNewFamilyMember ? _selectedRelation : null,
        howDidYouHear: _howDidYouHear,
        photoPath: null,
        consentGiven: _dataConsentGiven,
        privacyPolicyAccepted: _privacyPolicyAccepted,
      );
      success = result != null;
    }

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      // Audit log for receptionist actions
      final auth = ref.read(authProvider);
      if (auth.role == UserRole.receptionist) {
        ref.read(auditServiceProvider).log(
          userId: auth.userId ?? '',
          userRole: 'receptionist',
          action: AuditAction.createAppointment,
          details: 'Created ${_isCallBy ? 'call-by' : 'walk-in'} for ${_nameCtrl.text.trim()}',
        );
      }
      AppToast.show('${_isCallBy ? 'Call-by' : 'Walk-in'} appointment created!', type: ToastType.success);
      navigator.pop();
    } else if (mounted) {
      // Show error from provider state
      final err = ref.read(appointmentListProvider).error;
      if (err != null) {
        AppToast.show(err, type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: ResponsiveWrapper(
          child: LayoutBuilder(
            builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final header = Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 20, color: context.colors.textPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Text('New Appointment', style: context.textStyles.h2),
              ],
            );

            final typeToggle = Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  _typeTab('Call-by', Icons.phone_rounded, _isCallBy, () {
                    setState(() {
                      _isCallBy = true;
                      _forceWalkIn = false;
                    });
                  }),
                  _typeTab('Walk-in', Icons.directions_walk_rounded,
                      !_isCallBy, () {
                    setState(() => _isCallBy = false);
                  }),
                ],
              ),
            );

            final forceWalkInToggle = !_isCallBy
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Force Immediate Walk-In', style: context.textStyles.bodyMedium),
                              Text('Overrides schedule, books exactly right now', style: context.textStyles.caption),
                            ],
                          ),
                        ),
                        Switch(
                          value: _forceWalkIn,
                          onChanged: (v) => setState(() => _forceWalkIn = v),
                          activeColor: context.colors.primary,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink();

            final descriptionBanner = Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_isCallBy ? context.colors.info : context.colors.accent)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCallBy
                        ? Icons.info_outline_rounded
                        : Icons.directions_walk_rounded,
                    color: _isCallBy ? context.colors.info : context.colors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isCallBy
                          ? 'Book a future slot — patient calls to schedule.'
                          : 'Patient walked in — select a slot and enter details.',
                      style: context.textStyles.caption.copyWith(
                        color: _isCallBy ? context.colors.info : context.colors.accent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );

            final showDoctor = isClinic && _doctors.isNotEmpty;

            final doctorSelector = showDoctor
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Doctor', style: context.textStyles.label),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDoctorId,
                            isExpanded: true,
                            hint: Text('Choose a doctor',
                                style: context.textStyles.bodyMedium
                                    .copyWith(color: context.colors.textHint)),
                            items: _doctors
                                .map((d) => DropdownMenuItem(
                                      value: d['id'],
                                      child: Text(d['name'] ?? '',
                                          style: context.textStyles.bodyMedium),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedDoctorId = v),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink();

            final slotPickerOrImmediate = !_forceWalkIn
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appointment Slot', style: context.textStyles.label),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickSlot,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _hasSlotSelected ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                                color: _hasSlotSelected ? context.colors.success : context.colors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _slotDisplayText,
                                  style: context.textStyles.bodyMedium.copyWith(
                                    color: _hasSlotSelected ? context.colors.textPrimary : context.colors.textHint,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: context.colors.textHint, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appointment Slot', style: context.textStyles.label),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.colors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.success.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.flash_on_rounded, color: context.colors.success, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              'Booking Immediately',
                              style: context.textStyles.bodyMedium.copyWith(
                                color: context.colors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Time: ${TimeUtils.formatStringTime(DateFormat("HH:mm").format(DateTime.now()))}',
                              style: context.textStyles.caption.copyWith(color: context.colors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

            final phoneField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Phone Number', style: context.textStyles.label),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: context.colors.divider,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPhoneCode,
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          items: Validators.countryPhoneCodes.keys.map((code) {
                            return DropdownMenuItem(
                              value: code,
                              child: Text(
                                ' $code',
                                style: context.textStyles.bodyLarge.copyWith(
                                  color: context.colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedPhoneCode = val;
                              });
                              _onPhoneChanged();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          AppTextField(
                            label: '',
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            validator: (v) => Validators.phone(v, countryCode: _selectedPhoneCode),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                Validators.countryPhoneCodes[_selectedPhoneCode] ?? 15,
                              ),
                            ],
                          ),
                          if (_isCheckingPhone)
                            const Positioned(
                              right: 14,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );

            final phoneSection = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                phoneField,
                if (_existingPatient != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.colors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: context.colors.success, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Returning Patient: ${_existingPatient!.fullName} '
                            '(${_existingPatient!.relationToPrimary ?? 'Self'}'
                            '${_existingPatient!.gender != null ? ' • ${_existingPatient!.gender}' : ''}'
                            '${_existingPatient!.age != null ? ' • ${_existingPatient!.age} yrs' : ''})',
                            style: context.textStyles.caption.copyWith(
                              color: context.colors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (_matchingPatients.length > 1) {
                              _checkPhone(_phoneCtrl.text.trim(), forceShowScreen: true);
                            } else if (_matchingPatients.isNotEmpty) {
                              _applyNewFamilyMemberMode(_matchingPatients.first);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              _matchingPatients.length > 1 ? 'Change' : '+ Add Family Member',
                              style: context.textStyles.caption.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_isNewFamilyMember) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.family_restroom_rounded, color: context.colors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Adding New Family Member under ${_phoneCtrl.text.trim()}',
                            style: context.textStyles.caption.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_matchingPatients.isNotEmpty)
                          InkWell(
                            onTap: () {
                              if (_matchingPatients.length > 1) {
                                _checkPhone(_phoneCtrl.text.trim(), forceShowScreen: true);
                              } else {
                                _applySelectedPatient(_matchingPatients.first);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Text(
                                _matchingPatients.length > 1
                                    ? 'Change'
                                    : 'Switch Back to ${_matchingPatients.first.fullName}',
                                style: context.textStyles.caption.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRelationDropdown(),
                ],
              ],
            );


            final nameField = AppTextField(
              controller: _nameCtrl,
              label: 'Patient Name',
              prefixIcon: Icon(Icons.person_outline_rounded, color: context.colors.textHint),
              validator: Validators.required,
              readOnly: _existingPatient != null,
            );


            final formContent = _buildFormContent(
              context: context,
              isDesktop: isDesktop,
              isClinic: isClinic,
              header: header,
              typeToggle: typeToggle,
              forceWalkInToggle: forceWalkInToggle,
              descriptionBanner: descriptionBanner,
              showDoctor: showDoctor,
              doctorSelector: doctorSelector,
              slotPickerOrImmediate: slotPickerOrImmediate,
              phoneSection: phoneSection,
              nameField: nameField,
            );

            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.textPrimary.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: formContent,
                    ),
                  ),
                ),
              );
            } else {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: formContent,
              );
            }
          },
        ),
        ),
      ),
    );
  }

  Widget _buildFormContent({
    required BuildContext context,
    required bool isDesktop,
    required bool isClinic,
    required Widget header,
    required Widget typeToggle,
    required Widget forceWalkInToggle,
    required Widget descriptionBanner,
    required bool showDoctor,
    required Widget doctorSelector,
    required Widget slotPickerOrImmediate,
    required Widget phoneSection,
    required Widget nameField,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 28),

          // Toggles row on desktop
          if (isDesktop && !_isCallBy) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: typeToggle),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: forceWalkInToggle),
              ],
            ),
          ] else ...[
            typeToggle,
            if (!_isCallBy) ...[
              const SizedBox(height: 24),
              forceWalkInToggle,
            ],
          ],
          const SizedBox(height: 24),

          descriptionBanner,
          const SizedBox(height: 24),

          // Doctor Selector & Slot Picker Grid on desktop
          if (isDesktop) ...[
            if (showDoctor) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: doctorSelector),
                  const SizedBox(width: 16),
                  Expanded(child: slotPickerOrImmediate),
                ],
              ),
            ] else ...[
              slotPickerOrImmediate,
            ],
          ] else ...[
            if (showDoctor) ...[
              doctorSelector,
              const SizedBox(height: 20),
            ],
            slotPickerOrImmediate,
          ],
          const SizedBox(height: 24),

          Text('Patient Info', style: context.textStyles.h3),
          const SizedBox(height: 4),
          Text(
            _isCallBy
                ? 'Quick placeholder — full details collected on arrival.'
                : 'Enter the walk-in patient\'s details.',
            style: context.textStyles.caption,
          ),
          const SizedBox(height: 14),

          // Call-by vs Walk-in Form content
          if (_isCallBy)
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: phoneSection),
                      const SizedBox(width: 16),
                      Expanded(child: nameField),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      phoneSection,
                      const SizedBox(height: 14),
                      nameField,
                    ],
                  )
          else
            PatientDetailsForm(
              nameCtrl: _nameCtrl,
              phoneCtrl: _phoneCtrl,
              dobCtrl: _dobCtrl,
              pincodeCtrl: _pincodeCtrl,
              countryCtrl: _countryCtrl,
              stateCtrl: _stateCtrl,
              cityCtrl: _cityCtrl,
              areaCtrl: _areaCtrl,
              occupationCtrl: _occupationCtrl,
              emailCtrl: _emailCtrl,
              referenceCtrl: _referenceCtrl,
              selectedGender: _selectedGender,
              onGenderChanged: (v) => setState(() => _selectedGender = v),
              consentGiven: _dataConsentGiven,
              onConsentChanged: (v) => setState(() => _dataConsentGiven = v),
              privacyPolicyAccepted: _privacyPolicyAccepted,
              onPrivacyPolicyChanged: (v) => setState(() => _privacyPolicyAccepted = v),

              howDidYouHear: _howDidYouHear,
              onHowDidYouHearChanged: (v) => setState(() => _howDidYouHear = v),
              isReturningPatient: _isRegisteredPatient,
              isCheckingPhone: _isCheckingPhone,
              nameLocked: _isRegisteredPatient,
              isNewFamilyMember: _isNewFamilyMember,
              relationToPrimary: _selectedRelation,
              onRelationChanged: (v) => setState(() => _selectedRelation = v),
              selectedPhoneCode: _selectedPhoneCode,
              onPhoneCodeChanged: (v) => setState(() => _selectedPhoneCode = v),
              existingPatient: _existingPatient,
              matchingPatients: _matchingPatients,
              onAddFamilyMember: _matchingPatients.isNotEmpty
                  ? () => _applyNewFamilyMemberMode(_matchingPatients.first)
                  : null,
              onChangeFamilyMember: () => _checkPhone('$_selectedPhoneCode${_phoneCtrl.text.trim()}', forceShowScreen: true),
            ),
          const SizedBox(height: 28),

          AppButton(
            label: _isCallBy ? 'Book Appointment' : 'Register',
            isLoading: _isSubmitting,
            icon: _isCallBy
                ? Icons.event_available_rounded
                : Icons.how_to_reg_rounded,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }


  Widget _typeTab(
      String label, IconData icon, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? context.colors.heroGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : context.colors.textHint),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textStyles.label.copyWith(
                  color: selected ? Colors.white : context.colors.textHint,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
