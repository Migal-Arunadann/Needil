/// PocketBase API Rules Fix Script.
///
/// Run this to open up API rules on all collections so the Flutter app
/// can register clinics/doctors and access records normally:
///
///   dart run scripts/fix_rules.dart <admin_email> <admin_password>
library;

import 'dart:io';
import 'dart:convert';

const String pbUrl =
    'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

// Rules per collection:
// - Auth collections (clinics, doctors): createRule="" so anyone can register
// - Base collections: createRule="@request.auth.id != ''" so only logged-in users
// - listRule/viewRule: "@request.auth.id != ''" everywhere for security
// - updateRule: own-record only for auth, any-auth for base
// - deleteRule: locked down
final Map<String, Map<String, String?>> _rules = {
  // AUTH collections — empty createRule = open registration
  'clinics': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': '',          // Allow anyone to register
    'updateRule': "@request.auth.id = id",
    'deleteRule': null,
  },
  'doctors': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': '',          // Allow anyone to register
    'updateRule': "@request.auth.id = id",
    'deleteRule': null,
  },
  // BASE collections — require authentication
  'patients': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': "@request.auth.id != ''",
    'updateRule': "@request.auth.id != ''",
    'deleteRule': null,
  },
  'appointments': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': "@request.auth.id != ''",
    'updateRule': "@request.auth.id != ''",
    'deleteRule': null,
  },
  'consultations': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': "@request.auth.id != ''",
    'updateRule': "@request.auth.id != ''",
    'deleteRule': null,
  },
  'treatment_plans': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': "@request.auth.id != ''",
    'updateRule': "@request.auth.id != ''",
    'deleteRule': null,
  },
  'sessions': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': "@request.auth.id != ''",
    'updateRule': "@request.auth.id != ''",
    'deleteRule': null,
  },
  'audit_logs': {
    'listRule': null,          // Superuser-only for audit logs
    'viewRule': null,
    'createRule': "@request.auth.id != ''",
    'updateRule': null,
    'deleteRule': null,
  },
  'consent_records': {
    'listRule': "@request.auth.id != ''",
    'viewRule': "@request.auth.id != ''",
    'createRule': "@request.auth.id != ''",
    'updateRule': "@request.auth.id != ''",
    'deleteRule': null,
  },
};

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/fix_rules.dart <admin_email> <admin_password>');
    exit(1);
  }

  final email = args[0];
  final password = args[1];
  final client = HttpClient();

  try {
    print('🔐 Authenticating as admin...');
    final token = await _adminAuth(client, email, password);
    print('✅ Authenticated\n');

    for (final entry in _rules.entries) {
      final name = entry.key;
      final rules = entry.value;
      print('🔧 Patching rules for: $name...');
      try {
        await _patchRules(client, token, name, rules);
        print('   ✅ $name rules updated');
      } catch (e) {
        print('   ⚠️  $name: $e');
      }
    }

    print('\n🎉 All rules patched!');
    print('   Clinic/doctor registration should now work in the app.');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<String> _adminAuth(HttpClient client, String email, String password) async {
  final uri = Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password');
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'identity': email, 'password': password}));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw 'Auth failed (${response.statusCode}): $body';
  }
  return (jsonDecode(body) as Map<String, dynamic>)['token'] as String;
}

Future<void> _patchRules(
  HttpClient client,
  String token,
  String collectionName,
  Map<String, String?> rules,
) async {
  // Build body — only include non-null rules
  final body = <String, dynamic>{};
  for (final r in rules.entries) {
    body[r.key] = r.value;   // null means "superuser only" in PB
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
