import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/time_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scheduling/screens/available_slots_screen.dart';
import '../providers/appointment_provider.dart';
import '../../../core/services/auth_service.dart';
import '../models/appointment_model.dart';

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
  final _dobCtrl = TextEditingController(); // Or Age
  final _ageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _selectedGender;

  // Slot selection
  DateTime? _selectedDate;
  String? _selectedTimeStr; // e.g. "09:00" — raw string from AvailableSlotsScreen
  DateTime? _callByDate;
  String? _selectedDoctorId;
  List<Map<String, String>> _doctors = [];

  @override
  void initState() {
    super.initState();
    _isCallBy = widget.initialIsCallBy;
    _loadDoctors();
    _phoneCtrl.addListener(_onPhoneChanged);
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
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    _allergiesCtrl.dispose();
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

    // 1. Check for existing patient record
    final existing = await service.findPatientByPhone(phone, doctorId);
    if (existing != null && mounted && _nameCtrl.text.isEmpty) {
      final fill = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.person_search_rounded, color: AppColors.info, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text('Patient Found')),
            ],
          ),
          content: Text('A patient record for "${existing.fullName}" already exists with this phone number.\n\nAuto-fill the details?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Auto-fill'),
            ),
          ],
        ),
      );

      if (fill == true && mounted) {
        setState(() {
          _nameCtrl.text = existing.fullName;
          if (existing.dateOfBirth != null && existing.dateOfBirth!.isNotEmpty) _dobCtrl.text = existing.dateOfBirth!;
          if (existing.address != null && existing.address!.isNotEmpty) _addressCtrl.text = existing.address!;
          if (existing.emergencyContact != null && existing.emergencyContact!.isNotEmpty) _emergencyCtrl.text = existing.emergencyContact!;
          if (existing.allergiesConditions != null && existing.allergiesConditions!.isNotEmpty) _allergiesCtrl.text = existing.allergiesConditions!;
          if (existing.occupation != null && existing.occupation!.isNotEmpty) _occupationCtrl.text = existing.occupation!;
          if (existing.email != null && existing.email!.isNotEmpty) _emailCtrl.text = existing.email!;
          if (existing.gender != null && existing.gender!.isNotEmpty) _selectedGender = existing.gender;
          if (existing.age != null) _ageCtrl.text = existing.age.toString();
        });
      }
    }

    // 2. Check for existing scheduled appointment (double-booking prevention)
    final existingAppt = await service.findExistingAppointment(phone, doctorId);
    if (existingAppt != null && mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text('Existing Appointment')),
            ],
          ),
          content: Text('This patient already has a scheduled appointment on ${existingAppt.date} at ${TimeUtils.formatStringTime(existingAppt.time)}.\n\nDo you want to replace it with a new one?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (replace == true) {
        // Cancel the old appointment
        ref.read(appointmentListProvider.notifier).updateStatus(existingAppt.id, AppointmentStatus.cancelled);
      } else if (replace == false && mounted) {
        // User chose not to replace — clear the phone field to start fresh
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Appointment already exists. Booking cancelled.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    if (mounted) setState(() => _isCheckingPhone = false);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickCallByDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _callByDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
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
        _callByDate = picked;
        // Reset selected slot since date changed
        _selectedDate = null;
        _selectedTimeStr = null;
      });
      // Automatically open slot picker for the new date
      _pickSlot();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickSlot() async {
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
          allowFutureDates: _isCallBy,
          initialDate: _isCallBy ? (_callByDate ?? DateTime.now()) : DateTime.now(),
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
        _selectedDate = now;
        _selectedTimeStr = exactTimeStr;
      }

      final result = await notifier.createWalkIn(
        doctorId: doctorId,
        clinicId: clinicId,
        date: _formatDate(_selectedDate!),
        time: exactTimeStr,
        patientName: _nameCtrl.text.trim(),
        patientPhone: _phoneCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.isNotEmpty ? _dobCtrl.text : null,
        address: _addressCtrl.text.isNotEmpty ? _addressCtrl.text : null,
        emergencyContact:
            _emergencyCtrl.text.isNotEmpty ? _emergencyCtrl.text : null,
        allergiesConditions:
            _allergiesCtrl.text.isNotEmpty ? _allergiesCtrl.text : null,
        gender: _selectedGender,
        occupation: _occupationCtrl.text.isNotEmpty ? _occupationCtrl.text : null,
        email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
        age: int.tryParse(_ageCtrl.text),
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
                        setState(() => _isCallBy = true);
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

                // Call-By Date Selection
                if (_isCallBy) ...[
                  Text('Appointment Date', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickCallByDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _callByDate == null 
                                ? 'Tap to pick a date from Calendar' 
                                : DateFormat('EEEE, MMM d, yyyy').format(_callByDate!),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _callByDate == null ? AppColors.textHint : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(Icons.edit_calendar_rounded, color: AppColors.textHint, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

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

                // Patient fields (both call-by and walk-in)
                Text('Patient Info', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  _isCallBy
                      ? 'Quick placeholder — full details collected on arrival.'
                      : 'Enter the walk-in patient\'s details.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _nameCtrl,
                  label: 'Patient Name',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.textHint),
                  validator: Validators.required,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _phoneCtrl,
                  label: 'Phone Number',
                  prefixIcon:
                      Icon(Icons.phone_outlined, color: AppColors.textHint),
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                
                if (!_isCallBy) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _ageCtrl,
                          label: 'Age',
                          prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.textHint),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AppTextField(
                          controller: _dobCtrl,
                          label: 'DOB (Optional)',
                          prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.textHint, size: 18),
                          readOnly: true,
                          onTap: _pickDob,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        hint: Text('Gender (Optional)', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                        items: ['Male', 'Female', 'Other']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g, style: AppTextStyles.bodyMedium)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedGender = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _addressCtrl,
                    label: 'Address (City / Area)',
                    prefixIcon: const Icon(Icons.home_outlined, color: AppColors.textHint),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _occupationCtrl,
                    label: 'Occupation (Optional)',
                    prefixIcon: const Icon(Icons.work_outline_rounded, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email (Optional)',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _emergencyCtrl,
                    label: 'Emergency Contact (Optional)',
                    prefixIcon: const Icon(Icons.medical_services_outlined, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _allergiesCtrl,
                    label: 'Allergies / Conditions (Optional)',
                    prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.textHint),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 28),

                // Submit
                AppButton(
                  label:
                      _isCallBy ? 'Book Appointment' : 'Start Walk-in Session',
                  isLoading: _isSubmitting,
                  icon: _isCallBy
                      ? Icons.event_available_rounded
                      : Icons.directions_walk_rounded,
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
