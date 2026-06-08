import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/services/scheduling_service.dart';
import 'package:pms_app/features/scheduling/providers/scheduling_provider.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import 'package:pms_app/core/utils/time_utils.dart';
import 'package:pms_app/core/theme/app_theme.dart';


class AvailableSlotsScreen extends ConsumerStatefulWidget {
  final String doctorId;
  final String? clinicId;
  final List<WorkingSchedule>? schedules;
  final int treatmentDuration;
  final bool isSelectionMode;
  final bool allowFutureDates;
  final DateTime? initialDate;

  const AvailableSlotsScreen({
    super.key,
    required this.doctorId,
    this.clinicId,
    this.schedules,
    required this.treatmentDuration,
    this.isSelectionMode = false,
    this.allowFutureDates = true,
    this.initialDate,
  });

  @override
  ConsumerState<AvailableSlotsScreen> createState() =>
      _AvailableSlotsScreenState();
}

class _AvailableSlotsScreenState extends ConsumerState<AvailableSlotsScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _calendarMonth; // the month shown in the inline calendar
  String? _selectedSlot;
  int _slotDuration = 30;
  bool _calendarExpanded = true;

  late AnimationController _confirmCtrl;
  late Animation<double> _confirmSlide;
  late Animation<double> _confirmFade;

  List<WorkingSchedule> get _schedules =>
      widget.schedules ??
      ref.read(authProvider).doctor?.workingSchedule ??
      [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _slotDuration = widget.treatmentDuration;

    _confirmCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _confirmSlide = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _confirmCtrl, curve: Curves.easeOutCubic),
    );
    _confirmFade = CurvedAnimation(parent: _confirmCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _loadSlots() {
    ref.read(availableSlotsProvider.notifier).loadSlots(
          doctorId: widget.doctorId,
          date: _selectedDate,
          schedules: _schedules,
          slotDurationMinutes: _slotDuration,
        );
  }

  void _selectDate(DateTime date) {
    final today = DateTime.now();
    final earliest = DateTime(today.year, today.month, today.day);
    if (!widget.allowFutureDates && date.isAfter(earliest)) return;
    if (date.isBefore(earliest)) return;

    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
    });
    _confirmCtrl.reverse();
    _loadSlots();
  }

  void _goToToday() {
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    setState(() {
      _calendarMonth = DateTime(d.year, d.month);
    });
    _selectDate(d);
  }

  void _selectSlot(String time) {
    setState(() => _selectedSlot = time);
    _confirmCtrl.forward();
  }

  void _confirmSlot() {
    Navigator.pop(context, {
      'date': _selectedDate,
      'time': _selectedSlot,
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availableSlotsProvider);
    final service = ref.read(schedulingServiceProvider);
    final activeSchedules =
        state.schedules.isNotEmpty ? state.schedules : _schedules;
    final daySchedule =
        service.getScheduleForDay(activeSchedules, _selectedDate.weekday);
    final isWorkingDay = daySchedule != null;
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final headerSection = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: context.colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 20, color: context.colors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pick a Slot', style: context.textStyles.h2),
                        Text(
                          isToday
                              ? 'Today — ${DateFormat('d MMM').format(_selectedDate)}'
                              : DateFormat('EEEE, d MMM').format(_selectedDate),
                          style: context.textStyles.caption
                              .copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (widget.allowFutureDates && !isToday)
                    GestureDetector(
                      onTap: _goToToday,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Today',
                          style: context.textStyles.label.copyWith(
                            color: context.colors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (!isDesktop)
                    GestureDetector(
                      onTap: () => setState(
                          () => _calendarExpanded = !_calendarExpanded),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _calendarExpanded
                              ? context.colors.primary
                              : context.colors.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: _calendarExpanded
                                ? context.colors.primary
                                : context.colors.border,
                          ),
                        ),
                        child: Icon(
                          _calendarExpanded
                              ? Icons.calendar_month_rounded
                              : Icons.calendar_month_outlined,
                          size: 18,
                          color: _calendarExpanded
                              ? Colors.white
                              : context.colors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            );

            final calendarWidget = _InlineCalendar(
              selectedDate: _selectedDate,
              month: _calendarMonth,
              allowFutureDates: widget.allowFutureDates,
              schedules: activeSchedules,
              schedulingService: service,
              onDateSelected: _selectDate,
              onMonthChanged: (m) => setState(() => _calendarMonth = m),
            );

            final confirmPanel = _selectedSlot != null
                ? _ConfirmPanel(
                    selectedDate: _selectedDate,
                    selectedSlot: _selectedSlot!,
                    onConfirm: _confirmSlot,
                  )
                : const SizedBox.shrink();

            if (isDesktop) {
              Widget desktopSlotsWidget;
              if (state.isLoading) {
                desktopSlotsWidget = SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: context.colors.primary, strokeWidth: 3),
                  ),
                );
              } else if (!isWorkingDay) {
                desktopSlotsWidget = SizedBox(
                  height: 300,
                  child: _DayOffState(dayName: DateFormat('EEEE').format(_selectedDate)),
                );
              } else if (state.slots.isEmpty) {
                desktopSlotsWidget = const SizedBox(
                  height: 300,
                  child: _NoSlotsState(),
                );
              } else {
                desktopSlotsWidget = GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: state.slots.length,
                  itemBuilder: (context, index) => _SlotChip(
                    slot: state.slots[index],
                    isSelected: _selectedSlot == state.slots[index].time,
                    onTap: state.slots[index].isAvailable && !state.slots[index].isPast
                        ? () => _selectSlot(state.slots[index].time)
                        : null,
                  ),
                );
              }

              final desktopBody = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Date', style: context.textStyles.h3),
                        const SizedBox(height: 12),
                        calendarWidget,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available Slots', style: context.textStyles.h3),
                        const SizedBox(height: 12),
                        if (state.isLoading || !isWorkingDay || state.slots.isEmpty)
                          desktopSlotsWidget
                        else
                          SizedBox(
                            height: 380,
                            child: SingleChildScrollView(child: desktopSlotsWidget),
                          ),
                      ],
                    ),
                  ),
                ],
              );

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headerSection,
                          const SizedBox(height: 24),
                          desktopBody,
                          if (_selectedSlot != null) ...[
                            const SizedBox(height: 24),
                            confirmPanel,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else {
              Widget mobileSlotsWidget;
              if (state.isLoading) {
                mobileSlotsWidget = Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: context.colors.primary, strokeWidth: 3),
                  ),
                );
              } else if (!isWorkingDay) {
                mobileSlotsWidget = Expanded(
                  child: _DayOffState(dayName: DateFormat('EEEE').format(_selectedDate)),
                );
              } else if (state.slots.isEmpty) {
                mobileSlotsWidget = const Expanded(child: _NoSlotsState());
              } else {
                mobileSlotsWidget = Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.1,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: state.slots.length,
                      itemBuilder: (context, index) => _SlotChip(
                        slot: state.slots[index],
                        isSelected: _selectedSlot == state.slots[index].time,
                        onTap: state.slots[index].isAvailable && !state.slots[index].isPast
                            ? () => _selectSlot(state.slots[index].time)
                            : null,
                      ),
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerSection,
                      const SizedBox(height: 14),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 280),
                        crossFadeState: _calendarExpanded
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: calendarWidget,
                        ),
                        secondChild: const SizedBox(height: 0),
                      ),
                      if (_calendarExpanded) const SizedBox(height: 14),
                      mobileSlotsWidget,
                    ],
                  ),
                  if (_selectedSlot != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedBuilder(
                        animation: _confirmCtrl,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _confirmSlide.value),
                          child: FadeTransition(opacity: _confirmFade, child: child),
                        ),
                        child: confirmPanel,
                      ),
                    ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

