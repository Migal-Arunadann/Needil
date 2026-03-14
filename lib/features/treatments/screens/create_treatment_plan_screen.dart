import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/models/doctor_model.dart';
import '../providers/treatment_provider.dart';

class CreateTreatmentPlanScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String? consultationId;

  const CreateTreatmentPlanScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    this.consultationId,
  });

  @override
  ConsumerState<CreateTreatmentPlanScreen> createState() => _CreateTreatmentPlanScreenState();
}

class _CreateTreatmentPlanScreenState extends ConsumerState<CreateTreatmentPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  TreatmentConfig? _selectedTreatment;
  DateTime _startDate = DateTime.now();
  TimeOfDay _preferredTime = const TimeOfDay(hour: 10, minute: 0);
  
  final _sessionsCtrl = TextEditingController(text: '5');
  final _intervalCtrl = TextEditingController(text: '1');
  final _feeCtrl = TextEditingController();

  List<TreatmentConfig> _doctorTreatments = [];
  List<int> _doctorWorkingDays = [];
  bool _isLoadingTreatments = true;

  @override
  void initState() {
    super.initState();
    _loadTreatments();
  }

  Future<void> _loadTreatments() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      // Can't use PBCollections if we didn't import it, let's use string 'doctors'
      final record = await pb.collection('doctors').getOne(widget.doctorId);
      final doc = DoctorModel.fromRecord(record);
      if (mounted) {
        setState(() {
          _doctorTreatments = doc.treatments;
          _doctorWorkingDays = doc.workingDays;
          _isLoadingTreatments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTreatments = false);
      }
    }
  }

  @override
  void dispose() {
    _sessionsCtrl.dispose();
    _intervalCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      selectableDayPredicate: (day) {
        if (_doctorWorkingDays.isEmpty) return true; // Fallback
        return _doctorWorkingDays.contains(day.weekday);
      },
    );
    if (d != null) {
      setState(() => _startDate = d);
    }
  }

  Future<void> _pickPreferredTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _preferredTime,
    );
    if (t != null) {
      setState(() => _preferredTime = t);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTreatment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a treatment type'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(treatmentServiceProvider);
      
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final hr = _preferredTime.hour.toString().padLeft(2, "0");
      final mn = _preferredTime.minute.toString().padLeft(2, "0");
      final preferredTimeStr = '$hr:$mn';
      
      // Auto-schedule sessions considering clinic beds
      final numSessions = int.tryParse(_sessionsCtrl.text.trim()) ?? 5;
      final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
      final feeStr = _feeCtrl.text.trim();
      final fee = feeStr.isEmpty ? 0.0 : (double.tryParse(feeStr) ?? 0.0);

      await service.createSmartTreatmentPlan(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        consultationId: widget.consultationId,
        treatmentType: _selectedTreatment!.type,
        startDate: startDateStr,
        preferredTime: preferredTimeStr,
        totalSessions: numSessions,
        intervalDays: interval,
        sessionFee: fee,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Treatment Plan & Sessions Auto-Scheduled!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule plan: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {

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
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Session Planning', style: AppTextStyles.h2),
                          Text('For \${widget.patientName}', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Treatment Selection
                Text('Treatment Type', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TreatmentConfig>(
                      isExpanded: true,
                      value: _selectedTreatment,
                      hint: Text(_isLoadingTreatments ? 'Loading treatments...' : 'Select Treatment', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                      items: _doctorTreatments.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.type, style: AppTextStyles.bodyMedium),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTreatment = val;
                          if (val != null) {
                            _feeCtrl.text = val.fee.toString();
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sessions & Interval
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _sessionsCtrl,
                        label: 'Total Sessions',
                        hint: '10',
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        controller: _intervalCtrl,
                        label: 'Interval (Days)',
                        hint: 'Every X days',
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Fee
                AppTextField(
                  controller: _feeCtrl,
                  label: 'Session Fee (₹)',
                  hint: '500',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18, color: AppColors.success),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 32),

                // Start Date & Preferred Time
                Text('Scheduling Preferences', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickStartDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(DateFormat('MMM d, yyyy').format(_startDate), style: AppTextStyles.bodyMedium),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickPreferredTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Preferred Slot', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(_preferredTime.format(context), style: AppTextStyles.bodyMedium),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    '💡 Note: The smart scheduling engine will book sessions sequentially. If a time slot is fully occupied (all beds taken), it will find the closest next available slot.',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 36),

                // Submit
                AppButton(
                  label: 'Generate Treatment Plan',
                  isLoading: _isSubmitting,
                  icon: Icons.auto_awesome_mosaic_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
