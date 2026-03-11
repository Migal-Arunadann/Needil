import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../providers/treatment_provider.dart';
import '../../auth/providers/auth_provider.dart';

class CreateTreatmentPlanScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String? consultationId;

  const CreateTreatmentPlanScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.consultationId,
  });

  @override
  ConsumerState<CreateTreatmentPlanScreen> createState() =>
      _CreateTreatmentPlanScreenState();
}

class _CreateTreatmentPlanScreenState
    extends ConsumerState<CreateTreatmentPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  String? _selectedTreatment;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  final _sessionsCtrl = TextEditingController(text: '6');
  final _intervalCtrl = TextEditingController(text: '3');
  final _feeCtrl = TextEditingController();

  @override
  void dispose() {
    _sessionsCtrl.dispose();
    _intervalCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  List<String> _getTreatmentTypes() {
    final auth = ref.read(authProvider);
    final doctor = auth.doctor;
    if (doctor != null && doctor.treatments.isNotEmpty) {
      return doctor.treatments.map((t) => t.type).toList();
    }
    return ['Acupuncture', 'Physiotherapy', 'Cupping', 'Massage', 'Other'];
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked != null) setState(() => _startDate = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _autoFillFee() {
    if (_selectedTreatment != null) {
      final auth = ref.read(authProvider);
      final doctor = auth.doctor;
      if (doctor != null) {
        final treatment = doctor.treatments.where((t) => t.type == _selectedTreatment).toList();
        if (treatment.isNotEmpty && _feeCtrl.text.isEmpty) {
          _feeCtrl.text = treatment.first.fee.toInt().toString();
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTreatment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a treatment type'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = ref.read(authProvider);
    final notifier = ref.read(treatmentPlansProvider.notifier);

    final plan = await notifier.createPlan(
      patientId: widget.patientId,
      doctorId: auth.userId!,
      consultationId: widget.consultationId,
      treatmentType: _selectedTreatment!,
      startDate: _formatDate(_startDate),
      totalSessions: int.parse(_sessionsCtrl.text.trim()),
      intervalDays: int.parse(_intervalCtrl.text.trim()),
      sessionFee: double.parse(_feeCtrl.text.trim()),
    );

    setState(() => _isSubmitting = false);

    if (plan != null && mounted) {
      final total = int.parse(_sessionsCtrl.text.trim());
      final interval = int.parse(_intervalCtrl.text.trim());
      final endDate = _startDate.add(Duration(days: (total - 1) * interval));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$total sessions created: ${DateFormat('MMM d').format(_startDate)} — ${DateFormat('MMM d, yyyy').format(endDate)}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final treatments = _getTreatmentTypes();
    final totalSessions = int.tryParse(_sessionsCtrl.text) ?? 0;
    final intervalDays = int.tryParse(_intervalCtrl.text) ?? 0;
    final fee = double.tryParse(_feeCtrl.text) ?? 0;
    final endDate = totalSessions > 0 && intervalDays > 0
        ? _startDate.add(Duration(days: (totalSessions - 1) * intervalDays))
        : _startDate;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Treatment Plan', style: AppTextStyles.h2),
                          Text(widget.patientName,
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Treatment type
                Text('Treatment Type', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: treatments.map((t) {
                    final selected = _selectedTreatment == t;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedTreatment = t);
                        _autoFillFee();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: selected ? AppColors.heroGradient : null,
                          color: selected ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: selected
                              ? null
                              : Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          t,
                          style: AppTextStyles.label.copyWith(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Start date
                Text('Start Date', style: AppTextStyles.label),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickStartDate,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEEE, MMM d, yyyy').format(_startDate),
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sessions & Interval
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _sessionsCtrl,
                        label: 'Total Sessions',
                        hint: '6',
                        keyboardType: TextInputType.number,
                        validator: Validators.required,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _intervalCtrl,
                        label: 'Interval (days)',
                        hint: '3',
                        keyboardType: TextInputType.number,
                        validator: Validators.required,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fee
                AppTextField(
                  controller: _feeCtrl,
                  label: 'Fee per Session (₹)',
                  hint: '500',
                  keyboardType: TextInputType.number,
                  validator: Validators.required,
                  prefixIcon: const Icon(Icons.currency_rupee_rounded,
                      color: AppColors.success, size: 18),
                ),
                const SizedBox(height: 20),

                // Preview box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.preview_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Plan Preview',
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _previewRow('Treatment', _selectedTreatment ?? '—'),
                      _previewRow('Sessions', '$totalSessions sessions'),
                      _previewRow('Schedule',
                          'Every $intervalDays days'),
                      _previewRow('Duration',
                          '${DateFormat('MMM d').format(_startDate)} — ${DateFormat('MMM d, yyyy').format(endDate)}'),
                      _previewRow(
                          'Total Cost', '₹${(fee * totalSessions).toInt()}'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                AppButton(
                  label: 'Create Plan & Generate Sessions',
                  isLoading: _isSubmitting,
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
