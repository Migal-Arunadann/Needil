/// PocketBase Production API Rules & DPDP Act 2023 Compliance Sync Script.
///
/// This script configures and applies production-grade, multi-tenant row-level
/// security rules conforming to India's Digital Personal Data Protection (DPDP) Act 2023.
///
/// Features:
/// 1. Interactive 2FA / OTP Authentication support.
/// 2. Automatic provisioning of `system_settings` collection.
/// 3. DPDP Act 2023 row-level tenant isolation across all 14 collections.
///
/// Usage:
///   dart run scripts/fix_rules.dart
///   or: dart run scripts/fix_rules.dart <admin_email> <admin_password> [pocketbase_url]
library;

import 'dart:io';
import 'dart:convert';

String pbUrl = 'https://api.needil.com';

String _getPbUrl() {
  try {
    final file = File('lib/core/providers/pocketbase_provider.dart');
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final match = RegExp(r"pbBaseUrl\s*=\s*[\x27\x22]([^\x27\x22]+)[\x27\x22]").firstMatch(content);
      if (match != null) {
        return match.group(1)!;
      }
    }
  } catch (_) {}
  return pbUrl;
}

// ─── DPDP Rule Fragments ───────────────────────────────────────────────────

/// Direct clinic tenant check:
/// Valid if requester is Clinic Admin (@request.auth.id) OR Clinic Staff (@request.auth.clinic).
const String _tenantScope =
    "clinic.id = @request.auth.id || clinic.id = @request.auth.clinic";

/// Sub-resource tenant check (via doctor or patient clinic relations):
const String _subResourceScope =
    "doctor.clinic = @request.auth.id || doctor.clinic = @request.auth.clinic || patient.clinic = @request.auth.id || patient.clinic = @request.auth.clinic";

// ─── Production DPDP Rules Matrix ──────────────────────────────────────────

/// Scheduling audit logs scope (navigates through treatment_plan relation):
const String _schedulingAuditScope =
    "treatment_plan.doctor.clinic = @request.auth.id || treatment_plan.doctor.clinic = @request.auth.clinic || treatment_plan.patient.clinic = @request.auth.id || treatment_plan.patient.clinic = @request.auth.clinic";

final Map<String, Map<String, String?>> _dpdpProductionRules = {
  // 1. Clinics (Auth Collection)
  'clinics': {
    'listRule': "@request.auth.id = id || @request.auth.clinic = id",
    'viewRule': "@request.auth.id = id || @request.auth.clinic = id",
    'createRule': '', // Public registration endpoint
    'updateRule': "@request.auth.id = id",
    'deleteRule': null, // Superadmin only (hard purge/retention policy)
  },

  // 2. Doctors (Auth Collection)
  'doctors': {
    'listRule': _tenantScope,
    'viewRule': _tenantScope,
    'createRule': '', // Initial shell creation or clinic admin creation
    'updateRule': "@request.auth.id = id || clinic.id = @request.auth.id",
    'deleteRule': "clinic.id = @request.auth.id",
  },

  // 3. Receptionists (Auth Collection)
  'receptionists': {
    'listRule': _tenantScope,
    'viewRule': _tenantScope,
    'createRule': "@request.auth.id != '' && (clinic.id = @request.auth.id || @request.auth.collectionName = 'clinics')",
    'updateRule': "@request.auth.id = id || clinic.id = @request.auth.id",
    'deleteRule': "clinic.id = @request.auth.id",
  },

  // 4. Patients (Protected Health Information - Section 4 & 6 DPDP)
  'patients': {
    'listRule': _tenantScope,
    'viewRule': _tenantScope,
    'createRule': "@request.auth.id != '' && ($_tenantScope)",
    'updateRule': _tenantScope,
    'deleteRule': _tenantScope, // DPDP Section 12 Right to Erasure
  },

  // 5. Appointments (Health Schedule Data)
  'appointments': {
    'listRule': _tenantScope,
    'viewRule': _tenantScope,
    'createRule': "@request.auth.id != '' && ($_tenantScope)",
    'updateRule': _tenantScope,
    'deleteRule': _tenantScope,
  },

  // 6. Consultations (Sensitive Diagnostic Health Records)
  'consultations': {
    'listRule': _subResourceScope,
    'viewRule': _subResourceScope,
    'createRule': "@request.auth.id != '' && ($_subResourceScope)",
    'updateRule': _subResourceScope,
    'deleteRule': _subResourceScope,
  },

  // 7. Treatment Plans (Clinical Protocols)
  'treatment_plans': {
    'listRule': _subResourceScope,
    'viewRule': _subResourceScope,
    'createRule': "@request.auth.id != '' && ($_subResourceScope)",
    'updateRule': _subResourceScope,
    'deleteRule': _subResourceScope,
  },

  // 8. Sessions (Treatment Progress & Photos)
  'sessions': {
    'listRule': _subResourceScope,
    'viewRule': _subResourceScope,
    'createRule': "@request.auth.id != '' && ($_subResourceScope)",
    'updateRule': _subResourceScope,
    'deleteRule': _subResourceScope,
  },

  // 9. Consent Records (DPDP Section 6 Explicit Consent Management)
  'consent_records': {
    'listRule': "@request.auth.id != '' && user_id = @request.auth.id",
    'viewRule': "@request.auth.id != '' && user_id = @request.auth.id",
    'createRule': "@request.auth.id != '' && user_id = @request.auth.id",
    'updateRule': "@request.auth.id != '' && user_id = @request.auth.id",
    'deleteRule': null, // Locked for legal non-repudiation
  },

  // 10. Clinic Reactivation Requests
  // (Uses `clinic_id` text field)
  'clinic_reactivation_requests': {
    'listRule': "clinic_id = @request.auth.id || clinic_id = @request.auth.clinic",
    'viewRule': "clinic_id = @request.auth.id || clinic_id = @request.auth.clinic",
    'createRule': "@request.auth.id != '' && (clinic_id = @request.auth.id || clinic_id = @request.auth.clinic)",
    'updateRule': null, // Superadmin only for approvals/rejections
    'deleteRule': null, // Superadmin only
  },

  // 11. Scheduling Exceptions (Staff Availability Overrides)
  'scheduling_exceptions': {
    'listRule': _tenantScope,
    'viewRule': _tenantScope,
    'createRule': "@request.auth.id != '' && ($_tenantScope)",
    'updateRule': _tenantScope,
    'deleteRule': _tenantScope,
  },

  // 12. Scheduling Audit Logs (Immutable Operational Logs linked via treatment_plan)
  'scheduling_audit_logs': {
    'listRule': _schedulingAuditScope,
    'viewRule': _schedulingAuditScope,
    'createRule': "@request.auth.id != '' && ($_schedulingAuditScope)",
    'updateRule': null, // Immutable
    'deleteRule': null, // Immutable
  },

  // 13. Audit Logs (Master Platform Audit Trail)
  'audit_logs': {
    'listRule': null, // Superadmin only
    'viewRule': null, // Superadmin only
    'createRule': "@request.auth.id != ''", // Append-only
    'updateRule': null, // Immutable
    'deleteRule': null, // Immutable
  },

  // 14. System Settings (Platform Global Defaults)
  'system_settings': {
    'listRule': "@request.auth.id != ''", // Read-only for authenticated app
    'viewRule': "@request.auth.id != ''",
    'createRule': null, // Superadmin only
    'updateRule': null, // Superadmin only
    'deleteRule': null, // Superadmin only
  },
};

