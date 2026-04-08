import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';
import '../constants/pb_collections.dart';
import '../../features/auth/models/clinic_model.dart';
import '../../features/auth/models/doctor_model.dart';
import '../../features/auth/models/receptionist_model.dart';

enum UserRole { clinic, doctor, receptionist }

class AuthResult {
  final bool success;
  final String? error;
  final UserRole? role;
  final dynamic user; // ClinicModel, DoctorModel, or ReceptionistModel

  AuthResult({required this.success, this.error, this.role, this.user});
}

/// Result from an OTP request — carries the otpId needed for verification.
class OtpResult {
  final bool success;
  final String? error;
  final String? otpId;
  OtpResult({required this.success, this.error, this.otpId});
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
      final userId = await _storage.read(key: _userIdKey);

      if (role == null || token == null || userId == null) return null;

      String collection;
      switch (role) {
        case 'clinic':
          collection = PBCollections.clinics;
          break;
        case 'doctor':
          collection = PBCollections.doctors;
          break;
        case 'receptionist':
          collection = PBCollections.receptionists;
          break;
        default:
          return null;
      }

      // Inject saved token before refresh
      pb.authStore.save(token, null);
      final result = await pb.collection(collection).authRefresh();
      await _saveSession(role, result.token, result.record.id);

      switch (role) {
        case 'clinic':
          return AuthResult(
            success: true,
            role: UserRole.clinic,
            user: ClinicModel.fromRecord(result.record),
          );
        case 'doctor':
          return AuthResult(
            success: true,
            role: UserRole.doctor,
            user: DoctorModel.fromRecord(result.record),
          );
        case 'receptionist':
          return AuthResult(
            success: true,
            role: UserRole.receptionist,
            user: ReceptionistModel.fromRecord(result.record),
          );
        default:
          return null;
      }
    } catch (e) {
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
      return AuthResult(success: false, error: _parseError(e));
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
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred');
    }
  }

  /// Login as receptionist.
  /// PocketBase's receptionists collection uses email as the identity field,
  /// so we derive the same dummy email we created the record with.
  Future<AuthResult> loginReceptionist(String username, String password) async {
    try {
      // Derive the stored dummy email from the username
      final safe = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      final email = '$safe@pms.local';

      final result = await pb
          .collection(PBCollections.receptionists)
          .authWithPassword(email, password);

      await _saveSession('receptionist', result.token, result.record.id);

      final receptionist = ReceptionistModel.fromRecord(result.record);

      // Check if account is active
      if (!receptionist.isActive) {
        pb.authStore.clear();
        await _clearStorage();
        return AuthResult(
          success: false,
          error: 'This receptionist account has been deactivated. Contact your clinic administrator.',
        );
      }

      return AuthResult(
        success: true,
        role: UserRole.receptionist,
        user: receptionist,
      );
    } on ClientException catch (e) {
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred');
    }
  }

  /// Register a new clinic with its primary doctor, optional additional doctors,
  /// and optional receptionist account.
  Future<AuthResult> registerClinic({
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
    String? state,
    String? pincode,
    String? clinicEmail, // real email from registration; falls back to dummy if null
  }) async {
    try {
      // Generate unique clinic ID (6 chars)
      final clinicCode = _generateUniqueId(6);

      // ── 1. Create clinic record ──
      final clinicBody = {
        'name': clinicName,
        'username': username,
        'email': clinicEmail ?? _fakeEmail(username),
        'emailVisibility': clinicEmail != null,
        'password': password,
        'passwordConfirm': password,
        'bed_count': bedCount,
        'clinic_id': clinicCode,
        'subscription_tier': 'free',
        'max_doctors': 1,
        if (city != null && city.isNotEmpty) 'city': city,
        if (area != null && area.isNotEmpty) 'area': area,
        if (state != null && state.isNotEmpty) 'state': state,
        if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
      };

      final clinicRecord = await pb
          .collection(PBCollections.clinics)
          .create(body: clinicBody);

      // ── 2. Authenticate as the clinic immediately ──
      final loginResult = await pb
          .collection(PBCollections.clinics)
          .authWithPassword(username, password);

      // ── 3. Primary Doctor ──
      final primaryDoctorId = _generateUniqueId(8, prefix: 'DR');
      final internalUsername = 'dr_${clinicCode.toLowerCase()}';
      final internalPassword = '${password}_dr_$clinicCode';

      final doctorBody = {
        ...primaryDoctorData,
        'username': internalUsername,
        'email': _fakeEmail(internalUsername),
        'emailVisibility': false,
        'password': internalPassword,
        'passwordConfirm': internalPassword,
        'clinic': clinicRecord.id,
        'is_primary': true,
        'doctor_id': primaryDoctorId,
      };
      doctorBody.remove('password_confirm');

      if (doctorPhotoFile != null) {
        final files = [
          await http.MultipartFile.fromPath('photo', doctorPhotoFile.path)
        ];
        await pb
            .collection(PBCollections.doctors)
            .create(body: doctorBody, files: files);
      } else {
        await pb.collection(PBCollections.doctors).create(body: doctorBody);
      }

      // ── 4. Additional Doctors ──
      if (additionalDoctors != null) {
        for (final docData in additionalDoctors) {
          final docId = _generateUniqueId(8, prefix: 'DR');
          final photoPath = docData['photo_path'] as String?;
          final docUsername = 'dr_${clinicCode.toLowerCase()}_$docId'.toLowerCase();
          final body = {
            ...docData,
            'username': docUsername,
            'email': _fakeEmail(docUsername),
            'emailVisibility': false,
            'passwordConfirm': docData['password'],
            'clinic': clinicRecord.id,
            'is_primary': false,
            'doctor_id': docId,
          };
          body.remove('photo_path');

          if (photoPath != null) {
            final files = [
              await http.MultipartFile.fromPath('photo', photoPath)
            ];
            await pb.collection(PBCollections.doctors).create(body: body, files: files);
          } else {
            await pb.collection(PBCollections.doctors).create(body: body);
          }
        }
      }

      // ── 5. Receptionist ──
      if (receptionistData != null) {
        final recId = _generateUniqueId(8, prefix: 'RC');
        final recUsername = (receptionistData['username'] as String?)?.trim() ?? '';
        final recPassword = (receptionistData['password'] as String?)?.trim() ?? '';
        final recBody = {
          'name': receptionistData['name'],
          'username': recUsername,
          'email': _fakeEmail(recUsername),
          'emailVisibility': false,
          'password': recPassword,
          'passwordConfirm': recPassword,
          'clinic': clinicRecord.id,
          'is_active': true,
          'receptionist_id': recId,
          if ((receptionistData['phone'] as String?)?.isNotEmpty == true)
            'phone': receptionistData['phone'],
        };
        await pb.collection(PBCollections.receptionists).create(body: recBody);
      }

      // ── 6. Save session (already authenticated) ──
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
    if (role == 'receptionist') return UserRole.receptionist;
    return null;
  }

  bool get isLoggedIn => pb.authStore.isValid;

  // ── OTP Methods ────────────────────────────────────────────────

  /// Request an OTP to be sent to [email] via PocketBase's built-in OTP system.
  /// Returns an [OtpResult] carrying the otpId needed for verification.
  Future<OtpResult> requestOtp(String email) async {
    try {
      final response = await pb
          .collection(PBCollections.clinics)
          .requestOTP(email);
      return OtpResult(success: true, otpId: response.otpId);
    } on ClientException catch (e) {
      return OtpResult(success: false, error: _parseError(e));
    } catch (_) {
      return OtpResult(
          success: false, error: 'Could not send OTP. Check your email address.');
    }
  }

  /// Verify an OTP code. On success the PocketBase auth store is updated.
  Future<AuthResult> verifyOtp({required String otpId, required String otpCode}) async {
    try {
      await pb
          .collection(PBCollections.clinics)
          .authWithOTP(otpId, otpCode);
      return AuthResult(success: true);
    } on ClientException catch (_) {
      return AuthResult(success: false, error: 'Invalid or expired code. Try again.');
    } catch (_) {
      return AuthResult(success: false, error: 'Verification failed. Please try again.');
    }
  }

  /// Verify OTP and immediately update the authenticated clinic's password.
  Future<AuthResult> verifyOtpAndResetPassword({
    required String otpId,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final authResult = await pb
          .collection(PBCollections.clinics)
          .authWithOTP(otpId, otpCode);
      // Now authenticated — update the password
      await pb.collection(PBCollections.clinics).update(
        authResult.record.id,
        body: {
          'password': newPassword,
          'passwordConfirm': newPassword,
          'oldPassword': otpCode, // PocketBase may not require this for OTP auth
        },
      );
      // Clear the session — user must log in fresh with new password
      pb.authStore.clear();
      await _clearStorage();
      return AuthResult(success: true);
    } on ClientException catch (e) {
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'Reset failed. Please try again.');
    }
  }

  // ── Generate unique ID ───────────────────────────────────────────
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

  /// Generate a unique alphanumeric ID.
  /// [length] is the total length of the random part.
  /// [prefix] is an optional prefix (e.g., 'DR', 'RC').
  String _generateUniqueId(int length, {String? prefix}) {
    const chars = 'ABCDEFGHIJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final random = List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
    if (prefix != null) return '$prefix$random';
    return random;
  }

  /// Derive a dummy email from a username so PocketBase email-required
  /// auth collections accept the record. Email is never used for login.
  String _fakeEmail(String username) {
    // Sanitise: lowercase, strip spaces/special chars
    final safe = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return '$safe@pms.local';
  }

  String _parseError(ClientException e) {
    try {
      final response = e.response;

      if (response.containsKey('data')) {
        final data = response['data'];
        if (data is Map && data.isNotEmpty) {
          final fieldErrors = data.entries
              .where((entry) =>
                  entry.value is Map &&
                  (entry.value as Map).containsKey('message'))
              .map((entry) =>
                  '${entry.key}: ${(entry.value as Map)['message']}')
              .join('\n');
          if (fieldErrors.isNotEmpty) return fieldErrors;
        }
      }

      if (response.containsKey('message')) {
        final msg = response['message'].toString();
        if (msg.contains('Failed to authenticate')) {
          return 'Invalid username or password';
        }
        return msg;
      }
    } catch (_) {}
    return 'Something went wrong. Please try again.';
  }
}
