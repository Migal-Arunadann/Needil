import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scheduling/screens/available_slots_screen.dart';
import '../providers/appointment_provider.dart';
import '../../../core/services/auth_service.dart';

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
  bool _isSubmitting = false;

  // Call-by fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Shared fields
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedDoctorId;
  List<Map<String, String>> _doctors = [];

  @override
  void initState() {
    super.initState();
    _isCallBy = widget.initialIsCallBy;
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    final auth = ref.read(authProvider);
    if (auth.role == UserRole.clinic && auth.userId != null) {
      final service = ref.read(appointmentServiceProvider);
      final docs = await service.getClinicDoctors(auth.userId!);
      setState(() => _doctors = docs);
    } else {
      // Doctor role — only themselves
      setState(() {
        _selectedDoctorId = auth.userId;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
          treatmentDuration: 30, // Default duration, will sync with DB later
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedDate = result['date'] as DateTime;
        _selectedTime = result['time'] as TimeOfDay;
      });
    }
  }

  Future<void> _submit() async {
    if (_isCallBy && !_formKey.currentState!.validate()) return;

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
        date: _formatDate(_selectedDate),
        time: _formatTime(_selectedTime),
      );
      success = result != null;
    } else {
      final result = await notifier.createWalkIn(
        doctorId: doctorId,
        clinicId: clinicId,
        date: _formatDate(_selectedDate),
        time: _formatTime(_selectedTime),
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
                            : 'Patient walked in — assign current time.',
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

              // Date & Time (Unified Slot Picker)
              Row(
                children: [
                  Expanded(
                    child: _dateTimeTile(
                      label: 'Selected Slot',
                      value: '${DateFormat('MMM d').format(_selectedDate)} at ${_selectedTime.format(context)}',
                      icon: Icons.access_time_rounded,
                      onTap: _pickSlot,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Call-by form
              if (_isCallBy) ...[
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient Info', style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      Text(
                          'Quick placeholder — full details collected on arrival.',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Patient Name',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                        validator: Validators.required,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textHint),
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

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

  Widget _dateTimeTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
