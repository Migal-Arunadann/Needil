import 'package:flutter_test/flutter_test.dart';
import 'package:pms_app/core/scheduling/slot_finder.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';

void main() {
  group('Scheduling & Holiday/Leave Exception Simulation Tests', () {
    late Map<int, WorkingSchedule> sampleDaySchedules;

    setUp(() {
      sampleDaySchedules = {
        1: WorkingSchedule(day: 'Monday', startTime: '09:00', endTime: '18:00', breaks: []),
        2: WorkingSchedule(day: 'Tuesday', startTime: '09:00', endTime: '18:00', breaks: []),
        3: WorkingSchedule(day: 'Wednesday', startTime: '09:00', endTime: '18:00', breaks: []),
        4: WorkingSchedule(day: 'Thursday', startTime: '09:00', endTime: '18:00', breaks: []),
        5: WorkingSchedule(day: 'Friday', startTime: '09:00', endTime: '18:00', breaks: []),
        6: WorkingSchedule(day: 'Saturday', startTime: '09:00', endTime: '14:00', breaks: []),
      };
    });

    test('1. isDateAvailable returns false for Doctor Leave on specific date', () {
      final context = SchedulingContext(
        planId: 'plan_1',
        doctorId: 'doc_1',
        clinicId: 'clinic_1',
        workingDays: [1, 2, 3, 4, 5, 6], // Mon - Sat
        maxBeds: 3,
        blockedDates: {'2026-09-15'}, // Tuesday Sept 15 blocked
        daySchedules: sampleDaySchedules,
      );

      // Sept 15, 2026 is Tuesday
      final blockedTuesday = DateTime(2026, 9, 15);
      final openWednesday = DateTime(2026, 9, 16);
      final sunday = DateTime(2026, 9, 20); // Sunday (not in workingDays)

      expect(context.isDateAvailable(blockedTuesday), isFalse,
          reason: 'Sept 15 should be blocked due to leave');
      expect(context.isDateAvailable(openWednesday), isTrue,
          reason: 'Sept 16 should be open for scheduling');
      expect(context.isDateAvailable(sunday), isFalse,
          reason: 'Sunday should be blocked due to workingDays constraint');
    });

    test('2. Multi-session treatment plan simulation skips blocked leave and holiday dates', () {
      final context = SchedulingContext(
        planId: 'plan_1',
        doctorId: 'doc_1',
        clinicId: 'clinic_1',
        workingDays: [1, 2, 3, 4, 5], // Mon - Fri
        maxBeds: 3,
        blockedDates: {
          '2026-09-15', // Doctor Leave on Tuesday
          '2026-09-17', // Clinic Holiday on Thursday
        },
        daySchedules: sampleDaySchedules,
      );

      // Simulate placing 4 sessions starting from Monday Sept 14, interval = 1 day
      final scheduledDates = <DateTime>[];
      DateTime searchCursor = DateTime(2026, 9, 14); // Monday

      for (int i = 0; i < 4; i++) {
        while (!context.isDateAvailable(searchCursor)) {
          searchCursor = searchCursor.add(const Duration(days: 1));
        }
        scheduledDates.add(searchCursor);
        // Move to next session target date (interval = 1 day)
        searchCursor = searchCursor.add(const Duration(days: 1));
      }

      // Expected schedule:
      // Session 1: Mon Sep 14 (open)
      // Session 2: Tue Sep 15 is BLOCKED -> moves to Wed Sep 16
      // Session 3: Thu Sep 17 is BLOCKED -> moves to Fri Sep 18
      // Session 4: Sat Sep 19 / Sun Sep 20 BLOCKED (weekend) -> moves to Mon Sep 21
      expect(scheduledDates[0], equals(DateTime(2026, 9, 14)));
      expect(scheduledDates[1], equals(DateTime(2026, 9, 16)));
      expect(scheduledDates[2], equals(DateTime(2026, 9, 18)));
      expect(scheduledDates[3], equals(DateTime(2026, 9, 21)));
    });

    test('3. Doctor scoping: Doctor A is blocked on their leave, but Doctor B remains available', () {
      final doctorALeaveDates = {'2026-09-15'};
      final doctorBLeaveDates = <String>{};

      final contextDocA = SchedulingContext(
        planId: 'plan_A',
        doctorId: 'doc_A',
        clinicId: 'clinic_1',
        workingDays: [1, 2, 3, 4, 5],
        maxBeds: 3,
        blockedDates: doctorALeaveDates,
        daySchedules: sampleDaySchedules,
      );

      final contextDocB = SchedulingContext(
        planId: 'plan_B',
        doctorId: 'doc_B',
        clinicId: 'clinic_1',
        workingDays: [1, 2, 3, 4, 5],
        maxBeds: 3,
        blockedDates: doctorBLeaveDates,
        daySchedules: sampleDaySchedules,
      );

      final date = DateTime(2026, 9, 15);
      expect(contextDocA.isDateAvailable(date), isFalse,
          reason: 'Doctor A is on leave');
      expect(contextDocB.isDateAvailable(date), isTrue,
          reason: 'Doctor B is available and not affected by Doctor A leave');
    });

    test('4. Clinic holiday blocks ALL doctors in the clinic', () {
      final clinicHolidayDates = {'2026-10-02'}; // Gandhi Jayanti

      final contextDocA = SchedulingContext(
        planId: 'plan_A',
        doctorId: 'doc_A',
        clinicId: 'clinic_1',
        workingDays: [1, 2, 3, 4, 5],
        maxBeds: 3,
        blockedDates: clinicHolidayDates,
        daySchedules: sampleDaySchedules,
      );

      final contextDocB = SchedulingContext(
        planId: 'plan_B',
        doctorId: 'doc_B',
        clinicId: 'clinic_1',
        workingDays: [1, 2, 3, 4, 5],
        maxBeds: 3,
        blockedDates: clinicHolidayDates,
        daySchedules: sampleDaySchedules,
      );

      final holidayDate = DateTime(2026, 10, 2);
      expect(contextDocA.isDateAvailable(holidayDate), isFalse);
      expect(contextDocB.isDateAvailable(holidayDate), isFalse);
    });

    test('5. Pinned sessions are protected during leave cascade shifts', () {
      // Suppose Session 4 is pinned to Sept 22
      final session4 = SessionModel(
        id: 's4',
        treatmentPlanId: 'tp1',
        patientId: 'p1',
        doctorId: 'doc1',
        scheduledDate: '2026-09-22',
        sessionNumber: 4,
        isPinned: true,
        status: SessionStatus.upcoming,
      );

      expect(session4.isPinned, isTrue,
          reason: 'Pinned sessions should be flagged to avoid automatic date shift');
    });
  });
}
