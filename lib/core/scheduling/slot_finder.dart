import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';

// ─── Result & Exception types ─────────────────────────────────────────────────

/// The result of a successful slot search.
class SlotResult {
  final DateTime date;
  final String time;
  final int daysSearched;
  final int slotsEvaluated;

  const SlotResult({
    required this.date,
    required this.time,
    this.daysSearched = 0,
    this.slotsEvaluated = 0,
  });
}

/// Thrown when no available slot can be found within the search window.
class NoSlotFoundException implements Exception {
  final String message;
  final int daysSearched;

  const NoSlotFoundException(this.message, this.daysSearched);

  @override
  String toString() => 'NoSlotFoundException: $message (searched $daysSearched days)';
}

/// Immutable context bundle loaded once per scheduling operation.
///
/// Passed to [SlotFinder] and [TreatmentScheduler] so individual
/// components never fetch doctor/clinic data independently.
class SchedulingContext {
  final String planId;
  final String doctorId;
  final String? clinicId;
  final List<int> workingDays;
  final int maxBeds;
  /// YYYY-MM-DD strings of all blocked dates (leave + holidays).
  final Set<String> blockedDates;
  /// Map from weekday (1=Mon … 7=Sun) to the doctor's WorkingSchedule.
  final Map<int, WorkingSchedule> daySchedules;

  const SchedulingContext({
    required this.planId,
    required this.doctorId,
    this.clinicId,
    required this.workingDays,
    required this.maxBeds,
    required this.blockedDates,
    required this.daySchedules,
  });

