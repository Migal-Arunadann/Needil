import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/theme/app_theme.dart';


class TimeSlotPicker extends StatefulWidget {
  final TimeOfDay? initialTime;
  final int intervalMinutes;
  final int startHour;
  final int startMinute;  // NEW: start within the startHour
  final int endHour;
  final TimeOfDay? minTime; // Slots before this are disabled

  const TimeSlotPicker({
    super.key,
    this.initialTime,
    this.intervalMinutes = 30,
    this.startHour = 5,
    this.startMinute = 0,
    this.endHour = 23,
    this.minTime,
  });

  static Future<TimeOfDay?> show(
    BuildContext context, {
    TimeOfDay? initialTime,
    int intervalMinutes = 30,
    int startHour = 5,
    int startMinute = 0,
    int endHour = 23,
    TimeOfDay? minTime,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimeSlotPicker(
        initialTime: initialTime,
        intervalMinutes: intervalMinutes,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        minTime: minTime,
      ),
    );
  }

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  late final List<TimeOfDay> _slots;
  TimeOfDay? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTime;
    _slots = _generateIntervals(widget.intervalMinutes);
  }

  List<TimeOfDay> _generateIntervals(int interval) {
    final slots = <TimeOfDay>[];
    // Start from startHour:startMinute, snapped to next interval boundary
    final totalStartMinutes = widget.startHour * 60 + widget.startMinute;
    // Find the first slot >= totalStartMinutes that is on an interval boundary
    int firstSlotMinutes = totalStartMinutes;
    if (firstSlotMinutes % interval != 0) {
      firstSlotMinutes = ((firstSlotMinutes ~/ interval) + 1) * interval;
    }
    final totalEndMinutes = widget.endHour * 60;
    int current = firstSlotMinutes;
    while (current <= totalEndMinutes) {
      slots.add(TimeOfDay(hour: current ~/ 60, minute: current % 60));
      current += interval;
    }
    return slots;
  }

  bool _isDisabled(TimeOfDay slot) {
    if (widget.minTime == null) return false;
    final slotMin = slot.hour * 60 + slot.minute;
    final minMin = widget.minTime!.hour * 60 + widget.minTime!.minute;
    // Strict less-than: the exact minTime slot is NOT disabled (it is selectable)
    return slotMin < minMin;
  }

  String _format(TimeOfDay t) {
    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Time', style: context.textStyles.h2),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Range indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14, color: context.colors.textHint),
                const SizedBox(width: 6),
                Text(
                  '${_format(TimeOfDay(hour: widget.startHour, minute: widget.startMinute))} – ${_format(TimeOfDay(hour: widget.endHour, minute: 0))}',
                  style: context.textStyles.caption
                      .copyWith(color: context.colors.textHint, fontSize: 12),
                ),
                if (widget.minTime != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'After ${_format(widget.minTime!)}',
                      style: context.textStyles.caption
                          .copyWith(color: context.colors.warning, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: GridView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final isSelected = _selected != null &&
                    _selected!.hour == slot.hour &&
                    _selected!.minute == slot.minute;
                final disabled = _isDisabled(slot);

                return GestureDetector(
                  onTap: disabled
                      ? null
                      : () {
                          setState(() => _selected = slot);
                          Future.delayed(
                              const Duration(milliseconds: 150), () {
                            if (mounted) Navigator.pop(context, slot);
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: disabled
                          ? context.colors.border.withValues(alpha: 0.3)
                          : isSelected
                              ? context.colors.primary
                              : context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: disabled
                            ? context.colors.border
                            : isSelected
                                ? context.colors.primary
                                : context.colors.border,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    context.colors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      _format(slot),
                      style: context.textStyles.label.copyWith(
                        color: disabled
                            ? context.colors.textHint.withValues(alpha: 0.4)
                            : isSelected
                                ? Colors.white
                                : context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
