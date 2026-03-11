import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/time_utils.dart';
import '../../providers/auth_provider.dart';

/// Doctor Registration — multi‑step in a single screen with a PageView.
class DoctorRegistrationScreen extends ConsumerStatefulWidget {
  const DoctorRegistrationScreen({super.key});

  @override
  ConsumerState<DoctorRegistrationScreen> createState() =>
      _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState
    extends ConsumerState<DoctorRegistrationScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Step 1: Basic info
  final _step1Key = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _dateOfBirth;

  // Step 2: Working schedule
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
  final Map<String, TimeOfDay> _breakStartTimes = {};
  final Map<String, TimeOfDay> _breakEndTimes = {};

  // Step 3: Treatments
  final List<String> _availableTreatments = [
    'Acupuncture',
    'Acupressure',
    'Cupping Therapy',
    'Physiotherapy',
    'Foot Reflexology',
  ];
  final Map<String, bool> _selectedTreatments = {};
  final Map<String, TextEditingController> _durationControllers = {};
  final Map<String, TextEditingController> _feeControllers = {};

  // Step 4: Join clinic
  bool _joinClinic = false;
  final _clinicCodeController = TextEditingController();

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
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _clinicCodeController.dispose();
    for (final c in _durationControllers.values) {
      c.dispose();
    }
    for (final c in _feeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
  }