  /// Returns true if [date] is a valid working day that is not blocked.
  bool isDateAvailable(DateTime date) {
    if (workingDays.isNotEmpty && !workingDays.contains(date.weekday)) {
      return false;
    }
    if (blockedDates.contains(_formatDate(date))) return false;
    return true;
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── SlotFinder ───────────────────────────────────────────────────────────────

/// Single source of truth for slot allocation.
///
/// Key improvements over v1:
///   1. Capacity checked per-CLINIC (not per-doctor), fixing the bed-count bug.
///   2. Searches the doctor's full working hours and scores slots by proximity
///      to the preferred time — no more skipping early-morning slots.
///   3. Respects scheduling_exceptions (leave + holidays).
///   4. Throws [NoSlotFoundException] instead of silently force-booking a
///      full slot.
///   5. Search window capped at 90 calendar days.
class SlotFinder {
  final PocketBase pb;

  /// Maximum number of calendar days to search before giving up.
  static const int maxSearchDays = 90;

  SlotFinder(this.pb);

  /// Find the best available slot on or after [startDate].
  ///
  /// "Best" means the 30-minute slot closest to [preferredTime] that has
  /// fewer existing appointments than [context.maxBeds].
  ///
  /// The search respects:
  ///   - Doctor's working days
  ///   - Blocking exceptions (leave / holidays) from [context.blockedDates]
  ///   - Doctor's actual start/end hours from [context.daySchedules]
  ///   - Break windows from [context.daySchedules]
  ///   - Clinic-wide bed capacity (not per-doctor)
  Future<SlotResult> findBestSlot({
    required SchedulingContext context,
    required DateTime startDate,
    required String preferredTime,
  }) async {
    final preferredMinutes = _timeToMinutes(preferredTime);

    DateTime currentDate = startDate;
    int daysSearched = 0;
    int slotsEvaluated = 0;

    while (daysSearched < maxSearchDays) {
      if (context.isDateAvailable(currentDate)) {
        final slots = _generateDaySlots(currentDate, context);
        // Score and sort by proximity to preferred time
        slots.sort((a, b) {
          final aDiff = (a - preferredMinutes).abs();
          final bDiff = (b - preferredMinutes).abs();
          return aDiff.compareTo(bDiff);
        });

        final dateStr = _formatDate(currentDate);

        // HR-4 fix: fetch ALL appointments for this day in one query and
        // count per time slot in memory. Previously there was one DB
        // round-trip per slot (up to 1,620 queries per session in the worst
        // case). Now it is one query per day searched (max 90).
        final Map<String, int> countByTime = {};
        try {
          final dayFilter = context.clinicId != null && context.clinicId!.isNotEmpty
              ? 'clinic = "${context.clinicId}" && date = "$dateStr" && status != "cancelled"'
              : 'doctor = "${context.doctorId}" && date = "$dateStr" && status != "cancelled"';

          final dayAppts = await pb
              .collection(PBCollections.appointments)
              .getFullList(filter: dayFilter);

          for (final appt in dayAppts) {
            final t = appt.getStringValue('time');
            countByTime[t] = (countByTime[t] ?? 0) + 1;
          }
        } catch (_) {
          // On network error, skip this day conservatively
          currentDate = currentDate.add(const Duration(days: 1));
          daysSearched++;
          continue;
        }

        for (final slotMinutes in slots) {
          slotsEvaluated++;
          final slotTime = _minutesToTime(slotMinutes);
          if ((countByTime[slotTime] ?? 0) < context.maxBeds) {
            return SlotResult(
              date: currentDate,
              time: slotTime,
              daysSearched: daysSearched,
              slotsEvaluated: slotsEvaluated,
            );
          }
        }
      }

      currentDate = currentDate.add(const Duration(days: 1));
      daysSearched++;
    }

    throw NoSlotFoundException(
      'No available slot found for plan ${context.planId} '
      'starting from ${_formatDate(startDate)}',
      daysSearched,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Generate all valid 30-minute slot start-times (in minutes from midnight)
  /// for [date], using the doctor's WorkingSchedule if available.
  ///
  /// Falls back to 09:00–18:00 if no schedule is configured.
  List<int> _generateDaySlots(DateTime date, SchedulingContext context) {
    final schedule = context.daySchedules[date.weekday];

    int startMinutes;
    int endMinutes;
    List<Map<String, String>> breaks;

    if (schedule != null) {
      startMinutes = _timeToMinutes(schedule.startTime);
      endMinutes = _timeToMinutes(schedule.endTime);
      breaks = schedule.breaks;
    } else {
      // Default working hours if no specific schedule is set
      startMinutes = _timeToMinutes('09:00');
      endMinutes = _timeToMinutes('18:00');
      breaks = [];
    }

    final slots = <int>[];
    for (int t = startMinutes; t < endMinutes; t += 30) {
      if (!_isDuringBreak(t, breaks)) {
        slots.add(t);
      }
    }
    return slots;
  }

  /// Returns true if [minutes] falls within any break window.
  bool _isDuringBreak(int minutes, List<Map<String, String>> breaks) {
    for (final b in breaks) {
      final breakStart = _timeToMinutes(b['start'] ?? '');
      final breakEnd = _timeToMinutes(b['end'] ?? '');
      if (breakStart > 0 && breakEnd > 0 && minutes >= breakStart && minutes < breakEnd) {
        return true;
      }
    }
    return false;
  }

  int _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }

  String _minutesToTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── Context Loader ───────────────────────────────────────────────────────────

/// Loads a [SchedulingContext] for a given treatment plan.
///
/// This is separate so the TreatmentScheduler can load context once
/// and pass it down to SlotFinder without repeated DB fetches.
class SchedulingContextLoader {
  final PocketBase pb;

  SchedulingContextLoader(this.pb);

  Future<SchedulingContext> load(String planId) async {
    final planRec = await pb.collection('treatment_plans').getOne(planId);
    final doctorId = planRec.getStringValue('doctor');

    // Load doctor
    final docRec = await pb.collection('doctors').getOne(doctorId);
    final doctor = DoctorModel.fromRecord(docRec);
    final clinicId = doctor.clinicId;

    // Load bed count
    int maxBeds = 1; // Default for independent doctors
    if (clinicId != null && clinicId.isNotEmpty) {
      try {
        final clinicRec = await pb.collection('clinics').getOne(clinicId);
        maxBeds = clinicRec.getIntValue('bed_count');
        if (maxBeds <= 0) maxBeds = 3;
      } catch (_) {
        maxBeds = 3;
      }
    }

    // Load scheduling exceptions (leave + holidays) for the next 90 days
    final today = _formatDate(DateTime.now());
    final ninetyDaysOut =
        _formatDate(DateTime.now().add(const Duration(days: 90)));
    final blockedDates = <String>{};
    try {
      // LR-1 fix: build a filter that correctly handles independent doctors
      // (no clinic). The old filter used 'clinic = "" && doctor = ""' for
      // the clinic-wide branch when clinicId was null, which matched
      // orphaned records instead of the doctor's own exceptions.
      final String exFilter;
      if (clinicId != null && clinicId.isNotEmpty) {
        // Clinic doctor: load doctor-specific AND clinic-wide exceptions
        exFilter =
            '(doctor = "$doctorId" || (clinic = "$clinicId" && doctor = "")) '
            '&& date >= "$today" && date <= "$ninetyDaysOut"';
      } else {
        // Independent doctor: load only doctor-specific exceptions
        exFilter =
            'doctor = "$doctorId" '
            '&& date >= "$today" && date <= "$ninetyDaysOut"';
      }
      final exceptions = await pb
          .collection('scheduling_exceptions')
          .getList(filter: exFilter, perPage: 200);
      for (final rec in exceptions.items) {
        blockedDates.add(rec.getStringValue('date'));
      }
    } catch (_) {
      // scheduling_exceptions collection may not exist yet — safe to ignore
    }

    // Build weekday → schedule map
    final Map<int, WorkingSchedule> daySchedules = {};
    const dayMap = {
      'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4,
      'Friday': 5, 'Saturday': 6, 'Sunday': 7,
    };
    for (final ws in doctor.workingSchedule) {
      final weekday = dayMap[ws.day];
      if (weekday != null) daySchedules[weekday] = ws;
    }

    return SchedulingContext(
      planId: planId,
      doctorId: doctorId,
      clinicId: clinicId,
      workingDays: doctor.workingDays,
      maxBeds: maxBeds,
      blockedDates: blockedDates,
      daySchedules: daySchedules,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