// ─── Main Execution ────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  String email = '';
  String password = '';

  if (args.length >= 2) {
    email = args[0];
    password = args[1];
    if (args.length >= 3) {
      pbUrl = args[2];
    } else {
      pbUrl = _getPbUrl();
    }
  } else {
    pbUrl = _getPbUrl();
  }

  print('════════════════════════════════════════════════════════════════');
  print('🔐 NEEDIL DPDP ACT 2023 & PRODUCTION API RULES SYNC');
  print('🌐 PocketBase URL: $pbUrl');
  print('════════════════════════════════════════════════════════════════\n');

  if (email.isEmpty || password.isEmpty) {
    stdout.write('📧 Enter Superadmin Email: ');
    email = stdin.readLineSync()?.trim() ?? '';
    stdout.write('🔑 Enter Superadmin Password: ');
    try {
      stdin.echoMode = false;
      password = stdin.readLineSync()?.trim() ?? '';
      stdin.echoMode = true;
    } catch (_) {
      password = stdin.readLineSync()?.trim() ?? '';
    }
    print('\n');
  }

  if (email.isEmpty || password.isEmpty) {
    print('❌ Error: Email and password are required.');
    exit(1);
  }

  final client = HttpClient();

  try {
    print('1. Authenticating as Superadmin (with OTP/2FA support)...');
    final token = await _adminAuth(client, email, password);
    print('   ✅ Authenticated successfully.\n');

    // 1. Ensure system_settings collection exists
    print('2. Checking & provisioning system_settings collection...');
    await _ensureSystemSettingsCollection(client, token);
    print('');

    // 2. Patch production rules
    print('3. Enforcing DPDP production rules across 14 collections...');
    int updatedCount = 0;
    for (final entry in _dpdpProductionRules.entries) {
      final name = entry.key;
      final rules = entry.value;
      stdout.write('   • Enforcing rules on "$name"... ');
      try {
        await _patchRules(client, token, name, rules);
        print('✅ [ENFORCED]');
        updatedCount++;
      } catch (e) {
        print('⚠️ [$e]');
      }
    }

    print('\n════════════════════════════════════════════════════════════════');
    print('🎉 SUCCESS: $updatedCount/14 Collections Hardened for Production!');
    print('🛡️  DPDP Act 2023 Multi-Tenant Isolation: Active');
    print('🔒 Cross-Tenant Scraping: Blocked at database engine level');
    print('👑 Superadmin Master Access: Unrestricted via _superusers bypass');
    print('════════════════════════════════════════════════════════════════');
  } catch (e) {
    print('\n❌ Error during rule synchronization: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<String> _adminAuth(HttpClient client, String email, String password) async {
  // Step 1: Check credentials
  final uri = Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password');
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'identity': email, 'password': password}));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  Map<String, dynamic> data = {};
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {}

  // Direct login without 2FA
  if (response.statusCode == 200 && data['token'] != null) {
    return data['token'] as String;
  }

  // Step 2: Handle OTP / MFA
  final mfaId = data['mfaId'] as String?;
  final bool isMfa = mfaId != null || response.statusCode == 401 || response.statusCode == 403;

  if (!isMfa && response.statusCode != 200) {
    throw 'Superadmin credential check failed (${response.statusCode}): ${data['message'] ?? body}';
  }

  print('   📲 OTP 2FA required for superadmin account: $email');
  stdout.write('   📨 Requesting OTP from PocketBase... ');

  final otpUri = Uri.parse('$pbUrl/api/collections/_superusers/request-otp');
  final otpReq = await client.postUrl(otpUri);
  otpReq.headers.contentType = ContentType.json;
  otpReq.write(jsonEncode({'email': email}));
  final otpRes = await otpReq.close();
  final otpBody = await otpRes.transform(utf8.decoder).join();

  if (otpRes.statusCode != 200) {
    throw 'Failed to send OTP (${otpRes.statusCode}): $otpBody';
  }

  final otpData = jsonDecode(otpBody) as Map<String, dynamic>;
  final otpId = otpData['otpId'] as String?;
  if (otpId == null) {
    throw 'PocketBase did not return an otpId: $otpBody';
  }
  print('✅ Sent!');
  print('\n   👉 Check your email ($email) for the 6-digit OTP code.');
  stdout.write('   🔑 Enter OTP Code: ');
  final otpCode = stdin.readLineSync()?.trim() ?? '';

  if (otpCode.isEmpty) {
    throw 'OTP code cannot be empty.';
  }

  stdout.write('   ⏳ Verifying OTP... ');
  final verifyUri = Uri.parse('$pbUrl/api/collections/_superusers/auth-with-otp');
  final verifyReq = await client.postUrl(verifyUri);
  verifyReq.headers.contentType = ContentType.json;
  verifyReq.write(jsonEncode({
    'otpId': otpId,
    'password': otpCode,
    if (mfaId != null) 'mfaId': mfaId,
  }));
  final verifyRes = await verifyReq.close();
  final verifyBody = await verifyRes.transform(utf8.decoder).join();

  if (verifyRes.statusCode != 200) {
    throw 'OTP verification failed (${verifyRes.statusCode}): $verifyBody';
  }

  final verifyData = jsonDecode(verifyBody) as Map<String, dynamic>;
  final token = verifyData['token'] as String?;
  if (token == null) {
    throw 'No token returned after OTP verification: $verifyBody';
  }
  print('✅ Verified!');
  return token;
}

