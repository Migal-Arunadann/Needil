import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/scheduling_service.dart';
import '../providers/scheduling_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/doctor_model.dart';

class AvailableSlotsScreen extends ConsumerStatefulWidget {
  final String? doctorId;
  final List<WorkingSchedule>? schedules;

  const AvailableSlotsScreen({
    super.key,
    this.doctorId,
    this.schedules,
  });

  @override
  ConsumerState<AvailableSlotsScreen> createState() =>
      _AvailableSlotsScreenState();
}

class _AvailableSlotsScreenState extends ConsumerState<AvailableSlotsScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  int _slotDuration = 30;

  String get _doctorId {
    return widget.doctorId ?? ref.read(authProvider).userId ?? '';
  }

  List<WorkingSchedule> get _schedules {
    return widget.schedules ??
        ref.read(authProvider).doctor?.workingSchedule ??
        [];
  }

  @override
  void initState() {
    super.initState();
    // Auto-fill slot duration from first treatment config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.doctor != null && auth.doctor!.treatments.isNotEmpty) {
        _slotDuration = auth.doctor!.treatments.first.durationMinutes;
      }
      _loadSlots();
    });
  }

  void _loadSlots() {
    ref.read(availableSlotsProvider.notifier).loadSlots(
          doctorId: _doctorId,
          date: _selectedDate,
          schedules: _schedules,
          slotDurationMinutes: _slotDuration,
        );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
        _selectedDate = picked;
        _selectedSlot = null;
      });
      _loadSlots();
    }
  }

  void _goNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _selectedSlot = null;
    });
    _loadSlots();
  }

  void _goPrevDay() {
    final prev = _selectedDate.subtract(const Duration(days: 1));
    if (prev.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
      setState(() {
        _selectedDate = prev;
        _selectedSlot = null;
      });
      _loadSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availableSlotsProvider);
    final service = ref.read(schedulingServiceProvider);
    final daySchedule = service
        .getScheduleForDay(_schedules, _selectedDate.weekday);
    final isWorkingDay = daySchedule != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
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
                    child: Text('Available Slots', style: AppTextStyles.h2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Date navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _navButton(Icons.chevron_left_rounded, _goPrevDay),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Column(
                          children: [
                            Text(
                              DateFormat('EEEE').format(_selectedDate),
                              style: AppTextStyles.label.copyWith(
                                color: isWorkingDay
                                    ? AppColors.primary
                                    : AppColors.error,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy').format(_selectedDate),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _navButton(Icons.chevron_right_rounded, _goNextDay),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Working hours info
            if (isWorkingDay)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _infoBadge(Icons.schedule_rounded,
                        '${daySchedule.startTime} – ${daySchedule.endTime}',
                        AppColors.primary),
                    if (daySchedule.breakStart != null) ...[
                      const SizedBox(width: 8),
                      _infoBadge(Icons.coffee_rounded,
                          '${daySchedule.breakStart} – ${daySchedule.breakEnd}',
                          AppColors.warning),
                    ],
                    const SizedBox(width: 8),
                    _infoBadge(Icons.timelapse_rounded,
                        '${_slotDuration}min slots', AppColors.accent),
                  ],
                ),
              ),

            if (!isWorkingDay)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy_rounded,
                          size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text('Day Off',
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                          'No working hours on ${DateFormat('EEEE').format(_selectedDate)}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              )
            else ...[
              // Stats
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    _statChip('Available', state.availableCount,
                        AppColors.success),
                    const SizedBox(width: 8),
                    _statChip(
                        'Booked', state.bookedCount, AppColors.error),
                  ],
                ),
              ),

              // Slots grid
              Expanded(
                child: state.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 3))
                    : state.slots.isEmpty
                        ? Center(
                            child: Text('No slots available',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textSecondary)))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 2.2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: state.slots.length,
                            itemBuilder: (context, index) {
                              return _slotChip(state.slots[index]);
                            },
                          ),
              ),
            ],

            // If a slot is selected, show confirm button
            if (_selectedSlot != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context, {
                      'date': _selectedDate,
                      'time': _selectedSlot,
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Select $_selectedSlot on ${DateFormat('MMM d').format(_selectedDate)}',
                          style: AppTextStyles.label
                              .copyWith(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotChip(TimeSlot slot) {
    final isSelected = _selectedSlot == slot.time;
    Color bg;
    Color textColor;
    Border? border;

    if (slot.isDuringBreak) {
      bg = AppColors.warning.withValues(alpha: 0.08);
      textColor = AppColors.warning;
    } else if (!slot.isAvailable) {
      bg = AppColors.error.withValues(alpha: 0.08);
      textColor = AppColors.textHint;
    } else if (isSelected) {
      bg = AppColors.primary;
      textColor = Colors.white;
    } else {
      bg = AppColors.success.withValues(alpha: 0.08);
      textColor = AppColors.success;
      border = Border.all(color: AppColors.success.withValues(alpha: 0.3));
    }

    return GestureDetector(
      onTap: slot.isAvailable
          ? () => setState(() => _selectedSlot = slot.time)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          slot.time,
          style: AppTextStyles.label.copyWith(
            color: textColor,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$count $label',
              style:
                  AppTextStyles.caption.copyWith(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
