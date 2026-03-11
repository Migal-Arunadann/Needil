import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/treatment_service.dart';
import '../models/treatment_plan_model.dart';
import '../models/session_model.dart';

/// Provides the [TreatmentService] singleton.
final treatmentServiceProvider = Provider<TreatmentService>((ref) {
  final pb = ref.watch(pocketbaseProvider);
  return TreatmentService(pb);
});

// ─── Treatment Plans State ───────────────────────────────────

class TreatmentPlansState {
  final bool isLoading;
  final List<TreatmentPlanModel> plans;
  final String? error;

  const TreatmentPlansState({
    this.isLoading = false,
    this.plans = const [],
    this.error,
  });

  TreatmentPlansState copyWith({
    bool? isLoading,
    List<TreatmentPlanModel>? plans,
    String? error,
  }) {
    return TreatmentPlansState(
      isLoading: isLoading ?? this.isLoading,
      plans: plans ?? this.plans,
      error: error,
    );
  }
}

class TreatmentPlansNotifier extends StateNotifier<TreatmentPlansState> {
  final TreatmentService _service;

  TreatmentPlansNotifier(this._service) : super(const TreatmentPlansState());

  Future<void> loadDoctorPlans(String doctorId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final plans = await _service.getDoctorPlans(doctorId);
      state = state.copyWith(isLoading: false, plans: plans);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadPatientPlans(String patientId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final plans = await _service.getPatientPlans(patientId);
      state = state.copyWith(isLoading: false, plans: plans);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<TreatmentPlanModel?> createPlan({
    required String patientId,
    required String doctorId,
    String? consultationId,
    required String treatmentType,
    required String startDate,
    required int totalSessions,
    required int intervalDays,
    required double sessionFee,
  }) async {
    try {
      final plan = await _service.createTreatmentPlan(
        patientId: patientId,
        doctorId: doctorId,
        consultationId: consultationId,
        treatmentType: treatmentType,
        startDate: startDate,
        totalSessions: totalSessions,
        intervalDays: intervalDays,
        sessionFee: sessionFee,
      );
      state = state.copyWith(plans: [plan, ...state.plans]);
      return plan;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

final treatmentPlansProvider =
    StateNotifierProvider<TreatmentPlansNotifier, TreatmentPlansState>((ref) {
  final service = ref.watch(treatmentServiceProvider);
  return TreatmentPlansNotifier(service);
});

// ─── Sessions State ──────────────────────────────────────────

class SessionsState {
  final bool isLoading;
  final List<SessionModel> sessions;
  final String? error;

  const SessionsState({
    this.isLoading = false,
    this.sessions = const [],
    this.error,
  });

  SessionsState copyWith({
    bool? isLoading,
    List<SessionModel>? sessions,
    String? error,
  }) {
    return SessionsState(
      isLoading: isLoading ?? this.isLoading,
      sessions: sessions ?? this.sessions,
      error: error,
    );
  }
}

class SessionsNotifier extends StateNotifier<SessionsState> {
  final TreatmentService _service;

  SessionsNotifier(this._service) : super(const SessionsState());

  Future<void> loadPlanSessions(String planId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sessions = await _service.getPlanSessions(planId);
      state = state.copyWith(isLoading: false, sessions: sessions);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<SessionModel?> recordSession({
    required String sessionId,
    String? notes,
    String? bpLevel,
    int? pulse,
    String? remarks,
    List<String> photoPaths = const [],
  }) async {
    try {
      final session = await _service.recordSession(
        sessionId: sessionId,
        notes: notes,
        bpLevel: bpLevel,
        pulse: pulse,
        remarks: remarks,
        photoPaths: photoPaths,
      );
      // Update the session in the list
      final updated = state.sessions.map((s) {
        return s.id == sessionId ? session : s;
      }).toList();
      state = state.copyWith(sessions: updated);
      return session;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> markMissed(String sessionId) async {
    try {
      await _service.markSessionMissed(sessionId);
      final updated = state.sessions.map((s) {
        if (s.id == sessionId) {
          return SessionModel(
            id: s.id,
            treatmentPlanId: s.treatmentPlanId,
            patientId: s.patientId,
            doctorId: s.doctorId,
            sessionNumber: s.sessionNumber,
            scheduledDate: s.scheduledDate,
            scheduledTime: s.scheduledTime,
            status: SessionStatus.missed,
          );
        }
        return s;
      }).toList();
      state = state.copyWith(sessions: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, SessionsState>((ref) {
  final service = ref.watch(treatmentServiceProvider);
  return SessionsNotifier(service);
});
