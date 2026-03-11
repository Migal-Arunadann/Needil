import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/auth_service.dart';
import '../models/clinic_model.dart';
import '../models/doctor_model.dart';

/// Provides the [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return AuthService(pb);
});

/// Auth state that holds the current user info.
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserRole? role;
  final ClinicModel? clinic;
  final DoctorModel? doctor;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.role,
    this.clinic,
    this.doctor,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserRole? role,
    ClinicModel? clinic,
    DoctorModel? doctor,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      clinic: clinic ?? this.clinic,
      doctor: doctor ?? this.doctor,
      error: error,
    );
  }
}

/// Manages authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  /// Try to restore a previous session on app start.
  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true);
    final result = await _authService.restoreSession();

    if (result != null && result.success) {
      state = AuthState(
        isAuthenticated: true,
        role: result.role,
        clinic: result.role == UserRole.clinic ? result.user as ClinicModel : null,
        doctor: result.role == UserRole.doctor ? result.user as DoctorModel : null,
      );
    } else {
      state = const AuthState();
    }
  }

  /// Login as clinic.
  Future<void> loginClinic(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.loginClinic(username, password);

    if (result.success) {
      state = AuthState(
        isAuthenticated: true,
        role: UserRole.clinic,
        clinic: result.user as ClinicModel,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Login as doctor.
  Future<void> loginDoctor(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.loginDoctor(username, password);

    if (result.success) {
      state = AuthState(
        isAuthenticated: true,
        role: UserRole.doctor,
        doctor: result.user as DoctorModel,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Register a clinic with primary doctor.
  Future<void> registerClinic({
    required String clinicName,
    required String username,
    required String password,
    required int bedCount,
    required Map<String, dynamic> primaryDoctorData,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.registerClinic(
      clinicName: clinicName,
      username: username,
      password: password,
      bedCount: bedCount,
      primaryDoctorData: primaryDoctorData,
    );

    if (result.success) {
      state = AuthState(
        isAuthenticated: true,
        role: UserRole.clinic,
        clinic: result.user as ClinicModel,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Register a doctor.
  Future<void> registerDoctor({
    required String name,
    required int age,
    required String username,
    required String password,
    required List<Map<String, dynamic>> workingSchedule,
    required List<Map<String, dynamic>> treatments,
    String? clinicCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.registerDoctor(
      name: name,
      age: age,
      username: username,
      password: password,
      workingSchedule: workingSchedule,
      treatments: treatments,
      clinicCode: clinicCode,
    );

    if (result.success) {
      state = AuthState(
        isAuthenticated: true,
        role: UserRole.doctor,
        doctor: result.user as DoctorModel,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Logout.
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }

  /// Clear error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// The main auth state provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(authService);
});
