import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/date_picker_helper.dart';

class RescheduleAnchorDialog extends StatelessWidget {
  final List<int>? workingDays;
  final String title;
  final String subtitle;

  const RescheduleAnchorDialog({
    super.key,
    this.workingDays,
    this.title = 'Reschedule Starting Point',
    this.subtitle = 'Choose when the rescheduled sessions should start from:',
  });

  static Future<DateTime?> show(
    BuildContext context, {
    List<int>? workingDays,
    String title = 'Reschedule Starting Point',
    String subtitle = 'Choose when the rescheduled sessions should start from:',
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => RescheduleAnchorDialog(
        workingDays: workingDays,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5D4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_repeat_rounded, color: Color(0xFF0F5D4F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _OptionButton(
            icon: Icons.today_rounded,
            label: 'Today',
            sublabel: DateFormat('E, MMM d').format(today),
            color: const Color(0xFF0F5D4F),
            onTap: () => Navigator.pop(context, today),
          ),
          const SizedBox(height: 10),
          _OptionButton(
            icon: Icons.wb_sunny_outlined,
            label: 'Tomorrow',
            sublabel: DateFormat('E, MMM d').format(tomorrow),
            color: const Color(0xFF2563EB),
            onTap: () => Navigator.pop(context, tomorrow),
          ),
          const SizedBox(height: 10),
          _OptionButton(
            icon: Icons.calendar_month_rounded,
            label: 'Custom Date',
            sublabel: 'Pick a specific date',
            color: const Color(0xFFD97706),
            onTap: () async {
              final picked = await showAppDatePicker(
                context: context,
                initialDate: today,
                firstDate: today,
                lastDate: today.add(const Duration(days: 365)),
                selectableDayPredicate: workingDays != null && workingDays!.isNotEmpty
                    ? (day) => workingDays!.contains(day.weekday)
                    : null,
              );
              if (picked != null && context.mounted) {
                Navigator.pop(context, picked);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
