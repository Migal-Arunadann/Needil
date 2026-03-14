import '../../features/auth/models/doctor_model.dart';
import '../constants/pb_collections.dart';
import 'package:pocketbase/pocketbase.dart';

/// Time slot representing a bookable appointment window.
class TimeSlot {
  final String time; // "HH:mm"
  final bool isAvailable;
  final bool isDuringBreak;
  final bool isPast;

  const TimeSlot({
    required this.time,
    this.isAvailable = true,
    this.isDuringBreak = false,
    this.isPast = false,
  });
}

/// Scheduling service for availability checks and slot generation.
class SchedulingService {
  final PocketBase pb;

  SchedulingService(this.pb);

  // ─── Working Hours Validation ──────────────────────────────

  /// Get the working schedule for a specific day of the week.
  /// [dayOfWeek]: 1 = Monday, 7 = Sunday (from DateTime.weekday).
  WorkingSchedule? getScheduleForDay(
      List<WorkingSchedule> schedules, int dayOfWeek) {
    final dayName = _dayName(dayOfWeek);
    try {
      return schedules.firstWhere(
          (s) => s.day.toLowerCase() == dayName.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Check if a given time falls within working hours (excluding break).
  bool isWithinWorkingHours(WorkingSchedule schedule, String time) {
    final t = _parseTime(time);
    final start = _parseTime(schedule.startTime);
    final end = _parseTime(schedule.endTime);

    if (t < start || t >= end) return false;

    // Check break period
    if (schedule.breakStart != null && schedule.breakEnd != null) {
      final breakS = _parseTime(schedule.breakStart!);
      final breakE = _parseTime(schedule.breakEnd!);
      if (t >= breakS && t < breakE) return false;
    }

    return true;
  }

  /// Check if a doctor works on a given date.
  bool isDoctorWorkingOnDate(
      List<WorkingSchedule> schedules, DateTime date) {
    return getScheduleForDay(schedules, date.weekday) != null;
  }

  // ─── Slot Generation ───────────────────────────────────────

  /// Generate available time slots for a doctor on a given date.
  /// Excludes slots during break time and already-booked slots.
  Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
    required List<WorkingSchedule> schedules,
    required int slotDurationMinutes,
  }) async {
    final schedule = getScheduleForDay(schedules, date.weekday);
    if (schedule == null) return []; // Doctor doesn't work this day

    // Generate all time slots for the working day
    final allSlots = _generateSlots(schedule, slotDurationMinutes, date);

    // Get existing appointments for this doctor on this date
    final dateStr = _formatDate(date);
    final bookedTimes = await _getBookedTimes(doctorId, dateStr);

    // Mark booked slots as unavailable
    return allSlots.map((slot) {
      final booked = bookedTimes.contains(slot.time);
      return TimeSlot(
        time: slot.time,
        isAvailable: !booked && !slot.isDuringBreak && !slot.isPast,
        isDuringBreak: slot.isDuringBreak,
        isPast: slot.isPast,
      );
    }).toList();
  }

  /// Generate all possible time slots within working hours.
  List<TimeSlot> _generateSlots(
      WorkingSchedule schedule, int durationMinutes, DateTime targetDate) {
    final slots = <TimeSlot>[];
    var current = _parseTime(schedule.startTime);
    final end = _parseTime(schedule.endTime);
    final breakStart = schedule.breakStart != null
        ? _parseTime(schedule.breakStart!)
        : null;
    final breakEnd = schedule.breakEnd != null
        ? _parseTime(schedule.breakEnd!)
        : null;

    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
    final currentMinutes = now.hour * 60 + now.minute;

    while (current + durationMinutes <= end) {
      final isDuringBreak = breakStart != null &&
          breakEnd != null &&
          current >= breakStart &&
          current < breakEnd;
          
      final isPast = isToday && current < currentMinutes;

      slots.add(TimeSlot(
        time: _minutesToTimeStr(current),
        isAvailable: !isDuringBreak && !isPast,
        isDuringBreak: isDuringBreak,
        isPast: isPast,
      ));

      current += durationMinutes;
    }

    return slots;
  }

  /// Get booked appointment times for a doctor on a date.
  Future<Set<String>> _getBookedTimes(
      String doctorId, String date) async {
    try {
      final result = await pb.collection(PBCollections.appointments).getList(
        filter:
            'doctor = "$doctorId" && date = "$date" && status != "cancelled"',
      );
      return result.items.map((r) => r.getStringValue('time')).toSet();
    } catch (_) {
      return {};
    }
  }

  // ─── Bed Capacity Checks ──────────────────────────────────

  /// Check how many concurrent appointments exist for a clinic at a date/time.
  Future<int> getConcurrentAppointments(
      String clinicId, String date, String time) async {
    try {
      // Get all doctors for this clinic
      final doctors = await pb.collection(PBCollections.doctors).getList(
        filter: 'clinic = "$clinicId"',
      );
      final doctorIds =
          doctors.items.map((d) => d.id).toList();

      if (doctorIds.isEmpty) return 0;

      // Build the doctor filter
      final doctorFilter = doctorIds
          .map((id) => 'doctor = "$id"')
          .join(' || ');

      final result = await pb.collection(PBCollections.appointments).getList(
        filter:
            '($doctorFilter) && date = "$date" && time = "$time" && status != "cancelled"',
      );
      return result.items.length;
    } catch (_) {
      return 0;
    }
  }

  /// Check if a clinic has bed capacity at a given date/time.
  Future<bool> hasAvailableBeds(
      String clinicId, int totalBeds, String date, String time) async {
    final concurrent = await getConcurrentAppointments(clinicId, date, time);
    return concurrent < totalBeds;
  }

  // ─── Conflict Detection ────────────────────────────────────

  /// Check if a specific slot is already booked.
  Future<bool> isSlotBooked(
      String doctorId, String date, String time) async {
    try {
      final result = await pb.collection(PBCollections.appointments).getList(
        filter:
            'doctor = "$doctorId" && date = "$date" && time = "$time" && status != "cancelled"',
      );
      return result.items.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Validate an appointment time comprehensively.
  Future<String?> validateAppointmentTime({
    required String doctorId,
    required DateTime date,
    required String time,
    required List<WorkingSchedule> schedules,
    String? clinicId,
    int? totalBeds,
  }) async {
    // 1. Check if doctor works this day
    final schedule = getScheduleForDay(schedules, date.weekday);
    if (schedule == null) {
      return 'Doctor does not work on ${_dayName(date.weekday)}s';
    }

    // 2. Check working hours
    if (!isWithinWorkingHours(schedule, time)) {
      return 'Time is outside working hours (${schedule.startTime} - ${schedule.endTime})';
    }

    // 3. Check if slot is already booked
    final dateStr = _formatDate(date);
    final booked = await isSlotBooked(doctorId, dateStr, time);
    if (booked) {
      return 'This time slot is already booked';
    }

    // 4. Check bed capacity (if clinic)
    if (clinicId != null && totalBeds != null) {
      final hasBeds =
          await hasAvailableBeds(clinicId, totalBeds, dateStr, time);
      if (!hasBeds) {
        return 'All $totalBeds beds are occupied at this time';
      }
    }

    return null; // Valid!
  }

  // ─── Helpers ───────────────────────────────────────────────

  String _dayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  /// Convert "HH:mm" to minutes since midnight.
  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Convert minutes since midnight to "HH:mm".
  String _minutesToTimeStr(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Fetch a doctor's working schedule dynamically by ID.
  Future<List<WorkingSchedule>> getDoctorSchedules(String doctorId) async {
    try {
      final record = await pb.collection(PBCollections.doctors).getOne(doctorId);
      final doc = DoctorModel.fromRecord(record);
      return doc.workingSchedule;
    } catch (_) {
      return [];
    }
  }
}
