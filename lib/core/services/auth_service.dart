import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';
import '../constants/pb_collections.dart';
import '../../features/auth/models/clinic_model.dart';
import '../../features/auth/models/doctor_model.dart';

enum UserRole { clinic, doctor }

class AuthResult {
  final bool success;
  final String? error;
  final UserRole? role;
  final dynamic user; // ClinicModel or DoctorModel

  AuthResult({required this.success, this.error, this.role, this.user});
}

class AuthService {
  final PocketBase pb;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _roleKey = 'user_role';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  AuthService(this.pb);

  /// Check if user is logged in and restore session.
  Future<AuthResult?> restoreSession() async {
    try {
      final role = await _storage.read(key: _roleKey);
      final token = await _storage.read(key: _tokenKey);

      if (role == null || token == null) return null;

      final collection = role == 'clinic'
          ? PBCollections.clinics
          : PBCollections.doctors;

      // Try to refresh the auth
      final result = await pb.collection(collection).authRefresh();

      if (role == 'clinic') {
        return AuthResult(
          success: true,
          role: UserRole.clinic,
          user: ClinicModel.fromRecord(result.record),
        );
      } else {
        return AuthResult(
          success: true,
          role: UserRole.doctor,
          user: DoctorModel.fromRecord(result.record),
        );
      }
    } catch (e) {
      // Token expired or invalid — clear stored data
      await _clearStorage();
      return null;
    }
  }

  /// Login as clinic.
  Future<AuthResult> loginClinic(String username, String password) async {
    try {
      final result = await pb.collection(PBCollections.clinics).authWithPassword(
        username,
        password,
      );

      await _saveSession('clinic', result.token, result.record.id);

      return AuthResult(
        success: true,
        role: UserRole.clinic,
        user: ClinicModel.fromRecord(result.record),
      );
    } on ClientException catch (e) {
      return AuthResult(
        success: false,
        error: _parseError(e),
      );
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred');
    }
  }

  /// Login as doctor.
  Future<AuthResult> loginDoctor(String username, String password) async {
    try {
      final result = await pb.collection(PBCollections.doctors).authWithPassword(
        username,
        password,
      );

      await _saveSession('doctor', result.token, result.record.id);

      return AuthResult(
        success: true,
        role: UserRole.doctor,
        user: DoctorModel.fromRecord(result.record),
      );
    } on ClientException catch (e) {
      return AuthResult(
        success: false,
        error: _parseError(e),
      );
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred');
    }
  }

  /// Register a new clinic with its primary doctor.
  Future<AuthResult> registerClinic({
    required String clinicName,
    required String username,
    required String password,
    required int bedCount,
    required Map<String, dynamic> primaryDoctorData,
  }) async {
    try {
      // Generate unique clinic ID (6 chars)
      final clinicCode = _generateClinicId();

      // Create clinic record
      final clinicBody = {
        'name': clinicName,
        'username': username,
        'password': password,
        'passwordConfirm': password,
        'bed_count': bedCount,
        'clinic_id': clinicCode,
      };

      final clinicRecord = await pb
          .collection(PBCollections.clinics)
          .create(body: clinicBody);

      // Create primary doctor linked to this clinic
      final doctorBody = {
        ...primaryDoctorData,
        'password': primaryDoctorData['password'],
        'passwordConfirm': primaryDoctorData['password'],
        'clinic': clinicRecord.id,
        'is_primary': true,
      };

      await pb.collection(PBCollections.doctors).create(body: doctorBody);

      // Login as the clinic
      final loginResult = await pb
          .collection(PBCollections.clinics)
          .authWithPassword(username, password);

      await _saveSession('clinic', loginResult.token, loginResult.record.id);

      return AuthResult(
        success: true,
        role: UserRole.clinic,
        user: ClinicModel.fromRecord(loginResult.record),
      );
    } on ClientException catch (e) {
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Registration failed: ${e.toString()}',
      );
    }
  }

  /// Register a new doctor (individual or joining a clinic).
  Future<AuthResult> registerDoctor({
    required String name,
    required int age,
    required String username,
    required String password,
    required List<Map<String, dynamic>> workingSchedule,
    required List<Map<String, dynamic>> treatments,
    String? clinicCode,
  }) async {
    try {
      String? clinicRecordId;

      // If joining a clinic, find the clinic by its code
      if (clinicCode != null && clinicCode.isNotEmpty) {
        final clinics = await pb.collection(PBCollections.clinics).getList(
          filter: 'clinic_id = "$clinicCode"',
          perPage: 1,
        );
        if (clinics.items.isEmpty) {
          return AuthResult(
            success: false,
            error: 'No clinic found with ID "$clinicCode"',
          );
        }
        clinicRecordId = clinics.items.first.id;
      }

      final body = {
        'name': name,
        'age': age,
        'username': username,
        'password': password,
        'passwordConfirm': password,
        'working_schedule': workingSchedule,
        'treatments': treatments,
        'is_primary': false,
        'share_past_patients': false,
        'share_future_patients': false,
        if (clinicRecordId != null) 'clinic': clinicRecordId,
      };

      await pb.collection(PBCollections.doctors).create(body: body);

      // Login as the doctor
      final loginResult = await pb
          .collection(PBCollections.doctors)
          .authWithPassword(username, password);

      await _saveSession('doctor', loginResult.token, loginResult.record.id);

      return AuthResult(
        success: true,
        role: UserRole.doctor,
        user: DoctorModel.fromRecord(loginResult.record),
      );
    } on ClientException catch (e) {
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Registration failed: ${e.toString()}',
      );
    }
  }

  /// Logout and clear session.
  Future<void> logout() async {
    pb.authStore.clear();
    await _clearStorage();
  }

  /// Get current user role from storage.
  Future<UserRole?> getCurrentRole() async {
    final role = await _storage.read(key: _roleKey);
    if (role == 'clinic') return UserRole.clinic;
    if (role == 'doctor') return UserRole.doctor;
    return null;
  }

  bool get isLoggedIn => pb.authStore.isValid;

  // --- Private helpers ---

  Future<void> _saveSession(String role, String token, String userId) async {
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<void> _clearStorage() async {
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
  }

  String _generateClinicId() {
    const chars = 'ABCDEFGHIJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _parseError(ClientException e) {
    if (e.response.containsKey('message')) {
      final msg = e.response['message'];
      if (msg.toString().contains('Failed to authenticate')) {
        return 'Invalid username or password';
      }
      return msg.toString();
    }
    if (e.response.containsKey('data')) {
      final data = e.response['data'] as Map<String, dynamic>;
      final errors = data.entries
          .where((e) => e.value is Map && (e.value as Map).containsKey('message'))
          .map((e) => (e.value as Map)['message'])
          .join(', ');
      if (errors.isNotEmpty) return errors;
    }
    return 'Something went wrong. Please try again.';
  }
}
