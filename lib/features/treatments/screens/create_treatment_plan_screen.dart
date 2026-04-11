import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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
  String _preferredTimeStr = '10:00'; // stored as HH:mm to match slot format
  bool _firstSessionCompletedToday = true;
  List<WorkingSchedule> _doctorSchedules = [];
  int get _slotDurationMinutes =>
      _selectedTreatment?.durationMinutes ?? 30;
  
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
          _doctorSchedules = doc.workingSchedule;
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
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      selectableDayPredicate: (day) {
        if (_doctorWorkingDays.isEmpty) return true;
        return _doctorWorkingDays.contains(day.weekday);
      },
    );
    if (d != null) {
      setState(() => _startDate = d);
    }
  }

  /// Generate slot strings ("HH:mm") from the doctor's schedule matching
  /// the selected start date, using the treatment duration as interval.
  List<String> _generateSlots() {
    if (_doctorSchedules.isEmpty) return [];

    // Convert weekday int to day name (DateTime.weekday: 1=Mon … 7=Sun)
    const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'];
    final selectedDayName = dayNames[_startDate.weekday];

    // Find schedule for the selected day, fall back to first available
    WorkingSchedule? daySchedule;
    for (final s in _doctorSchedules) {
      if (s.day == selectedDayName) { daySchedule = s; break; }
    }
    daySchedule ??= _doctorSchedules.first;

    final duration = _selectedTreatment?.durationMinutes ?? _slotDurationMinutes;
    final slots = <String>[];

    TimeOfDay parseTime(String t) {
      final parts = t.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    var current = parseTime(daySchedule.startTime);
    final end = parseTime(daySchedule.endTime);

    final breakStart = daySchedule.breakStart != null
        ? parseTime(daySchedule.breakStart!)
        : null;
    final breakEnd = daySchedule.breakEnd != null
        ? parseTime(daySchedule.breakEnd!)
        : null;

    int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    while (toMinutes(current) + duration <= toMinutes(end)) {
      final cMin = toMinutes(current);
      final isDuringBreak = breakStart != null &&
          breakEnd != null &&
          cMin >= toMinutes(breakStart) &&
          cMin < toMinutes(breakEnd);

      if (!isDuringBreak) slots.add(fmt(current));

      final nextMin = cMin + duration;
      current = TimeOfDay(hour: nextMin ~/ 60, minute: nextMin % 60);
    }
    return slots;
  }

  void _showSlotPicker() {
    FocusScope.of(context).unfocus();
    final slots = _generateSlots();

    if (slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No slots available — ensure a treatment is selected and doctor has a schedule'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SlotPickerSheet(
        slots: slots,
        selectedSlot: _preferredTimeStr,
        onSelected: (slot) {
          setState(() => _preferredTimeStr = slot);
          Navigator.pop(ctx);
        },
      ),
    );
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
      final preferredTimeStr = _preferredTimeStr;
      
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
        firstSessionCompletedToday: _firstSessionCompletedToday,
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
                        onTap: _showSlotPicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _preferredTimeStr.isNotEmpty
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Preferred Slot', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _preferredTimeStr.isEmpty
                                        ? 'Pick a slot'
                                        : _formatSlot(_preferredTimeStr),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: _preferredTimeStr.isEmpty
                                          ? AppColors.textHint
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start the 1st session today itself?', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Creates Session 1 today and schedules the remaining sessions', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Switch(
                        value: _firstSessionCompletedToday,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _firstSessionCompletedToday = val),
                      ),
                    ],
                  ),
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

  String _formatSlot(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mStr = m.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }
}

// ── Slot Picker Bottom Sheet ────────────────────────────────────────────────
class _SlotPickerSheet extends StatelessWidget {
  final List<String> slots;
  final String selectedSlot;
  final void Function(String) onSelected;

  const _SlotPickerSheet({
    required this.slots,
    required this.selectedSlot,
    required this.onSelected,
  });

  String _fmt(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Choose a Preferred Slot',
              style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            'Based on doctor\'s schedule & treatment duration',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Slot grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: slots.length,
            itemBuilder: (context, i) {
              final s = slots[i];
              final isSelected = s == selectedSlot;
              return GestureDetector(
                onTap: () => onSelected(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                      width: isSelected ? 0 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _fmt(s),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
