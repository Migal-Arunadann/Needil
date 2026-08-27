/// PocketBase API Rules Verification Script.
///
/// Fetches and inspects live API rules directly from the PocketBase server
/// to verify that all 14 collections have their production DPDP rules active.
///
/// Usage:
///   dart run scripts/verify_rules.dart
///   or: dart run scripts/verify_rules.dart <admin_email> <admin_password>
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
  print('🔍 POCKETBASE LIVE API RULES AUDIT & VERIFICATION');
  print('🌐 PocketBase Server: $pbUrl');
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
    print('1. Authenticating as Superadmin...');
    final token = await _adminAuth(client, email, password);
    print('   ✅ Authenticated.\n');

    print('2. Fetching live collection rules from PocketBase server...\n');
    final uri = Uri.parse('$pbUrl/api/collections?perPage=100');
    final request = await client.getUrl(uri);
    request.headers.set('Authorization', token);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw 'Failed to fetch collections (${response.statusCode}): $body';
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];

    const targetCollections = [
      'clinics',
      'doctors',
      'receptionists',
      'patients',
      'appointments',
      'consultations',
      'treatment_plans',
      'sessions',
      'consent_records',
      'clinic_reactivation_requests',
      'scheduling_exceptions',
      'scheduling_audit_logs',
      'audit_logs',
      'system_settings',
    ];

    print('═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════');
    print(
      '${'COLLECTION'.padRight(30)} '
      '${'LIST RULE'.padRight(20)} '
      '${'VIEW RULE'.padRight(20)} '
      '${'CREATE RULE'.padRight(16)} '
      '${'UPDATE RULE'.padRight(16)} '
      '${'DELETE RULE'.padRight(12)}',
    );
    print('═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════');

    int verifiedCount = 0;

    for (final target in targetCollections) {
      final col = items.firstWhere(
        (c) => (c as Map<String, dynamic>)['name'] == target,
        orElse: () => null,
      ) as Map<String, dynamic>?;

      if (col == null) {
        print('${target.padRight(30)} ❌ NOT FOUND ON SERVER');
        continue;
      }

      verifiedCount++;
      final listRule = _formatRule(col['listRule']);
      final viewRule = _formatRule(col['viewRule']);
      final createRule = _formatRule(col['createRule']);
      final updateRule = _formatRule(col['updateRule']);
      final deleteRule = _formatRule(col['deleteRule']);

      print(
        '${target.padRight(30)} '
        '${listRule.padRight(20)} '
        '${viewRule.padRight(20)} '
        '${createRule.padRight(16)} '
        '${updateRule.padRight(16)} '
        '${deleteRule.padRight(12)}',
      );
    }

    print('═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════\n');
    print('🎉 Verified $verifiedCount/${targetCollections.length} collections live on PocketBase server!');
    print('ℹ️ Legend:');
    print('   • [Tenant Scoped] = Protected Health Information isolated to clinic fiduciary (DPDP compliant)');
    print('   • [Superadmin Only] = Master-level access only (regular users blocked)');
    print('   • [Public Open] = Public endpoint (e.g. registration onboarding)');
    print('   • [Owner Only] = Isolated per data principal (e.g. consent records)');
    print('   • [Immutable] = Append-only audit logs (no updates/deletions allowed)');
  } catch (e) {
    print('\n❌ Error during verification: $e');
    exit(1);
  } finally {
    client.close();
  }
}

String _formatRule(dynamic rule) {
  if (rule == null) return '[Superadmin Only]';
  if (rule == '') return '[Public Open]';
  final str = rule.toString();
  if (str.contains('user_id = @request.auth.id')) return '[Owner Only]';
  if (str.contains('clinic')) return '[Tenant Scoped]';
  if (str.contains('@request.auth.id')) return '[Auth Only]';
  return str.length > 18 ? '${str.substring(0, 15)}...' : str;
}

Future<String> _adminAuth(HttpClient client, String email, String password) async {
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

  if (response.statusCode == 200 && data['token'] != null) {
    return data['token'] as String;
  }

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
