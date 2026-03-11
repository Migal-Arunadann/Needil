import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeUtils {
  /// Converts a 24-hour time string like "14:30" to 12-hour format "02:30 PM".
  /// If parsing fails, returns the original string.
  static String formatStringTime(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length < 2) return time24;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1].split(' ').first); // handle cases where it might already have AM/PM
      final dt = DateTime(2000, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(dt); // e.g., 02:30 PM
    } catch (e) {
      return time24;
    }
  }

  /// Converts a TimeOfDay to 12-hour format "02:30 PM".
  static String formatTimeOfDay(TimeOfDay time) {
    final dt = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }
}
