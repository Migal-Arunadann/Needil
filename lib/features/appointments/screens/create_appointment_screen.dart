import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/patient_details_form.dart';
import '../../../core/utils/time_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/doctor_model.dart';
import '../../../core/services/scheduling_service.dart';
import '../../scheduling/screens/available_slots_screen.dart';
import '../providers/appointment_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../patients/models/patient_model.dart';

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
  String? _selectedGender;

  // Slot selection
  DateTime? _selectedDate;
  String? _selectedTimeStr; // e.g. "09:00" — raw string from AvailableSlotsScreen
  String? _selectedDoctorId;
  List<Map<String, String>> _doctors = [];

  // Phone lookup state
  PatientModel? _existingPatient; // non-null if phone matched a patient record
  bool _isRegisteredPatient = false; // true when walk-in phone matches existing

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
    super.dispose();
  }

  void _onPhoneChanged() {
    _phoneDebounce?.cancel();
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) return;
    _phoneDebounce = Timer(const Duration(milliseconds: 600), () => _checkPhone(phone));
  }

  Future<void> _checkPhone(String phone) async {
    if (_isCheckingPhone) return;
    setState(() => _isCheckingPhone = true);

    final auth = ref.read(authProvider);
    final doctorId = _selectedDoctorId ?? auth.userId;
    if (doctorId == null) {
      setState(() => _isCheckingPhone = false);
      return;
    }

    final service = ref.read(appointmentServiceProvider);
    final existing = await service.findPatientByPhone(
      phone, 
      doctorId, 
      clinicId: auth.clinicId,
    );

    if (mounted) {
      setState(() {
        _existingPatient = existing;
        _isRegisteredPatient = !_isCallBy && existing != null;
      });

      if (existing != null) {
        // Always silently auto-fill shared fields
        _nameCtrl.text = existing.fullName;
        if (existing.dateOfBirth != null && existing.dateOfBirth!.isNotEmpty) _dobCtrl.text = existing.dateOfBirth!;
        if (existing.city != null && existing.city!.isNotEmpty) _cityCtrl.text = existing.city!;
        if (existing.area != null && existing.area!.isNotEmpty) _areaCtrl.text = existing.area!;
        if (existing.occupation != null && existing.occupation!.isNotEmpty) _occupationCtrl.text = existing.occupation!;
        if (existing.email != null && existing.email!.isNotEmpty) _emailCtrl.text = existing.email!;
        if (existing.gender != null && existing.gender!.isNotEmpty) _selectedGender = existing.gender;
      }
    }

    if (mounted) setState(() => _isCheckingPhone = false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor first')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: doctorId,
          clinicId: isClinic ? auth.userId : auth.clinic?.id,
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

    // Gender is mandatory for walk-in
    if (!_isCallBy && _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select the patient\'s gender'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!_hasSlotSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a time slot first'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    final auth = ref.read(authProvider);
    final doctorId = _selectedDoctorId ?? auth.userId;
    if (doctorId == null) return;

    // --- Duplicate Appointment Check (same-date scheduled) ---
    final service = ref.read(appointmentServiceProvider);
    final phone = _phoneCtrl.text.trim();
    final checkDate = _formatDate(_selectedDate ?? DateTime.now());

    // For walk-ins: block if same phone already has any active appointment today (prevents
    // dual registration of the same patient under a different name).
    if (!_isCallBy) {
      final todayDuplicate = await service.findAnyActiveTodayByPhone(phone, doctorId);
      if (todayDuplicate != null && mounted) {
        final existingName = todayDuplicate.displayName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This phone number is already registered today as "$existingName". '
              'A patient can only have one consultation per day. '
              'Please find the existing appointment in the schedule.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    final existingAppt = await service.findExistingAppointment(phone, doctorId, date: checkDate);
    if (existingAppt != null && mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
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
            backgroundColor: AppColors.surface,
            title: const Text('Confirm Reschedule'),
            content: Text('The old appointment on ${existingAppt.date} at ${TimeUtils.formatStringTime(existingAppt.time)} will be deleted and rescheduled to ${_formatDate(_selectedDate!)} at ${TimeUtils.formatStringTime(_selectedTimeStr!)}.\n\nProceed?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete old appointment: $e'), backgroundColor: AppColors.error));
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
    final clinicId =
        auth.role == UserRole.clinic ? auth.userId : auth.clinic?.id;

    bool success;
    if (_isCallBy) {
      final result = await notifier.createCallBy(
        doctorId: doctorId,
        clinicId: clinicId,
        patientName: _nameCtrl.text.trim(),
        patientPhone: _phoneCtrl.text.trim(),
        date: _formatDate(_selectedDate!),
        time: _selectedTimeStr!,
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
          setState(() => _isSubmitting = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor is not scheduled to work today.'), backgroundColor: AppColors.error));
          }
          return;
        }
        
        if (!schedService.isWithinWorkingHours(daySchedule, exactTimeStr)) {
          setState(() => _isSubmitting = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Walk-in appointments can only be created during doctor\'s working hours.'), backgroundColor: AppColors.error));
          }
          return;
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
      );
      success = result != null;
    }

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${_isCallBy ? 'Call-by' : 'Walk-in'} appointment created!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      // Show error from provider state
      final err = ref.read(appointmentListProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('New Appointment', style: AppTextStyles.h2),
                  ],
                ),
                const SizedBox(height: 28),

                // Type toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
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
                ),
                const SizedBox(height: 24),

                // Description
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_isCallBy ? AppColors.info : AppColors.accent)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCallBy
                            ? Icons.info_outline_rounded
                            : Icons.directions_walk_rounded,
                        color: _isCallBy ? AppColors.info : AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isCallBy
                              ? 'Book a future slot — patient calls to schedule.'
                              : 'Patient walked in — select a slot and enter details.',
                          style: AppTextStyles.caption.copyWith(
                            color:
                                _isCallBy ? AppColors.info : AppColors.accent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (!_isCallBy) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Force Immediate Walk-In', style: AppTextStyles.bodyMedium),
                              Text('Overrides schedule, books exactly right now', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Switch(
                          value: _forceWalkIn,
                          onChanged: (v) => setState(() => _forceWalkIn = v),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Doctor selector (clinic only)
                if (isClinic && _doctors.isNotEmpty) ...[
                  Text('Select Doctor', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDoctorId,
                        isExpanded: true,
                        hint: Text('Choose a doctor',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textHint)),
                        items: _doctors
                            .map((d) => DropdownMenuItem(
                                  value: d['id'],
                                  child: Text('Dr. ${d['name']}',
                                      style: AppTextStyles.bodyMedium),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedDoctorId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Call-by: slot picker directly (no separate date field)
                // Walk-in: slot picker (today only) or Force Walk-In
                // Date & Time (Unified Slot Picker)
                if (!_forceWalkIn) ...[
                  Text('Appointment Slot', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickSlot,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasSlotSelected ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                            color: _hasSlotSelected ? AppColors.success : AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _slotDisplayText,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _hasSlotSelected ? AppColors.textPrimary : AppColors.textHint,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.flash_on_rounded, color: AppColors.success, size: 28),
                        const SizedBox(height: 8),
                        Text('Booking Immediately', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                        Text('Time: ${TimeUtils.formatStringTime(DateFormat("HH:mm").format(DateTime.now()))}', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Text('Patient Info', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  _isCallBy
                      ? 'Quick placeholder — full details collected on arrival.'
                      : 'Enter the walk-in patient\'s details.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 14),

                // ── Call-by: quick phone + name only ─────────────────────
                if (_isCallBy) ...[
                  Stack(
                    children: [
                      AppTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        prefixIcon:
                            const Icon(Icons.phone_outlined, color: AppColors.textHint),
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          ),
                        ),
                    ],
                  ),
                  if (_existingPatient != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Returning patient — name auto-filled.',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Patient Name',
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.textHint),
                    validator: Validators.required,
                    readOnly: _existingPatient != null,
                  ),
                ],

               
                if (!_isCallBy) ...[
                  const SizedBox(height: 14),
                  // ── Shared Common Patient Details Form ───────────────────
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
                    selectedGender: _selectedGender,
                    onGenderChanged: (v) => setState(() => _selectedGender = v),
                    consentGiven: false,
                    onConsentChanged: (_) {},
                    isReturningPatient: _isRegisteredPatient,
                    isCheckingPhone: _isCheckingPhone,
                    nameLocked: _isRegisteredPatient,
                  ),
                ],
                const SizedBox(height: 28),

                // Submit
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
          ),
        ),
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
            gradient: selected ? AppColors.heroGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textHint),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: selected ? Colors.white : AppColors.textHint,
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
