import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/auth_service.dart';
import '../models/clinic_model.dart';
import '../models/doctor_model.dart';
import '../models/receptionist_model.dart';

/// Provides the [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return AuthService(pb);
});

/// Auth state that holds the current user info.
class AuthState {
  final bool isInitializing;
  final bool isLoading;
  final bool isAuthenticated;
  final UserRole? role;
  final ClinicModel? clinic;
  final DoctorModel? doctor;
  final ReceptionistModel? receptionist;
  final String? error;

  const AuthState({
    this.isInitializing = true,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.role,
    this.clinic,
    this.doctor,
    this.receptionist,
    this.error,
  });

  AuthState copyWith({
    bool? isInitializing,
    bool? isLoading,
    bool? isAuthenticated,
    UserRole? role,
    ClinicModel? clinic,
    DoctorModel? doctor,
    ReceptionistModel? receptionist,
    String? error,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      clinic: clinic ?? this.clinic,
      doctor: doctor ?? this.doctor,
      receptionist: receptionist ?? this.receptionist,
      error: error,
    );
  }

  /// Convenience getter for the current user's PocketBase record ID.
  String? get userId => clinic?.id ?? doctor?.id ?? receptionist?.id;

  /// The clinic ID this user belongs to (works for all roles).
  String? get clinicId {
    if (role == UserRole.clinic) return clinic?.id;
    if (role == UserRole.doctor) return doctor?.clinicId;
    if (role == UserRole.receptionist) return receptionist?.clinicId;
    return null;
  }
}

/// Manages authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  /// Try to restore a previous session on app start.
  Future<void> restoreSession() async {
    state = state.copyWith(isInitializing: true);
    final result = await _authService.restoreSession();

    if (result != null && result.success) {
      state = AuthState(
        isInitializing: false,
        isAuthenticated: true,
        role: result.role,
        clinic: result.role == UserRole.clinic ? result.user as ClinicModel : null,
        doctor: result.role == UserRole.doctor ? result.user as DoctorModel : null,
        receptionist: result.role == UserRole.receptionist ? result.user as ReceptionistModel : null,
      );
    } else {
      state = const AuthState(isInitializing: false);
    }
  }

  /// Login as clinic.
  Future<void> loginClinic(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _authService.loginClinic(username, password);

    if (result.success) {
      state = AuthState(
        isInitializing: false,
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
        isInitializing: false,
        isAuthenticated: true,
        role: UserRole.doctor,
        doctor: result.user as DoctorModel,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Login as receptionist.
  Future<void> loginReceptionist(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _authService.loginReceptionist(username, password);

    if (result.success) {
      state = AuthState(
        isInitializing: false,
        isAuthenticated: true,
        role: UserRole.receptionist,
        receptionist: result.user as ReceptionistModel,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Register a clinic with primary doctor + optional additional doctors + optional receptionist.
  Future<void> registerClinic({
    required String clinicName,
    required String username,
    required String password,
    required int bedCount,
    required Map<String, dynamic> primaryDoctorData,
    File? doctorPhotoFile,
    List<Map<String, dynamic>>? additionalDoctors,
    Map<String, dynamic>? receptionistData,
    String? city,
    String? area,
    String? stateField,
    String? pincode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.registerClinic(
      clinicName: clinicName,
      username: username,
      password: password,
      bedCount: bedCount,
      primaryDoctorData: primaryDoctorData,
      doctorPhotoFile: doctorPhotoFile,
      additionalDoctors: additionalDoctors,
      receptionistData: receptionistData,
      city: city,
      area: area,
      state: stateField,
      pincode: pincode,
    );

    if (result.success) {
      state = AuthState(
        isInitializing: false,
        isAuthenticated: true,
        role: UserRole.clinic,
        clinic: result.user as ClinicModel,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Logout.
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(isInitializing: false);
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