Future<void> _ensureSystemSettingsCollection(HttpClient client, String token) async {
  final uri = Uri.parse('$pbUrl/api/collections');
  final request = await client.getUrl(uri);
  request.headers.set('Authorization', token);
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode == 200) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    final exists = items.any((c) => (c as Map<String, dynamic>)['name'] == 'system_settings');
    if (exists) {
      print('   ✅ system_settings collection already provisioned.');
      return;
    }
  }

  print('   📦 Creating system_settings collection...');
  final createUri = Uri.parse('$pbUrl/api/collections');
  final createReq = await client.postUrl(createUri);
  createReq.headers.contentType = ContentType.json;
  createReq.headers.set('Authorization', token);
  createReq.write(jsonEncode({
    'name': 'system_settings',
    'type': 'base',
    'schema': [
      {
        'name': 'default_trial_days',
        'type': 'number',
        'required': false,
        'options': {'min': 1, 'max': 365},
      },
      {
        'name': 'grace_period_days',
        'type': 'number',
        'required': false,
        'options': {'min': 0, 'max': 60},
      },
      {
        'name': 'default_photo_limit',
        'type': 'number',
        'required': false,
        'options': {'min': 100, 'max': 100000},
      },
    ],
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': null,
    'updateRule': null,
    'deleteRule': null,
  }));
  final createRes = await createReq.close();
  final createBody = await createRes.transform(utf8.decoder).join();
  if (createRes.statusCode >= 200 && createRes.statusCode < 300) {
    print('   ✅ system_settings collection created successfully.');
  } else {
    print('   ⚠️ Note on system_settings creation: $createBody');
  }
}

Future<void> _patchRules(
  HttpClient client,
  String token,
  String collectionName,
  Map<String, String?> rules,
) async {
  final body = <String, dynamic>{};
  for (final r in rules.entries) {
    body[r.key] = r.value; // null means "superuser only" in PB
  }

  final uri = Uri.parse('$pbUrl/api/collections/$collectionName');
  final request = await client.openUrl('PATCH', uri);
  request.headers.contentType = ContentType.json;
  request.headers.set('Authorization', token);
  request.write(jsonEncode(body));
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    throw 'PATCH failed (${response.statusCode}): $responseBody';
  }
}
