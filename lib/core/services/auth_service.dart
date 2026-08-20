import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/auth/models/clinic_model.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import 'package:pms_app/features/auth/models/receptionist_model.dart';

enum UserRole { clinic, doctor, receptionist, superadmin }

class AuthResult {
  final bool success;
  final String? error;
  final UserRole? role;
  final dynamic user; // ClinicModel, DoctorModel, or ReceptionistModel
  /// True when a clinic is in 'pending_deletion' state — login still succeeds.
  final bool isPendingDeletion;
  final DateTime? purgeAt;

  AuthResult({
    required this.success,
    this.error,
    this.role,
    this.user,
    this.isPendingDeletion = false,
    this.purgeAt,
  });
}

/// Result from an OTP request — carries the otpId needed for verification.
class OtpResult {
  final bool success;
  final String? error;
  final String? otpId;
  final String? mfaId;
  OtpResult({required this.success, this.error, this.otpId, this.mfaId});
}

class AuthService {
  final PocketBase pb;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _roleKey = 'user_role';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  Timer? _fileTokenTimer;

  AuthService(this.pb);

  Future<void> _startFileTokenRefresh() async {
    _fileTokenTimer?.cancel();
    await _refreshFileToken(); // Wait for the first token to be fetched
    _fileTokenTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _refreshFileToken();
    });
  }

  Future<void> _refreshFileToken() async {
    if (!pb.authStore.isValid) return;
    try {
      final res = await pb.send('/api/files/token', method: 'POST');
      ImageHelper.globalFileToken = res['token'];
    } catch (_) {}
  }

  /// Check if user is logged in and restore session.
  Future<AuthResult?> restoreSession() async {
    try {
      final role = await _storage.read(key: _roleKey);
      final token = await _storage.read(key: _tokenKey);
      final userId = await _storage.read(key: _userIdKey);

      if (role == null || token == null || userId == null) return null;

      // ── Superadmin session restore (raw HTTP refresh) ─────────
      if (role == 'superadmin') {
        final pbUrl = pb.baseURL;
        final res = await http.post(
          Uri.parse('$pbUrl/api/collections/_superusers/auth-refresh'),
          headers: {'Content-Type': 'application/json', 'Authorization': token},
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final newToken = body['token'] as String? ?? token;
          final recordId =
              (body['record'] as Map<String, dynamic>?)?['id'] as String? ??
              userId;
          await _saveSession('superadmin', newToken, recordId);
          final recordMap = body['record'] as Map<String, dynamic>?;
          final recordModel = recordMap != null ? RecordModel(recordMap) : null;
          pb.authStore.save(newToken, recordModel);
          return AuthResult(success: true, role: UserRole.superadmin);
        }
        // Token expired — clear storage
        await _clearStorage();
        return null;
      }

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
          final clinicRecord = result.record;
          final clinicStatus = clinicRecord.getStringValue('status');
          final clinicPurgeAt = DateTime.tryParse(clinicRecord.getStringValue('purge_at'));
          return AuthResult(
            success: true,
            role: UserRole.clinic,
            user: ClinicModel.fromRecord(clinicRecord),
            isPendingDeletion: clinicStatus == 'pending_deletion',
            purgeAt: clinicPurgeAt,
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

  HttpServer? _currentOAuthServer;

  /// Cancel any pending local OAuth server (e.g. if user returned to app without authenticating).
  void cancelOAuth() {
    try {
      _currentOAuthServer?.close(force: true);
    } catch (_) {}
    _currentOAuthServer = null;
  }

  /// Login as clinic.

  Future<Map<String, String>?> _runLocalOAuthServer() async {
    HttpServer? server;
    try {
      final authMethods = await pb.collection(PBCollections.clinics).listAuthMethods();
      final provider = authMethods.oauth2.providers.firstWhere((p) => p.name == 'google');

      server = await HttpServer.bind(InternetAddress.anyIPv4, 8080, shared: true);
      _currentOAuthServer = server;
      final redirectUrl = 'http://localhost:8080/callback';
      final state = _generateUniqueId(16);

      final authUrl = Uri.parse(provider.authURL + redirectUrl);
      final queryParams = Map<String, String>.from(authUrl.queryParameters);
      queryParams['state'] = state;
      final finalAuthUrl = authUrl.replace(queryParameters: queryParams);

      await launchUrl(finalAuthUrl, mode: LaunchMode.externalApplication);

      final request = await server.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('Google authentication timed out or was cancelled.'),
      );
      final query = request.uri.queryParameters;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Auth Successful</title>
    <style>
        body { font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background-color: #f8f9fa; color: #333; }
        h1 { font-size: 1.5rem; color: #4caf50; }
        p { color: #666; }
    </style>
</head>
<body>
    <h1>Authentication Successful!</h1>
    <p>You can safely close this browser and return to the app.</p>
</body>
</html>
''');
      await request.response.close();
      await server.close();
      _currentOAuthServer = null;

      if (query['state'] != state || query['code'] == null) {
        return null;
      }

      return {
        'code': query['code']!,
        'codeVerifier': provider.codeVerifier,
        'redirectUrl': redirectUrl,
      };
    } catch (e) {
      await server?.close(force: true);
      _currentOAuthServer = null;
      debugPrint('Local OAuth server error: $e');
      return null;
    }
  }

  /// Start Google OAuth login flow
  Future<AuthResult> loginWithGoogle() async {
    try {
      RecordAuth loginResult;
      
      // Generate a unique username to avoid PocketBase username collision on first-time OAuth registration
      final tempUsername = _generateUniqueId(10, prefix: 'clinic_');
      
      if (kIsWeb) {
        loginResult = await pb
            .collection(PBCollections.clinics)
            .authWithOAuth2('google', (url) async {
          final uri = Uri.parse(url.toString());
          try {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (e) {
            debugPrint('Could not launch URL: $e');
          }
        }, createData: {
          'username': tempUsername,
        });
      } else {
        final oauthData = await _runLocalOAuthServer();
        if (oauthData == null) {
          return AuthResult(success: false, error: 'Google login was cancelled or failed.');
        }

        // The OS often aborts network connections immediately after returning from an external browser.
        // We retry up to 3 times with a delay to allow the network layer to wake up.
        int retries = 3;
        while (true) {
          try {
            await Future.delayed(const Duration(milliseconds: 800));
            loginResult = await pb.collection(PBCollections.clinics).authWithOAuth2Code(
              'google',
              oauthData['code']!,
              oauthData['codeVerifier']!,
              oauthData['redirectUrl']!,
              createData: {
                'username': tempUsername,
              },
            );
            break; // Success
          } on ClientException catch (e) {
            if ((e.isAbort || e.statusCode == 0) && retries > 0) {
              retries--;
              debugPrint('Network abort caught, retrying... ($retries left)');
              continue;
            }
            rethrow;
          }
        }
      }
      
      await _saveSession('clinic', loginResult.token, loginResult.record.id);
      
      return AuthResult(
        success: true,
        role: UserRole.clinic,
        user: ClinicModel.fromRecord(loginResult.record),
      );
    } on ClientException catch (e) {
      debugPrint('ClientException in loginWithGoogle: ${e.response}');
      if (e.response['message']?.toString().contains('Failed to authenticate') == true) {
        return AuthResult(success: false, error: 'google_account_exists_unlinked');
      }
      if (e.statusCode == 400) {
        final data = e.response['data'] as Map<String, dynamic>?;
        if (data != null && data['email'] != null) {
            final emailError = data['email']['message']?.toString().toLowerCase() ?? '';
            if (emailError.contains('unique') || emailError.contains('already in use')) {
                 return AuthResult(success: false, error: 'google_account_exists_unlinked');
            }
        }
        return AuthResult(success: false, error: _parseError(e));
      }
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      debugPrint('Generic exception in loginWithGoogle: $e');
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Link Google account to existing user
  Future<AuthResult> linkGoogleAccount() async {
    try {
      final originalToken = pb.authStore.token;
      final originalModel = pb.authStore.model;
      final originalId = originalModel?.id;

      RecordAuth loginResult;

      if (kIsWeb) {
        loginResult = await pb
            .collection(PBCollections.clinics)
            .authWithOAuth2('google', (url) async {
          final uri = Uri.parse(url.toString());
          try {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (e) {
            debugPrint('Could not launch URL: $e');
          }
        });
      } else {
        final oauthData = await _runLocalOAuthServer();
        if (oauthData == null) {
          return AuthResult(success: false, error: 'Google link was cancelled or failed.');
        }

        int retries = 3;
        while (true) {
          try {
            await Future.delayed(const Duration(milliseconds: 800));
            loginResult = await pb.collection(PBCollections.clinics).authWithOAuth2Code(
              'google',
              oauthData['code']!,
              oauthData['codeVerifier']!,
              oauthData['redirectUrl']!,
            );
            break;
          } on ClientException catch (e) {
            if ((e.isAbort || e.statusCode == 0) && retries > 0) {
              retries--;
              debugPrint('Network abort caught, retrying... ($retries left)');
              continue;
            }
            rethrow;
          }
        }
      }
      
      if (loginResult.record.id != originalId) {
        pb.authStore.save(originalToken, originalModel);
        return AuthResult(success: false, error: 'This Google account is already linked to another clinic.');
      }
      
      await _saveSession('clinic', loginResult.token, loginResult.record.id);
      return AuthResult(success: true, role: UserRole.clinic, user: ClinicModel.fromRecord(loginResult.record));
      
    } catch (e) {
      debugPrint('Error linking Google account: $e');
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Complete the clinic registration for a Google OAuth user.
  Future<AuthResult> completeGoogleRegistrationPatch({
    required String recordId,
    required String clinicName,
    required String username,
    required int bedCount,
    required Map<String, dynamic> primaryDoctorData,
    File? doctorPhotoFile,
    List<Map<String, dynamic>>? additionalDoctors,
    Map<String, dynamic>? receptionistData,
    String? city,
    String? area,
    String? state,
    String? pincode,
  }) async {
    try {
      final clinicCode = _generateUniqueId(6);

      final profileBody = {
        'name': clinicName,
        'username': username,
        'bed_count': bedCount,
        'clinic_id': clinicCode,
        'subscription_tier': 'base',
        'photo_limit': 2000,
        'photos_used': 0,
        'max_doctors': 1,
        if (city != null && city.isNotEmpty) 'city': city,
        if (area != null && area.isNotEmpty) 'area': area,
        if (state != null && state.isNotEmpty) 'state': state,
        if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
      };

      final updatedClinic = await pb
          .collection(PBCollections.clinics)
          .update(recordId, body: profileBody);

      final primaryDoctorId = _generateUniqueId(8, prefix: 'DR');
      final internalUsername = 'dr_$clinicCode'.toLowerCase();
      final internalPassword = '${_generateUniqueId(8)}_dr_$clinicCode';

      final existingPrimary = await pb
          .collection(PBCollections.doctors)
          .getList(
            page: 1,
            perPage: 1,
            filter: 'clinic = "$recordId" && is_primary = true',
          );

      if (existingPrimary.items.isEmpty) {
        final doctorBody = {
          ...primaryDoctorData,
          'username': internalUsername,
          'email': _fakeEmail(internalUsername),
          'emailVisibility': false,
          'password': internalPassword,
          'passwordConfirm': internalPassword,
          'clinic': recordId,
          'is_primary': true,
          'is_active': true,
          'doctor_id': primaryDoctorId,
        };

        if (doctorPhotoFile != null) {
          final mPart = await http.MultipartFile.fromPath(
            'photo',
            doctorPhotoFile.path,
          );
          await pb
              .collection(PBCollections.doctors)
              .create(body: doctorBody, files: [mPart]);
        } else {
          await pb.collection(PBCollections.doctors).create(body: doctorBody);
        }
      }

      // ── 4. Additional Doctors ──
      if (additionalDoctors != null) {
        for (final docData in additionalDoctors) {
          final docId = _generateUniqueId(8, prefix: 'DR');
          final photoPath = docData['photo_path'] as String?;
          final docUsername =
              (docData['username'] as String?)?.trim().isNotEmpty == true
              ? docData['username'].toString().toLowerCase()
              : 'dr_${clinicCode.toLowerCase()}_$docId'.toLowerCase();
          final body = {
            ...docData,
            'username': docUsername,
            'email': _fakeEmail(docUsername),
            'emailVisibility': false,
            'passwordConfirm': docData['password'],
            'clinic': recordId,
            'is_primary': false,
            'is_active': true,
            'doctor_id': docId,
          };
          body.remove('photo_path');

          if (photoPath != null) {
            final files = [
              await http.MultipartFile.fromPath('photo', photoPath),
            ];
            await pb
                .collection(PBCollections.doctors)
                .create(body: body, files: files);
          } else {
            await pb.collection(PBCollections.doctors).create(body: body);
          }
        }
      }

      // ── 5. Receptionist ──
      if (receptionistData != null) {
        final recId = _generateUniqueId(8, prefix: 'RC');
        final recUsername =
            (receptionistData['username'] as String?)?.trim() ?? '';
        final recPassword =
            (receptionistData['password'] as String?)?.trim() ?? '';
        final recBody = {
          'name': receptionistData['name'],
          'username': recUsername,
          'email': _fakeEmail(recUsername),
          'emailVisibility': false,
          'password': recPassword,
          'passwordConfirm': recPassword,
          'clinic': recordId,
          'is_active': true,
          'receptionist_id': recId,
          if ((receptionistData['phone'] as String?)?.isNotEmpty == true)
            'phone': receptionistData['phone'],
        };
        await pb.collection(PBCollections.receptionists).create(body: recBody);
      }

      return AuthResult(
        success: true,
        role: UserRole.clinic,
        user: ClinicModel.fromRecord(updatedClinic),
      );
    } on ClientException catch (e) {
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Complete Google registration failed: $e',
      );
    }
  }

  Future<bool> hasGoogleAccount(String userId) async {
    try {
      final records = await pb.collection('_externalAuths').getFullList(
        filter: 'recordId = "$userId" && provider = "google"',
      );
      return records.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking google account: $e');
      return false;
    }
  }

  Future<bool> unlinkGoogleAccount(String userId) async {
    try {
      final records = await pb.collection('_externalAuths').getFullList(
        filter: 'recordId = "$userId" && provider = "google"',
      );
      for (final record in records) {
        await pb.collection('_externalAuths').delete(record.id);
      }
      return true;
    } catch (e) {
      debugPrint('Error unlinking google account: $e');
      return false;
    }
  }

  Future<AuthResult> loginClinic(String username, String password) async {
    try {
      final result = await pb
          .collection(PBCollections.clinics)
          .authWithPassword(username, password);

      // ── Block deactivated clinics ──────────────────────────────────────────
      // Check is_deactivated flag before creating a session.
      // This is a client-side gate; PocketBase API rules should also enforce this.
      final isDeactivated = result.record.getBoolValue('is_deactivated');
      if (isDeactivated) {
        // Clear the newly created auth session so no token persists
        pb.authStore.clear();
        final scheduledDate = result.record.getStringValue('scheduled_deletion_date');
        final dateStr = scheduledDate.isNotEmpty
            ? scheduledDate.substring(0, 10)
            : 'soon';
        return AuthResult(
          success: false,
          error: 'This clinic account has been deactivated. '
              'Scheduled for deletion on $dateStr. '
              'Contact support to reactivate.',
        );
      }

      // ── Check pending_deletion (self-requested) ────────────────────────────
      // Allow login, but flag it so the UI can show the deletion banner.
      final status = result.record.getStringValue('status');
      final isPendingDeletion = status == 'pending_deletion';
      final purgeAt = DateTime.tryParse(result.record.getStringValue('purge_at'));
      // ── End deactivation check ─────────────────────────────────────────────

      await _saveSession('clinic', result.token, result.record.id);

      return AuthResult(
        success: true,
        role: UserRole.clinic,
        user: ClinicModel.fromRecord(result.record),
        isPendingDeletion: isPendingDeletion,
        purgeAt: purgeAt,
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
      final result = await pb
          .collection(PBCollections.doctors)
          .authWithPassword(username, password);

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
      final safe = username.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9_]'),
        '_',
      );
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
          error:
              'This receptionist account has been deactivated. Contact your clinic administrator.',
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
    String?
    clinicEmail, // real email from registration; falls back to dummy if null
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
        'subscription_tier': 'base',
        'photo_limit': 2000,
        'photos_used': 0,
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
      // Retry up to 3 times with delay — PocketBase may not be ready
      // for auth immediately after create on slow networks / devices.
      RecordAuth? loginResult;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          loginResult = await pb
              .collection(PBCollections.clinics)
              .authWithPassword(username, password);
          break; // success
        } catch (e) {
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          } else {
            rethrow; // give up after 3 tries
          }
        }
      }

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
          await http.MultipartFile.fromPath('photo', doctorPhotoFile.path),
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
          final docUsername = 'dr_${clinicCode.toLowerCase()}_$docId'
              .toLowerCase();
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
              await http.MultipartFile.fromPath('photo', photoPath),
            ];
            await pb
                .collection(PBCollections.doctors)
                .create(body: body, files: files);
          } else {
            await pb.collection(PBCollections.doctors).create(body: body);
          }
        }
      }

      // ── 5. Receptionist ──
      if (receptionistData != null) {
        final recId = _generateUniqueId(8, prefix: 'RC');
        final recUsername =
            (receptionistData['username'] as String?)?.trim() ?? '';
        final recPassword =
            (receptionistData['password'] as String?)?.trim() ?? '';
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
      await _saveSession('clinic', loginResult!.token, loginResult.record.id);

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

  /// Complete the clinic registration by patching the empty clinic record
  /// created during OTP verification.
  Future<AuthResult> completeClinicRegistrationPatch({
    required String recordId,
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
  }) async {
    try {
      final clinicCode = _generateUniqueId(6);

      // The tempPw is still the actual record password — PocketBase's authWithOTP
      // does NOT rotate or change the password field. It only issues an auth token.
      // So tempPw == current password of the shell record at this point.
      final tempPw = await _storage.read(key: 'temp_otp_password');

      // ── 1. Update profile fields (name, username, etc.) — no password change ──
      final profileBody = {
        'name': clinicName,
        'username': username,
        'bed_count': bedCount,
        'clinic_id': clinicCode,
        'subscription_tier': 'base',
        'photo_limit': 2000,
        'photos_used': 0,
        'max_doctors': 1,
        if (city != null && city.isNotEmpty) 'city': city,
        if (area != null && area.isNotEmpty) 'area': area,
        if (state != null && state.isNotEmpty) 'state': state,
        if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
      };

      await pb
          .collection(PBCollections.clinics)
          .update(recordId, body: profileBody);

      // ── 2. Authenticate with new username + tempPw ──
      // The username has just been updated from 'tmp_...' to the real username.
      // Since OTP auth didn't change the password, tempPw is still valid.
      // We log in fresh so we have a clean token for the password update.
      await pb
          .collection(PBCollections.clinics)
          .authWithPassword(username, tempPw ?? password);

      // ── 3. Change password from tempPw to the user's real password ──
      // Now we know oldPassword (it's tempPw) so PocketBase will accept it.
      await pb
          .collection(PBCollections.clinics)
          .update(
            recordId,
            body: {
              'password': password,
              'passwordConfirm': password,
              'oldPassword': tempPw ?? password,
            },
          );

      await _storage.delete(key: 'temp_otp_password');
      await _storage.delete(key: 'intended_clinic_password');

      // ── 4. Authenticate with the real password ──
      final loginResult = await pb
          .collection(PBCollections.clinics)
          .authWithPassword(username, password);

      final clinicId = loginResult.record.id;

      // ── 3. Primary Doctor ──
      // Guard: check if a primary doctor already exists (from a previous failed
      // registration attempt). If so, skip creation to avoid duplicates.
      final primaryDoctorId = _generateUniqueId(8, prefix: 'DR');
      final internalUsername = 'dr_${clinicCode.toLowerCase()}';
      final internalPassword = '${password}_dr_$clinicCode';

      final existingPrimary = await pb
          .collection(PBCollections.doctors)
          .getList(
            page: 1,
            perPage: 1,
            filter: 'clinic = "$clinicId" && is_primary = true',
          );

      if (existingPrimary.items.isEmpty) {
        final doctorBody = {
          ...primaryDoctorData,
          'username': internalUsername,
          'email': _fakeEmail(internalUsername),
          'emailVisibility': false,
          'password': internalPassword,
          'passwordConfirm': internalPassword,
          'clinic': clinicId,
          'is_primary': true,
          'is_active': true,
          'doctor_id': primaryDoctorId,
        };
        doctorBody.remove('password_confirm');

        if (doctorPhotoFile != null) {
          final files = [
            await http.MultipartFile.fromPath('photo', doctorPhotoFile.path),
          ];
          await pb
              .collection(PBCollections.doctors)
              .create(body: doctorBody, files: files);
        } else {
          await pb.collection(PBCollections.doctors).create(body: doctorBody);
        }
      }

      // ── 4. Additional Doctors ──
      if (additionalDoctors != null) {
        for (final docData in additionalDoctors) {
          final docId = _generateUniqueId(8, prefix: 'DR');
          final photoPath = docData['photo_path'] as String?;
          final docUsername =
              (docData['username'] as String?)?.trim().isNotEmpty == true
              ? docData['username'].toString().toLowerCase()
              : 'dr_${clinicCode.toLowerCase()}_$docId'.toLowerCase();
          final body = {
            ...docData,
            'username': docUsername,
            'email': _fakeEmail(docUsername),
            'emailVisibility': false,
            'passwordConfirm': docData['password'],
            'clinic': clinicId,
            'is_primary': false,
            'is_active': true,
            'doctor_id': docId,
          };
          body.remove('photo_path');

          if (photoPath != null) {
            final files = [
              await http.MultipartFile.fromPath('photo', photoPath),
            ];
            await pb
                .collection(PBCollections.doctors)
                .create(body: body, files: files);
          } else {
            await pb.collection(PBCollections.doctors).create(body: body);
          }
        }
      }

      // ── 5. Receptionist ──
      if (receptionistData != null) {
        final recId = _generateUniqueId(8, prefix: 'RC');
        final recUsername =
            (receptionistData['username'] as String?)?.trim() ?? '';
        final recPassword =
            (receptionistData['password'] as String?)?.trim() ?? '';
        final recBody = {
          'name': receptionistData['name'],
          'username': recUsername,
          'email': _fakeEmail(recUsername),
          'emailVisibility': false,
          'password': recPassword,
          'passwordConfirm': recPassword,
          'clinic': clinicId,
          'is_active': true,
          'receptionist_id': recId,
          if ((receptionistData['phone'] as String?)?.isNotEmpty == true)
            'phone': receptionistData['phone'],
        };
        await pb.collection(PBCollections.receptionists).create(body: recBody);
      }

      // ── 6. Save session ──
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
        error: 'Registration patch failed: ${e.toString()}',
      );
    }
  }

  /// Logout and clear session.
  Future<void> logout() async {
    _fileTokenTimer?.cancel();
    ImageHelper.globalFileToken = null;
    pb.authStore.clear();
    await _clearStorage();
  }

  /// Add a working doctor to the current clinic.
  Future<void> addDoctor(Map<String, dynamic> docData) async {
    final clinicId = pb.authStore.model?.id;
    if (clinicId == null) throw Exception('Not authenticated as clinic');

    final docId = _generateUniqueId(8, prefix: 'DR');
    final photoPath = docData['photo_path'] as String?;
    final docUsername =
        (docData['username'] as String?)?.trim().isNotEmpty == true
        ? docData['username'].toString().toLowerCase()
        : 'dr_${clinicId.toLowerCase()}_$docId'.toLowerCase();

    final body = {
      ...docData,
      'username': docUsername,
      'email': _fakeEmail(docUsername),
      'emailVisibility': false,
      'passwordConfirm': docData['password'],
      'clinic': clinicId,
      'is_primary': false,
      'doctor_id': docId,
    };
    body.remove('photo_path');

    if (photoPath != null) {
      final files = [await http.MultipartFile.fromPath('photo', photoPath)];
      await pb
          .collection(PBCollections.doctors)
          .create(body: body, files: files);
    } else {
      await pb.collection(PBCollections.doctors).create(body: body);
    }
  }

  /// Add a receptionist to the current clinic.
  Future<void> addReceptionist(Map<String, dynamic> recData) async {
    final clinicId = pb.authStore.model?.id;
    if (clinicId == null) throw Exception('Not authenticated as clinic');

    final recId = _generateUniqueId(8, prefix: 'RC');
    final recUsername = (recData['username'] as String?)?.trim() ?? '';
    final recPassword = (recData['password'] as String?)?.trim() ?? '';
    final body = {
      'name': recData['name'],
      'username': recUsername,
      'email': _fakeEmail(recUsername),
      'emailVisibility': false,
      'password': recPassword,
      'passwordConfirm': recPassword,
      'clinic': clinicId,
      'is_active': true,
      'receptionist_id': recId,
      if ((recData['phone'] as String?)?.isNotEmpty == true)
        'phone': recData['phone'],
    };
    await pb.collection(PBCollections.receptionists).create(body: body);
  }

  /// Get current user role from storage.
  Future<UserRole?> getCurrentRole() async {
    final role = await _storage.read(key: _roleKey);
    if (role == 'clinic') return UserRole.clinic;
    if (role == 'doctor') return UserRole.doctor;
    if (role == 'receptionist') return UserRole.receptionist;
    if (role == 'superadmin') return UserRole.superadmin;
    return null;
  }

  bool get isLoggedIn => pb.authStore.isValid;

  // ── Superadmin Authentication (raw HTTP — bypasses SDK quirks for _superusers) ──

  /// Step 1: Verify superadmin email + password via raw HTTP,
  /// then immediately request an OTP to the admin email.
  Future<OtpResult> loginSuperadmin(String email, String password) async {
    final base = pb.baseURL;
    try {
      // 1a. Verify credentials
      final authRes = await http.post(
        Uri.parse('$base/api/collections/_superusers/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identity': email, 'password': password}),
      );

      final authBody = jsonDecode(authRes.body) as Map<String, dynamic>;
      final mfaId = authBody['mfaId'] as String?;

      // If OTP is enabled, PB returns a 401/403 with "mfaId" instead of 200 with token
      // If OTP is disabled, it returns 200 with token
      final bool credentialsValid = authRes.statusCode == 200 || mfaId != null;

      if (!credentialsValid) {
        final msg = (authBody['message'] as String?) ?? 'Invalid credentials';
        return OtpResult(success: false, error: msg);
      }

      // 1b. Request OTP (second factor)
      final otpRes = await http.post(
        Uri.parse('$base/api/collections/_superusers/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (otpRes.statusCode != 200) {
        final err = jsonDecode(otpRes.body) as Map<String, dynamic>;
        final msg = (err['message'] as String?) ?? 'Failed to send OTP';
        return OtpResult(success: false, error: msg);
      }

      final otpBody = jsonDecode(otpRes.body) as Map<String, dynamic>;
      final otpId = otpBody['otpId'] as String?;
      if (otpId == null) {
        return OtpResult(success: false, error: 'OTP request returned no ID');
      }
      return OtpResult(success: true, otpId: otpId, mfaId: mfaId);
    } catch (e) {
      return OtpResult(
        success: false,
        error: 'Connection error: ${e.toString()}',
      );
    }
  }

  /// Step 2: Verify OTP and complete the superadmin login.
  Future<AuthResult> verifySuperadminOtp({
    required String otpId,
    required String otpCode,
    String? mfaId,
  }) async {
    final base = pb.baseURL;
    try {
      final res = await http.post(
        Uri.parse('$base/api/collections/_superusers/auth-with-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'otpId': otpId,
          'password': otpCode,
          if (mfaId != null) 'mfaId': mfaId,
        }),
      );
      if (res.statusCode != 200) {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = err['message'] ?? 'Invalid or expired OTP.';
        return AuthResult(
          success: false,
          error: '$msg (Code: ${res.statusCode})',
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final token = body['token'] as String?;
      final recordId =
          (body['record'] as Map<String, dynamic>?)?['id'] as String?;
      if (token == null || recordId == null) {
        return AuthResult(success: false, error: 'Unexpected server response.');
      }
      // Persist session and inject token into pb.authStore for SuperadminService calls
      await _saveSession('superadmin', token, recordId);
      final recordMap = body['record'] as Map<String, dynamic>?;
      final recordModel = recordMap != null ? RecordModel(recordMap) : null;
      pb.authStore.save(token, recordModel);
      return AuthResult(success: true, role: UserRole.superadmin);
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Connection error: ${e.toString()}',
      );
    }
  }

  // ── OTP Methods ────────────────────────────────────────────────

  /// Delete the currently authenticated shell clinic record if it is unfilled
  /// (i.e. the name field is empty — created purely for OTP verification).
  /// Called when the user wants to change their email after OTP.
  /// Requires the clinics Delete API rule to be `@request.auth.id = id`.
  Future<bool> deleteShellClinic() async {
    try {
      final record = pb.authStore.record;
      if (record == null) return false;

      // Safety guard: only delete shells (name is empty = not yet registered)
      final name = record.getStringValue('name');
      if (name.isNotEmpty) return false; // fully registered — never auto-delete

      await pb.collection(PBCollections.clinics).delete(record.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// After a successful authWithOTP call, the PB auth store holds the clinic
  /// record and token. This method persists the session to secure storage and
  /// returns an [AuthResult] so the UI can set state correctly.
  Future<AuthResult?> saveClinicSessionFromAuthStore() async {
    try {
      final record = pb.authStore.record;
      final token = pb.authStore.token;
      if (record == null || token.isEmpty) return null;

      await _saveSession('clinic', token, record.id);
      return AuthResult(
        success: true,
        role: UserRole.clinic,
        user: ClinicModel.fromRecord(record),
      );
    } catch (_) {
      return null;
    }
  }

  /// Request an OTP to be sent to [email] via PocketBase's built-in OTP system.
  /// PocketBase requires a record to already exist before it sends an OTP.
  /// For new emails we create a minimal shell record first; if the email already
  /// exists the creation silently fails and we proceed to OTP as usual.
  /// Save the intended clinic password to secure storage so it can be used
  /// during the final registration step. Call this before [requestOtp] so the
  /// shell record is created with this password, making it available as
  /// [oldPassword] when we need to update to the same real password.
  Future<void> storeIntendedPassword(String password) async {
    await _storage.write(key: 'intended_clinic_password', value: password);
  }

  Future<OtpResult> requestOtp(String email) async {
    // ── 1. Ensure a clinic record exists for this email ──────────────────────
    // For new registrations: create a bare shell so PB has a record to OTP.
    // We use the intended password (stored by storeIntendedPassword) so that
    // after OTP verification we can supply it as oldPassword when completing
    // registration. Falls back to a random temp if not available.
    // For existing accounts: this create call will fail with a duplicate-email
    // 400 error — we swallow it and move on.
    try {
      // Use the intended password if already stored, otherwise a random temp
      final storedPw = await _storage.read(key: 'intended_clinic_password');
      final tempPw =
          storedPw ?? 'TempPw!${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: 'temp_otp_password', value: tempPw);
      final tempUsername = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
      await pb
          .collection(PBCollections.clinics)
          .create(
            body: {
              'email': email,
              'emailVisibility': true,
              'password': tempPw,
              'passwordConfirm': tempPw,
              'name': '', // empty shell — filled during registration completion
              'username': tempUsername, // temporary unique username
              'bed_count': 0,
              'clinic_id': tempUsername,
              'subscription_tier': 'base',
              'photo_limit': 2000,
              'photos_used': 0,
              'max_doctors': 1,
            },
          );
    } catch (_) {
      // Ignore — record already exists (existing user) or a field failed validation.
    }

    // ── 2. Request OTP ───────────────────────────────────────────────────────
    try {
      final response = await pb
          .collection(PBCollections.clinics)
          .requestOTP(email);
      return OtpResult(success: true, otpId: response.otpId);
    } on ClientException catch (e) {
      return OtpResult(success: false, error: _parseError(e));
    } catch (_) {
      return OtpResult(
        success: false,
        error: 'Could not send OTP. Check your email address.',
      );
    }
  }

  /// Verify an OTP code. On success the PocketBase auth store is updated.
  Future<AuthResult> verifyOtp({
    required String otpId,
    required String otpCode,
  }) async {
    try {
      await pb.collection(PBCollections.clinics).authWithOTP(otpId, otpCode);
      return AuthResult(success: true);
    } on ClientException catch (_) {
      return AuthResult(
        success: false,
        error: 'Invalid or expired code. Try again.',
      );
    } catch (_) {
      return AuthResult(
        success: false,
        error: 'Verification failed. Please try again.',
      );
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
      await pb
          .collection(PBCollections.clinics)
          .update(
            authResult.record.id,
            body: {
              'password': newPassword,
              'passwordConfirm': newPassword,
              'oldPassword':
                  otpCode, // PocketBase may not require this for OTP auth
            },
          );
      // Clear the session — user must log in fresh with new password
      pb.authStore.clear();
      await _clearStorage();
      return AuthResult(success: true);
    } on ClientException catch (e) {
      return AuthResult(success: false, error: _parseError(e));
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Reset failed. Please try again.',
      );
    }
  }

  /// Check if a username is already taken across all roles (clinics, doctors, receptionists).
  /// Returns true if the username exists, false otherwise.
  Future<bool> checkUsernameExists(String username) async {
    final sanitized = username.trim().toLowerCase();
    if (sanitized.isEmpty) return false;

    try {
      final futures = await Future.wait([
        pb
            .collection(PBCollections.clinics)
            .getList(page: 1, perPage: 1, filter: 'username="$sanitized"'),
        pb
            .collection(PBCollections.doctors)
            .getList(page: 1, perPage: 1, filter: 'username="$sanitized"'),
        pb
            .collection(PBCollections.receptionists)
            .getList(page: 1, perPage: 1, filter: 'username="$sanitized"'),
      ]);

      for (final result in futures) {
        if (result.items.isNotEmpty) return true;
      }
      return false;
    } catch (_) {
      // In case of a network error, return false to let them try submitting (server will reject if taken)
      return false;
    }
  }

  // ── Generate unique ID ───────────────────────────────────────────
  Future<void> _saveSession(String role, String token, String userId) async {
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _startFileTokenRefresh();
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
    final random = List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
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
          if (data.containsKey('username')) {
            final msg = (data['username'] as Map?)?['message']?.toString() ?? '';
            if (msg.toLowerCase().contains('unique')) {
              return 'This username is already taken. Please choose a different one.';
            }
          }
          if (data.containsKey('email')) {
            final msg = (data['email'] as Map?)?['message']?.toString() ?? '';
            if (msg.toLowerCase().contains('unique')) {
              return 'This username is already registered. Please choose a different username.';
            }
          }
          final fieldErrors = data.entries
              .where(
                (entry) =>
                    entry.value is Map &&
                    (entry.value as Map).containsKey('message'),
              )
              .map((entry) => (entry.value as Map)['message'])
              .join('\n');
          if (fieldErrors.isNotEmpty) {
            return fieldErrors;
          }
        }
      }

      if (response.containsKey('message')) {
        return response['message'].toString();
      }

      return 'Something went wrong. Please try again.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }
}
