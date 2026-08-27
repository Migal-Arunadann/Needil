/// PocketBase Complete Schema & API Rules Inspector.
///
/// Dumps all collections, field definitions, relation targets, and active API rules
/// from the live PocketBase server.
///
/// Usage:
///   dart run scripts/inspect_full_schema_and_rules.dart
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

  print('════════════════════════════════════════════════════════════════════════════════');
  print('🔎 POCKETBASE COMPLETE LIVE SCHEMA & API RULES INSPECTION');
  print('🌐 PocketBase Server: $pbUrl');
  print('════════════════════════════════════════════════════════════════════════════════\n');

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
    print('1. Authenticating as Superadmin (with 2FA/OTP support)...');
    final token = await _adminAuth(client, email, password);
    print('   ✅ Authenticated successfully.\n');

    print('2. Querying all collection metadata from /api/collections...\n');
    final uri = Uri.parse('$pbUrl/api/collections?perPage=500');
    final request = await client.getUrl(uri);
    request.headers.set('Authorization', token);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw 'Failed to fetch collections (${response.statusCode}): $body';
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    // Sort alphabetically by collection name
    items.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

    // Save full raw JSON to file
    final outputFile = File('pocketbase_live_schema.json');
    outputFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(items));
    print('💾 Complete raw schema exported to: ${outputFile.path}\n');

    print('════════════════════════════════════════════════════════════════════════════════');
    print('📋 LIVE SCHEMA & API RULES SUMMARY (${items.length} Collections)');
    print('════════════════════════════════════════════════════════════════════════════════\n');

    for (int i = 0; i < items.length; i++) {
      final col = items[i];
      final name = col['name'] ?? 'unknown';
      final type = col['type'] ?? 'base';
      final id = col['id'] ?? '';
      final listRule = col['listRule'];
      final viewRule = col['viewRule'];
      final createRule = col['createRule'];
      final updateRule = col['updateRule'];
      final deleteRule = col['deleteRule'];
      
      // Fields can be in 'schema' (PB v0.22) or 'fields' (PB v0.23+)
      final fields = (col['schema'] as List<dynamic>?) ??
          (col['fields'] as List<dynamic>?) ??
          [];

      print('[$name] (Type: $type, ID: $id)');
      print('  ├─ API Rules:');
      print('  │   ├─ listRule:   ${_formatRuleText(listRule)}');
      print('  │   ├─ viewRule:   ${_formatRuleText(viewRule)}');
      print('  │   ├─ createRule: ${_formatRuleText(createRule)}');
      print('  │   ├─ updateRule: ${_formatRuleText(updateRule)}');
      print('  │   └─ deleteRule: ${_formatRuleText(deleteRule)}');
      print('  └─ Fields (${fields.length}):');

      for (int f = 0; f < fields.length; f++) {
        final field = fields[f] as Map<String, dynamic>;
        final fName = field['name'] ?? '';
        final fType = field['type'] ?? '';
        final fReq = field['required'] == true ? ' [REQUIRED]' : '';
        String extra = '';

        if (fType == 'relation') {
          final relColId = field['options']?['collectionId'] ?? field['collectionId'] ?? '';
          final maxSelect = field['options']?['maxSelect'] ?? field['maxSelect'] ?? 1;
          extra = ' -> Relation (target: $relColId, max: $maxSelect)';
        } else if (fType == 'select') {
          final values = field['options']?['values'] ?? field['values'] ?? [];
          extra = ' -> Select $values';
        }

        final isLast = f == fields.length - 1;
        final prefix = isLast ? '      └─' : '      ├─';
        print('$prefix $fName ($fType)$fReq$extra');
      }
      print('');
    }

    print('════════════════════════════════════════════════════════════════════════════════');
    print('✅ Schema inspection complete! Please copy and share the output.');
    print('════════════════════════════════════════════════════════════════════════════════');
  } catch (e) {
    print('\n❌ Inspection error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

String _formatRuleText(dynamic rule) {
  if (rule == null) return 'null (Superadmin only)';
  if (rule == '') return '"" (Public Open)';
  return '"$rule"';
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
