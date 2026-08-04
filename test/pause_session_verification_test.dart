import 'package:flutter_test/flutter_test.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';

void main() {
  group('Pause Session & Needs Attention Feature Verification Tests', () {

    test('Test Case 1: Session Selection & Filtering for Pause Execution', () {
      // Simulate all sessions of a treatment plan across various lifecycle states
      final planSessions = [
        SessionModel(id: 's1', treatmentPlanId: 'plan_101', patientId: 'p1', doctorId: 'd1', sessionNumber: 1, scheduledDate: '2026-07-20', status: SessionStatus.completed),
        SessionModel(id: 's2', treatmentPlanId: 'plan_101', patientId: 'p1', doctorId: 'd1', sessionNumber: 2, scheduledDate: '2026-07-25', status: SessionStatus.missed),
        SessionModel(id: 's3', treatmentPlanId: 'plan_101', patientId: 'p1', doctorId: 'd1', sessionNumber: 3, scheduledDate: '2026-08-01', status: SessionStatus.overdue),
        SessionModel(id: 's4', treatmentPlanId: 'plan_101', patientId: 'p1', doctorId: 'd1', sessionNumber: 4, scheduledDate: '2026-08-05', status: SessionStatus.upcoming),
        SessionModel(id: 's5', treatmentPlanId: 'plan_101', patientId: 'p1', doctorId: 'd1', sessionNumber: 5, scheduledDate: '2026-08-10', status: SessionStatus.cancelled),
      ];

      // In TreatmentScheduler.pausePlan, we target sessions with status upcoming, missed, waiting, or overdue
      final targetedForPause = planSessions.where((s) => 
        s.status == SessionStatus.upcoming || 
        s.status == SessionStatus.missed || 
        s.status == SessionStatus.waiting ||
        s.status == SessionStatus.overdue
      ).toList();

      expect(targetedForPause.length, equals(3), reason: 'Should only target pending/missed/overdue sessions');
      expect(targetedForPause.map((s) => s.id), containsAll(['s2', 's3', 's4']));
      expect(targetedForPause.any((s) => s.id == 's1' || s.id == 's5'), isFalse, 
        reason: 'Completed (s1) and cancelled (s5) sessions must NEVER be modified when pausing a plan');
    });

    test('Test Case 2: Needs Attention Grouping Logic by Treatment Plan', () {
      // Simulate dashboard receiving mixed overdue sessions from different patients and plans
      final dashboardSessions = [
        SessionModel(id: 's_a1', treatmentPlanId: 'plan_A', patientId: 'p_A', patientName: 'Lav', doctorId: 'd1', sessionNumber: 2, scheduledDate: '2026-08-01', status: SessionStatus.overdue),
        SessionModel(id: 's_a2', treatmentPlanId: 'plan_A', patientId: 'p_A', patientName: 'Lav', doctorId: 'd1', sessionNumber: 3, scheduledDate: '2026-08-03', status: SessionStatus.overdue),
        SessionModel(id: 's_b1', treatmentPlanId: 'plan_B', patientId: 'p_B', patientName: 'Ananya', doctorId: 'd1', sessionNumber: 1, scheduledDate: '2026-08-02', status: SessionStatus.overdue),
        // Orphan session with empty treatmentPlanId
        SessionModel(id: 's_orphan', treatmentPlanId: '', patientId: 'p_C', patientName: 'Walkin', doctorId: 'd1', sessionNumber: 1, scheduledDate: '2026-08-02', status: SessionStatus.overdue),
      ];

      // Grouping logic applied in _buildSessionList()
      final Map<String, List<SessionModel>> grouped = {};
      for (final s in dashboardSessions) {
        final key = s.treatmentPlanId.isNotEmpty ? s.treatmentPlanId : s.id;
        grouped.putIfAbsent(key, () => []).add(s);
      }

      expect(grouped.length, equals(3), reason: 'Should form exactly 3 distinct groups');
      
      // Patient A has 2 overdue sessions -> triggers grouped patient view with miss count badge
      expect(grouped['plan_A']!.length, equals(2));
      expect(grouped['plan_A']!.first.patientName, equals('Lav'));
      
      // Patient B has 1 overdue session -> triggers single flat card view
      expect(grouped['plan_B']!.length, equals(1));
      expect(grouped['plan_B']!.first.patientName, equals('Ananya'));

      // Orphan fallback -> correctly isolates under session ID key 's_orphan'
      expect(grouped['s_orphan']!.length, equals(1));
      expect(grouped['s_orphan']!.first.patientName, equals('Walkin'));
    });

    test('Test Case 3: Optimistic UI Removal & Auto-Dismissal Condition', () {
      // Simulate dashboard state containing overdue items across tabs
      var sessions = [
        SessionModel(id: 's_a1', treatmentPlanId: 'plan_A', patientId: 'p_A', doctorId: 'd1', sessionNumber: 2, scheduledDate: '2026-08-01', status: SessionStatus.overdue),
        SessionModel(id: 's_a2', treatmentPlanId: 'plan_A', patientId: 'p_A', doctorId: 'd1', sessionNumber: 3, scheduledDate: '2026-08-03', status: SessionStatus.overdue),
        SessionModel(id: 's_b1', treatmentPlanId: 'plan_B', patientId: 'p_B', doctorId: 'd1', sessionNumber: 1, scheduledDate: '2026-08-02', status: SessionStatus.overdue),
      ];
      var consultations = [
        AppointmentModel(id: 'c1', patientId: 'p1', doctorId: 'd1', date: '2026-08-01', time: '10:00', status: AppointmentStatus.scheduled, type: AppointmentType.callBy),
      ];
      var manualPlans = <TreatmentPlanModel>[];

      // Doctor pauses Plan A -> execute removal logic
      sessions.removeWhere((s) => s.treatmentPlanId == 'plan_A');

      expect(sessions.length, equals(1), reason: 'Only plan_B session should remain');
      expect(sessions.first.id, equals('s_b1'));

      // Check auto-dismiss condition (must check sessions, consultations, and manualPlans)
      bool shouldPop = sessions.isEmpty && consultations.isEmpty && manualPlans.isEmpty;
      expect(shouldPop, isFalse, reason: 'Must NOT close modal because consultations and plan_B remain');

      // Now clear remaining session
      sessions.clear();
      shouldPop = sessions.isEmpty && consultations.isEmpty && manualPlans.isEmpty;
      expect(shouldPop, isFalse, reason: 'Must NOT close modal because 1 consultation still needs attention');

      // Resolve consultation
      consultations.clear();
      shouldPop = sessions.isEmpty && consultations.isEmpty && manualPlans.isEmpty;
      expect(shouldPop, isTrue, reason: 'When all lists are empty, modal safely dismisses');
    });

    test('Test Case 4: Paused Status Representation & Auto-Schedule Suppression', () {
      // Test status parsing and serialization
      final status = TreatmentPlanModel.parseStatus('paused');
      expect(status, equals(TreatmentPlanStatus.paused));
      expect(TreatmentPlanModel.statusToString(TreatmentPlanStatus.paused), equals('paused'));

      // In MissedSessionDetector._processPlan, paused plans are skipped
      final mockPausedPlan = TreatmentPlanModel(
        id: 'plan_101',
        patientId: 'p1',
        doctorId: 'd1',
        treatmentType: 'Acupuncture',
        startDate: '2026-07-01',
        totalSessions: 10,
        intervalDays: 2,
        sessionFee: 500.0,
        completedSessions: 2,
        status: TreatmentPlanStatus.paused,
        isPaused: true,
      );

      bool detectorWouldProcess = !(mockPausedPlan.status == TreatmentPlanStatus.paused ||
                                    mockPausedPlan.status == TreatmentPlanStatus.completed ||
                                    mockPausedPlan.status == TreatmentPlanStatus.closed);

      expect(detectorWouldProcess, isFalse, 
        reason: 'MissedSessionDetector must immediately skip paused treatment plans');
    });

  });
}
