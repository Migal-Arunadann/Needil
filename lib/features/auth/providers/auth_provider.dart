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

  // ── OTP pending state ──────────────────────────────────────
  /// The OTP ID returned by PocketBase after requestOTP.
  final String? pendingOtpId;
  /// The email the OTP was sent to.
  final String? pendingEmail;
  /// The full clinic registration payload, held while waiting for OTP.
  final Map<String, dynamic>? pendingClinicData;

  const AuthState({
    this.isInitializing = true,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.role,
    this.clinic,
    this.doctor,
    this.receptionist,
    this.error,
    this.pendingOtpId,
    this.pendingEmail,
    this.pendingClinicData,
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
    String? pendingOtpId,
    String? pendingEmail,
    Map<String, dynamic>? pendingClinicData,
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
      pendingOtpId: pendingOtpId ?? this.pendingOtpId,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      pendingClinicData: pendingClinicData ?? this.pendingClinicData,
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

  /// Universal login — tries clinic → doctor → receptionist automatically.
  /// The user never needs to know or select their role.
  Future<void> loginAny(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    // Try clinic first
    final clinicResult = await _authService.loginClinic(username, password);
    if (clinicResult.success) {
      state = AuthState(
        isInitializing: false,
        isAuthenticated: true,
        role: UserRole.clinic,
        clinic: clinicResult.user as ClinicModel,
      );
      return;
    }

    // Try doctor
    final doctorResult = await _authService.loginDoctor(username, password);
    if (doctorResult.success) {
      state = AuthState(
        isInitializing: false,
        isAuthenticated: true,
        role: UserRole.doctor,
        doctor: doctorResult.user as DoctorModel,
      );
      return;
    }

    // Try receptionist
    final recResult = await _authService.loginReceptionist(username, password);
    if (recResult.success) {
      state = AuthState(
        isInitializing: false,
        isAuthenticated: true,
        role: UserRole.receptionist,
        receptionist: recResult.user as ReceptionistModel,
      );
      return;
    }

    // All failed — show a generic message
    state = state.copyWith(
      isLoading: false,
      error: 'Invalid username or password.',
    );
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
    String? clinicEmail,
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
      clinicEmail: clinicEmail,
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

  /// Complete clinic registration using the empty clinic record
  Future<void> completeClinicRegistration({
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

    final clinicId = state.clinic?.id;
    if (clinicId == null) {
      state = state.copyWith(isLoading: false, error: 'Unauthorized to complete registration.');
      return;
    }

    final result = await _authService.completeClinicRegistrationPatch(
      recordId: clinicId,
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

  // ── OTP: Registration ──────────────────────────────────────

  /// Registration OTP flow (create-first, then verify):
  /// 1. We now just request OTP — since name and bed_count are optional, PocketBase
  ///    will create the account when they type in the OTP code.
  Future<void> requestRegistrationOtp({
    required String email,
    required Map<String, dynamic> clinicData,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final otpResult = await _authService.requestOtp(email);
    
    if (otpResult.success) {
      state = state.copyWith(
        isLoading: false,
        pendingEmail: email,
        pendingOtpId: otpResult.otpId,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: otpResult.error ?? 'Failed to send OTP.',
      );
    }
  }

  /// Step 2: Verify OTP after registration (email ownership verification only).
  /// Clinic is already created — just confirm the OTP code.
  Future<void> verifyRegistrationOtp({required String otpCode}) async {
    if (state.pendingOtpId == null) {
      // No OTP pending — already verified or skipped, just go to dashboard
      state = state.copyWith(pendingEmail: null, pendingClinicData: null);
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    final verified = await _authService.verifyOtp(
      otpId: state.pendingOtpId!,
      otpCode: otpCode,
    );
    if (verified.success) {
      // OTP verified — this implicitly creates and authenticates the clinic.
      final result = await _authService.restoreSession(); // Loads the newly created user into state

      state = AuthState(
        isInitializing: false,
        isLoading: false,
        isAuthenticated: true,
        role: result?.role,
        clinic: result?.user is ClinicModel ? result!.user : null,
        // Clear OTP pending fields
        pendingOtpId: null,
        pendingEmail: null,
        pendingClinicData: null,
      );
    } else {
      state = state.copyWith(isLoading: false, error: verified.error);
    }
  }

  /// Resend OTP for registration using the stored pending email.
  Future<void> resendRegistrationOtp() async {
    if (state.pendingEmail == null) return;
    final result = await _authService.requestOtp(state.pendingEmail!);
    if (result.success) {
      state = state.copyWith(pendingOtpId: result.otpId);
    } else {
      state = state.copyWith(error: result.error);
    }
  }

  // ── OTP: Forgot Password ───────────────────────────────────

  /// Send OTP to a clinic email for password reset.
  Future<void> requestForgotPasswordOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _authService.requestOtp(email);
    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        pendingOtpId: result.otpId,
        pendingEmail: email,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  /// Verify OTP then update the clinic password.
  Future<void> verifyOtpAndResetPassword({
    required String otpCode,
    required String newPassword,
  }) async {
    if (state.pendingOtpId == null) {
      state = state.copyWith(error: 'Session expired. Please try again.');
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    final result = await _authService.verifyOtpAndResetPassword(
      otpId: state.pendingOtpId!,
      otpCode: otpCode,
      newPassword: newPassword,
    );
    if (result.success) {
      state = state.copyWith(isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }
}

/// The main auth state provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(authService);
});
