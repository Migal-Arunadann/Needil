import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

/// Clinic Registration — Step 3: Primary Doctor details.
class ClinicStep3Screen extends ConsumerStatefulWidget {
  final Map<String, dynamic> clinicData;

  const ClinicStep3Screen({super.key, required this.clinicData});

  @override
  ConsumerState<ClinicStep3Screen> createState() => _ClinicStep3ScreenState();
}

class _ClinicStep3ScreenState extends ConsumerState<ClinicStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorNameController = TextEditingController();
  final _doctorAgeController = TextEditingController();
  final _doctorUsernameController = TextEditingController();
  final _doctorPasswordController = TextEditingController();

  // Working schedule
  final Map<String, bool> _selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  final Map<String, TimeOfDay> _startTimes = {};
  final Map<String, TimeOfDay> _endTimes = {};

  // Treatments
  final List<String> _availableTreatments = [
    'Acupuncture',
    'Acupressure',
    'Cupping Therapy',
    'Physiotherapy',
  ];
  final Map<String, bool> _selectedTreatments = {};
  final Map<String, TextEditingController> _durationControllers = {};
  final Map<String, TextEditingController> _feeControllers = {};

  @override
  void initState() {
    super.initState();
    for (final t in _availableTreatments) {
      _selectedTreatments[t] = false;
      _durationControllers[t] = TextEditingController(text: '30');
      _feeControllers[t] = TextEditingController(text: '500');
    }
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _doctorAgeController.dispose();
    _doctorUsernameController.dispose();
    _doctorPasswordController.dispose();
    for (final c in _durationControllers.values) {
      c.dispose();
    }
    for (final c in _feeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectTime(String day, bool isStart) async {
    final initial = isStart
        ? (_startTimes[day] ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTimes[day] ?? const TimeOfDay(hour: 17, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTimes[day] = picked;
        } else {
          _endTimes[day] = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Set';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one working day
    final selectedDays =
        _selectedDays.entries.where((e) => e.value).toList();
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one working day'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate times for selected days
    for (final day in selectedDays) {
      if (!_startTimes.containsKey(day.key) ||
          !_endTimes.containsKey(day.key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Please set start and end times for ${day.key}'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Validate at least one treatment
    final selectedTreatments =
        _selectedTreatments.entries.where((e) => e.value).toList();
    if (selectedTreatments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one treatment'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Build schedule
    final schedule = selectedDays.map((day) {
      return {
        'day': day.key,
        'start': _formatTime(_startTimes[day.key]),
        'end': _formatTime(_endTimes[day.key]),
      };
    }).toList();

    // Build treatments
    final treatments = selectedTreatments.map((t) {
      return {
        'type': t.key,
        'duration_min':
            int.tryParse(_durationControllers[t.key]!.text) ?? 30,
        'fee': double.tryParse(_feeControllers[t.key]!.text) ?? 500,
      };
    }).toList();

    // Build primary doctor data
    final primaryDoctorData = {
      'name': _doctorNameController.text.trim(),
      'age': int.tryParse(_doctorAgeController.text.trim()) ?? 0,
      'username': _doctorUsernameController.text.trim(),
      'password': _doctorPasswordController.text,
      'working_schedule': schedule,
      'treatments': treatments,
    };

    await ref.read(authProvider.notifier).registerClinic(
          clinicName: widget.clinicData['clinic_name'],
          username: widget.clinicData['username'],
          password: widget.clinicData['password'],
          bedCount: widget.clinicData['bed_count'],
          primaryDoctorData: primaryDoctorData,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
      if (next.isAuthenticated) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Clinic Registration', style: AppTextStyles.h4),
        centerTitle: true,
      ),
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        message: 'Creating your clinic...',
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildStepIndicator(3, 3),
                  const SizedBox(height: 24),
                  Text('Primary Doctor', style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  Text(
                    'Set up the primary doctor for your clinic',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Doctor basic info
                  AppTextField(
                    label: 'Doctor Name',
                    hint: 'e.g. Dr. Sharma',
                    controller: _doctorNameController,
                    validator: (v) => Validators.required(v, 'Name'),
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.textHint),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Age',
                    hint: 'e.g. 35',
                    controller: _doctorAgeController,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        Validators.positiveNumber(v, 'Age'),
                    prefixIcon: const Icon(Icons.cake_outlined,
                        color: AppColors.textHint),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Doctor Username',
                    hint: 'Login username for doctor',
                    controller: _doctorUsernameController,
                    validator: (v) =>
                        Validators.minLength(v, 3, 'Username'),
                    prefixIcon: const Icon(Icons.alternate_email_rounded,
                        color: AppColors.textHint),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Doctor Password',
                    hint: 'Min. 8 characters',
                    controller: _doctorPasswordController,
                    obscureText: true,
                    validator: Validators.password,
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.textHint),
                  ),
                  const SizedBox(height: 28),

                  // Working Schedule
                  Text('Working Schedule', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  ..._selectedDays.entries.map((entry) {
                    return _buildDayRow(entry.key, entry.value);
                  }),
                  const SizedBox(height: 28),

                  // Treatments
                  Text('Treatments Offered', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  ..._availableTreatments.map((t) {
                    return _buildTreatmentTile(t);
                  }),
                  const SizedBox(height: 32),

                  AppButton(
                    label: 'Create Clinic',
                    onPressed: _submit,
                    isLoading: authState.isLoading,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayRow(String day, bool selected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) =>
                setState(() => _selectedDays[day] = v ?? false),
            activeColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Text(day, style: AppTextStyles.label),
          ),
          if (selected) ...[
            _timeButton(day, true),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('–'),
            ),
            _timeButton(day, false),
          ],
        ],
      ),
    );
  }

  Widget _timeButton(String day, bool isStart) {
    final time = isStart ? _startTimes[day] : _endTimes[day];
    return GestureDetector(
      onTap: () => _selectTime(day, isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _formatTime(time),
          style: AppTextStyles.bodySmall.copyWith(
            color: time != null ? AppColors.textPrimary : AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentTile(String treatment) {
    final selected = _selectedTreatments[treatment] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => setState(
                    () => _selectedTreatments[treatment] = v ?? false),
                activeColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Text(treatment, style: AppTextStyles.label),
              ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniField(
                    'Duration (min)',
                    _durationControllers[treatment]!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniField(
                    'Fee (₹)',
                    _feeControllers[treatment]!,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        final isActive = step <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: step < total ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
