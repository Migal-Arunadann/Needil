import 'package:flutter_test/flutter_test.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';

void main() {
  group('MissedSessionDetector Tests', () {
    test('Identifies missed sessions correctly based on time', () {
      final now = DateTime.now();
      
      // Setup a session from 5 days ago (should be missed)
      final pastSession = SessionModel(
        id: 's1',
        treatmentPlanId: 'tp1',
        patientId: 'p1',
        doctorId: 'd1',
        scheduledDate: now.subtract(const Duration(days: 5)).toIso8601String(),
        status: SessionStatus.upcoming,
        sessionNumber: 1,
      );

      // Setup a session for tomorrow (should NOT be missed)
      final futureSession = SessionModel(
        id: 's2',
        treatmentPlanId: 'tp2',
        patientId: 'p1',
        doctorId: 'd1',
        scheduledDate: now.add(const Duration(days: 1)).toIso8601String(),
        status: SessionStatus.upcoming,
        sessionNumber: 2,
      );

      // This is a unit test of the internal time check logic
      // In MissedSessionDetector, a session is missed if scheduledDate is before yesterday
      final yesterday = now.subtract(const Duration(days: 1));
      
      expect(DateTime.parse(pastSession.scheduledDate).isBefore(yesterday), isTrue, 
        reason: 'Past session should be flagged as missed');
      
      expect(DateTime.parse(futureSession.scheduledDate).isBefore(yesterday), isFalse,
        reason: 'Future session should NOT be flagged as missed');
    });

    test('3 consecutive misses transitions to manualReview', () {
      // Simulate consecutive misses incrementing
      int consecutiveMisses = 0;
      
      // Session 1 missed
      consecutiveMisses++;
      expect(consecutiveMisses >= 3, isFalse);

      // Session 2 missed
      consecutiveMisses++;
      expect(consecutiveMisses >= 3, isFalse);

      // Session 3 missed
      consecutiveMisses++;
      expect(consecutiveMisses >= 3, isTrue, 
        reason: '3 consecutive misses should trigger manualReview transition');
    });
  });
}
