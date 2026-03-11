import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class TimeSlotPicker extends StatefulWidget {
  final TimeOfDay? initialTime;
  final int intervalMinutes;

  const TimeSlotPicker({
    super.key,
    this.initialTime,
    this.intervalMinutes = 30,
  });

  static Future<TimeOfDay?> show(
    BuildContext context, {
    TimeOfDay? initialTime,
    int intervalMinutes = 30,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimeSlotPicker(
        initialTime: initialTime,
        intervalMinutes: intervalMinutes,
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
    for (int h = 0; h < 24; h++) {
      for (int m = 0; m < 60; m += interval) {
        slots.add(TimeOfDay(hour: h, minute: m));
      }
    }
    return slots;
  }

  String _format(TimeOfDay t) {
    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Time', style: AppTextStyles.h2),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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

                return GestureDetector(
                  onTap: () {
                    setState(() => _selected = slot);
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) Navigator.pop(context, slot);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      _format(slot),
                      style: AppTextStyles.label.copyWith(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
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