// ── Inline Calendar ────────────────────────────────────────────────────────
class _InlineCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime month;
  final bool allowFutureDates;
  final List<WorkingSchedule> schedules;
  final SchedulingService schedulingService;
  final void Function(DateTime) onDateSelected;
  final void Function(DateTime) onMonthChanged;

  const _InlineCalendar({
    required this.selectedDate,
    required this.month,
    required this.allowFutureDates,
    required this.schedules,
    required this.schedulingService,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    // Monday-based offset (weekday: 1=Mon … 7=Sun)
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth =
        DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _MonthNavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => onMonthChanged(
                      DateTime(month.year, month.month - 1)),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(month),
                    textAlign: TextAlign.center,
                    style: context.textStyles.label
                        .copyWith(fontSize: 15),
                  ),
                ),
                _MonthNavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => onMonthChanged(
                      DateTime(month.year, month.month + 1)),
                ),
              ],
            ),
          ),

          // Day-of-week headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: context.textStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),

          // Date grid
          Padding(
            padding:
                const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: List.generate(rows, (row) {
                return Row(
                  children: List.generate(7, (col) {
                    final cellIndex = row * 7 + col;
                    final dayNum = cellIndex - startOffset + 1;

                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 38));
                    }

                    final date =
                        DateTime(month.year, month.month, dayNum);
                    final isSelected =
                        DateUtils.isSameDay(date, selectedDate);
                    final isToday =
                        DateUtils.isSameDay(date, today);
                    final earliest = DateTime(today.year, today.month, today.day);
                    final isPast = date.isBefore(earliest) || (!allowFutureDates && date.isAfter(earliest));
                    final isWorkingDay = schedulingService
                            .getScheduleForDay(
                                schedules, date.weekday) !=
                        null;

                    Color? bg;
                    Color textColor;
                    Border? border;

                    if (isSelected) {
                      bg = context.colors.primary;
                      textColor = Colors.white;
                    } else if (isToday) {
                      bg = context.colors.primary.withValues(alpha: 0.10);
                      textColor = context.colors.primary;
                      border = Border.all(
                          color: context.colors.primary
                              .withValues(alpha: 0.4),
                          width: 1.2);
                    } else if (isPast) {
                      textColor = context.colors.textHint
                          .withValues(alpha: 0.4);
                    } else if (!isWorkingDay) {
                      textColor = context.colors.error
                          .withValues(alpha: 0.5);
                    } else {
                      textColor = context.colors.textPrimary;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: isPast ? null : () => onDateSelected(date),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          height: 38,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: border,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 20, color: context.colors.primary),
      ),
    );
  }
}