  void _nextPage() {
    // Validate current step
    if (_currentPage == 0) {
      if (!_step1Key.currentState!.validate()) return;
    } else if (_currentPage == 1) {
      final anySelected = _selectedDays.values.any((v) => v);
      if (!anySelected) {
        _showError('Please select at least one working day');
        return;
      }
      for (final entry in _selectedDays.entries) {
        if (entry.value &&
            (!_startTimes.containsKey(entry.key) ||
                !_endTimes.containsKey(entry.key))) {
          _showError('Please set start and end times for ${entry.key}');
          return;
        }
      }
    } else if (_currentPage == 2) {
      final anySelected = _selectedTreatments.values.any((v) => v);
      if (!anySelected) {
        _showError('Please select at least one treatment');
        return;
      }
    }
    _goToPage(_currentPage + 1);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectTime(String day, String type) async {
    TimeOfDay initial;
    switch (type) {
      case 'start':
        initial = _startTimes[day] ?? const TimeOfDay(hour: 9, minute: 0);
        break;
      case 'end':
        initial = _endTimes[day] ?? const TimeOfDay(hour: 17, minute: 0);
        break;
      case 'break_start':
        initial = _breakStartTimes[day] ?? const TimeOfDay(hour: 13, minute: 0);
        break;
      case 'break_end':
        initial = _breakEndTimes[day] ?? const TimeOfDay(hour: 14, minute: 0);
        break;
      default:
        initial = const TimeOfDay(hour: 9, minute: 0);
    }

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        switch (type) {
          case 'start':
            _startTimes[day] = picked;
            // Auto-fill other selected days that haven't been set yet
            for (final d in _selectedDays.entries) {
              if (d.value && !_startTimes.containsKey(d.key)) {
                _startTimes[d.key] = picked;
              }
            }
            break;
          case 'end':
            _endTimes[day] = picked;
            for (final d in _selectedDays.entries) {
              if (d.value && !_endTimes.containsKey(d.key)) {
                _endTimes[d.key] = picked;
              }
            }
            break;
          case 'break_start':
            _breakStartTimes[day] = picked;
            for (final d in _selectedDays.entries) {
              if (d.value && !_breakStartTimes.containsKey(d.key)) {
                _breakStartTimes[d.key] = picked;
              }
            }
            break;
          case 'break_end':
            _breakEndTimes[day] = picked;
            for (final d in _selectedDays.entries) {
              if (d.value && !_breakEndTimes.containsKey(d.key)) {
                _breakEndTimes[d.key] = picked;
              }
            }
            break;
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
    if (_dateOfBirth == null) {
      _showError('Please select your date of birth');
      return;
    }
    // Build schedule
    final schedule = _selectedDays.entries
        .where((e) => e.value)
        .map((e) => {
              'day': e.key,
              'start': _formatTime(_startTimes[e.key]),
              'end': _formatTime(_endTimes[e.key]),
              if (_breakStartTimes.containsKey(e.key))
                'break_start': _formatTime(_breakStartTimes[e.key]),
              if (_breakEndTimes.containsKey(e.key))
                'break_end': _formatTime(_breakEndTimes[e.key]),
            })
        .toList();

    final treatments = _selectedTreatments.entries
        .where((e) => e.value)
        .map((e) => {
              'type': e.key,
              'duration_min': int.tryParse(_durationControllers[e.key]!.text) ?? 30,
              'fee': double.tryParse(_feeControllers[e.key]!.text) ?? 500,
            })
        .toList();

    final dob =
        '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';

    await ref.read(authProvider.notifier).registerDoctor(
          name: _nameController.text.trim(),
          dateOfBirth: dob,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          workingSchedule: schedule,
          treatments: treatments,
          clinicCode: _joinClinic ? _clinicCodeController.text.trim() : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        _showError(next.error!);
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
          onPressed: () {
            if (_currentPage > 0) {
              _goToPage(_currentPage - 1);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text('Doctor Registration', style: AppTextStyles.h4),
        centerTitle: true,
      ),
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        message: 'Creating your account...',
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildStepIndicator(_currentPage + 1, 4),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                    _buildStep4(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 1: Basic Info ---
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Details', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Enter your basic information',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Full Name',
              hint: 'e.g. Dr. Priya Sharma',
              controller: _nameController,
              validator: (v) => Validators.required(v, 'Name'),
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            // Date of Birth picker
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ??
                      DateTime.now().subtract(const Duration(days: 365 * 30)),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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
                if (picked != null) setState(() => _dateOfBirth = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: AppColors.textHint, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dateOfBirth == null
                            ? 'Date of Birth'
                            : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _dateOfBirth == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Username',
              hint: 'Choose a unique username',
              controller: _usernameController,
              validator: (v) => Validators.minLength(v, 3, 'Username'),
              prefixIcon: const Icon(Icons.alternate_email_rounded,
                  color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password',
              hint: 'Min. 8 characters',
              controller: _passwordController,
              obscureText: true,
              validator: Validators.password,
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              controller: _confirmPasswordController,
              obscureText: true,
              validator: (v) =>
                  Validators.confirmPassword(v, _passwordController.text),
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.textHint),
            ),
            const SizedBox(height: 32),
            AppButton(
                label: 'Next',
                onPressed: _nextPage,
                icon: Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Working Schedule ---
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Working Schedule', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Set your working days and hours',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ..._selectedDays.entries.map((entry) {
            final day = entry.key;
            final selected = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (v) =>
                            setState(() => _selectedDays[day] = v ?? false),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      Expanded(
                        child: Text(day, style: AppTextStyles.label),
                      ),
                    ],
                  ),
                  if (selected) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        const Text('Work: '),
                        _timeChip(day, 'start'),
                        const Text(' – '),
                        _timeChip(day, 'end'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        Text('Break: ',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                        _timeChip(day, 'break_start'),
                        const Text(' – '),
                        _timeChip(day, 'break_end'),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          AppButton(
              label: 'Next',
              onPressed: _nextPage,
              icon: Icons.arrow_forward_rounded),
        ],
      ),
    );
  }

  Widget _timeChip(String day, String type) {
    TimeOfDay? time;
    switch (type) {
      case 'start':
        time = _startTimes[day];
        break;
      case 'end':
        time = _endTimes[day];
        break;
      case 'break_start':
        time = _breakStartTimes[day];
        break;
      case 'break_end':
        time = _breakEndTimes[day];
        break;
    }

    return GestureDetector(
      onTap: () => _selectTime(day, type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          time == null ? 'Set' : TimeUtils.formatTimeOfDay(time),
          style: AppTextStyles.bodySmall.copyWith(
            color: time != null ? AppColors.textPrimary : AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // --- Step 3: Treatments ---
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Treatments', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Select the treatments you offer and set defaults',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ..._availableTreatments.map((treatment) {
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
                        onChanged: (v) => setState(() =>
                            _selectedTreatments[treatment] = v ?? false),
                        activeColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      Expanded(
                        child:
                            Text(treatment, style: AppTextStyles.label),
                      ),
                    ],
                  ),
                  if (selected) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _miniField('Duration (min)',
                                _durationControllers[treatment]!),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniField(
                                'Fee (₹)', _feeControllers[treatment]!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          AppButton(
              label: 'Next',
              onPressed: _nextPage,
              icon: Icons.arrow_forward_rounded),
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

  // --- Step 4: Join Clinic ---
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Join a Clinic?', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'You can join a clinic now or practice individually',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),

          // Option cards
          _buildOptionCard(
            icon: Icons.person_rounded,
            title: 'Practice Individually',
            description: 'Start your independent practice',
            selected: !_joinClinic,
            onTap: () => setState(() => _joinClinic = false),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.business_rounded,
            title: 'Join a Clinic',
            description: 'Enter a clinic ID to join an existing clinic',
            selected: _joinClinic,
            onTap: () => setState(() => _joinClinic = true),
          ),

          if (_joinClinic) ...[
            const SizedBox(height: 24),
            AppTextField(
              label: 'Clinic ID',
              hint: 'Enter the 6-character clinic code',
              controller: _clinicCodeController,
              validator: (v) => Validators.required(v, 'Clinic ID'),
              prefixIcon: const Icon(Icons.vpn_key_outlined,
                  color: AppColors.textHint),
            ),
          ],

          const SizedBox(height: 40),
          AppButton(
            label: 'Create Account',
            onPressed: _submit,
            icon: Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label),
                  const SizedBox(height: 2),
                  Text(description, style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
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
      ),
    );
  }
}
