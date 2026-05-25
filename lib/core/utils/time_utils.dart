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

  /// Generates a list of time candidate strings in various formats (e.g. HH:mm, hh:mm a, HH:mm:ss, hh:mmAM etc.)
  /// to match times stored in different formats in the database.
  static List<String> generateTimeCandidates(String time) {
    final clean = time.trim();
    if (clean.isEmpty) return [];
    final candidates = {clean};
    
    int? hour;
    int? minute;
    bool isPm = false;
    bool hasAmPm = false;

    final lower = clean.toLowerCase();
    if (lower.contains('am') || lower.contains('pm')) {
      hasAmPm = true;
      if (lower.contains('pm')) {
        isPm = true;
      }
    }

    final digitsOnly = lower.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = digitsOnly.split(':');
    if (parts.isNotEmpty) {
      hour = int.tryParse(parts[0]);
      if (parts.length > 1) {
        minute = int.tryParse(parts[1]);
      }
    }

    if (hour != null && minute != null) {
      int hour24 = hour;
      if (hasAmPm) {
        if (isPm && hour < 12) {
          hour24 = hour + 12;
        } else if (!isPm && hour == 12) {
          hour24 = 0;
        }
      }

      final h24Str = hour24.toString().padLeft(2, '0');
      final mStr = minute.toString().padLeft(2, '0');
      
      candidates.add('$h24Str:$mStr');
      candidates.add('$h24Str:$mStr:00');
      
      int hour12 = hour24 % 12;
      if (hour12 == 0) hour12 = 12;
      final h12Str = hour12.toString().padLeft(2, '0');
      final h12ShortStr = hour12.toString();
      final ampm = hour24 >= 12 ? 'PM' : 'AM';
      final ampmLower = ampm.toLowerCase();
      
      candidates.add('$h12Str:$mStr $ampm');
      candidates.add('$h12Str:$mStr$ampm');
      candidates.add('$h12Str:$mStr $ampmLower');
      candidates.add('$h12Str:$mStr$ampmLower');
      
      candidates.add('$h12ShortStr:$mStr $ampm');
      candidates.add('$h12ShortStr:$mStr$ampm');
      candidates.add('$h12ShortStr:$mStr $ampmLower');
      candidates.add('$h12ShortStr:$mStr$ampmLower');
    }

    return candidates.toList();
  }
}