// ── Slot Chip ──────────────────────────────────────────────────────────────
class _SlotChip extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = slot.isPast;
    final isBooked = !slot.isAvailable && !slot.isDuringBreak;
    final isBreak = slot.isDuringBreak;

    Color bg;
    Color textColor;
    Border? border;
    BoxShadow? shadow;

    if (isSelected) {
      bg = context.colors.primary;
      textColor = Colors.white;
      shadow = BoxShadow(
        color: context.colors.primary.withValues(alpha: 0.35),
        blurRadius: 10,
        offset: const Offset(0, 4),
      );
    } else if (isBreak || isPast || isBooked) {
      bg = context.colors.surface;
      textColor = context.colors.textHint.withValues(alpha: 0.45);
      border = Border.all(
          color: context.colors.border.withValues(alpha: 0.5), width: 0.8);
    } else {
      bg = context.colors.cardBackground;
      textColor = context.colors.textPrimary;
      border = Border.all(color: context.colors.border, width: 0.8);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: shadow != null ? [shadow] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          TimeUtils.formatStringTime(slot.time),
          style: context.textStyles.label.copyWith(
            color: textColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Confirm Panel ──────────────────────────────────────────────────────────
class _ConfirmPanel extends StatelessWidget {
  final DateTime selectedDate;
  final String selectedSlot;
  final VoidCallback onConfirm;

  const _ConfirmPanel({
    required this.selectedDate,
    required this.selectedSlot,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        gradient: context.colors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onConfirm,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TimeUtils.formatStringTime(selectedSlot),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, d MMM').format(selectedDate),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty States ───────────────────────────────────────────────────────────
class _DayOffState extends StatelessWidget {
  final String dayName;
  const _DayOffState({required this.dayName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(Icons.event_busy_rounded,
                size: 36, color: context.colors.textHint),
          ),
          const SizedBox(height: 16),
          Text('No Working Hours',
              style: context.textStyles.h3
                  .copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 6),
          Text('$dayName is a day off', style: context.textStyles.caption),
        ],
      ),
    );
  }
}

class _NoSlotsState extends StatelessWidget {
  const _NoSlotsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(Icons.schedule_rounded,
                size: 36, color: context.colors.textHint),
          ),
          const SizedBox(height: 16),
          Text('No Slots Available',
              style: context.textStyles.h3
                  .copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 6),
          Text('All slots are booked for this day',
              style: context.textStyles.caption),
        ],
      ),
    );
  }
}
