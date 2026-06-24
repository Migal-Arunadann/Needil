import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/patients/services/patient_service.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

final patientServiceProvider = Provider<PatientService>((ref) {
  final pb = ref.watch(pocketbaseProvider);
  return PatientService(pb);
});

class PatientListState {
  final bool isLoading;
  final List<PatientModel> patients;
  final Map<String, DateTime> lastVisitDates;
  final String? error;

  const PatientListState({
    this.isLoading = false,
    this.patients = const [],
    this.lastVisitDates = const {},
    this.error,
  });

  PatientListState copyWith({
    bool? isLoading,
    List<PatientModel>? patients,
    Map<String, DateTime>? lastVisitDates,
    String? error,
  }) {
    return PatientListState(
      isLoading: isLoading ?? this.isLoading,
      patients: patients ?? this.patients,
      lastVisitDates: lastVisitDates ?? this.lastVisitDates,
      error: error,
    );
  }
}

class PatientListNotifier extends StateNotifier<PatientListState> {
  final PatientService _service;
  final AuthState _authState;

  PatientListNotifier(this._service, this._authState) : super(const PatientListState()) {
    loadPatients();
  }

  Future<void> loadPatients() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      List<PatientModel> result = [];
      
      final userId = _authState.userId;
      if (userId == null) {
        state = state.copyWith(isLoading: false, patients: [], lastVisitDates: {});
        return;
      }

      if (_authState.role == UserRole.clinic) {
        result = await _service.getClinicPatients(userId);
      } else if (_authState.role == UserRole.doctor) {
        result = await _service.getDoctorPatients(userId);
      }

      // Fetch last completed appointment dates for all patients in batch
      final patientIds = result.map((p) => p.id).toList();
      final lastVisits = await _service.getLastVisitDates(patientIds);

      state = state.copyWith(
        isLoading: false,
        patients: result,
        lastVisitDates: lastVisits,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final patientListProvider = StateNotifierProvider<PatientListNotifier, PatientListState>((ref) {
  final service = ref.watch(patientServiceProvider);
  final authState = ref.watch(authProvider);
  return PatientListNotifier(service, authState);
});
