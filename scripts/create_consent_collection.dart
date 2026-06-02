/// Creates the consent_records collection and sets its API rules.
/// Run: dart run scripts/create_consent_collection.dart <email> <password>
library;

import 'dart:io';
import 'dart:convert';

const String pbUrl =
    'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/create_consent_collection.dart <email> <password>');
    exit(1);
  }
  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final token = await _adminAuth(client, args[0], args[1]);
    print('✅ Authenticated\n');

    // 1. Create collection
    print('📦 Creating consent_records collection...');
    final createBody = {
      'name': 'consent_records',
      'type': 'base',
      'fields': [
        {'name': 'user_id',      'type': 'text', 'required': true},
        {'name': 'consent_type', 'type': 'text', 'required': true},
        {'name': 'purpose',      'type': 'text'},
        {'name': 'withdrawn',    'type': 'bool'},
        {'name': 'timestamp',    'type': 'text'},
      ],
      // API rules: owner can write, superuser can read (DPDP compliance)
      'listRule':   null,                        // superuser only
      'viewRule':   null,                        // superuser only
      'createRule': "@request.auth.id != ''",   // any authenticated user
      'updateRule': "@request.auth.id != '' && user_id = @request.auth.id",
      'deleteRule': null,                        // locked
    };

    final uri = Uri.parse('$pbUrl/api/collections');
    final req = await client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.headers.set('Authorization', token);
    req.write(jsonEncode(createBody));
    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();

    if (res.statusCode == 200) {
      print('✅ consent_records created with secure API rules');
    } else if (resBody.contains('already exists')) {
      print('⚠️  Collection already exists — patching rules only...');
      await _patch(client, token, 'consent_records', {
        'listRule':   null,
        'viewRule':   null,
        'createRule': "@request.auth.id != ''",
        'updateRule': "@request.auth.id != '' && user_id = @request.auth.id",
        'deleteRule': null,
      });
      print('✅ Rules patched');
    } else {
      throw 'Create failed (${res.statusCode}): $resBody';
    }

    print('\n🎉 Done! consent_records is ready.');
  } catch (e) {
    print('❌ $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<String> _adminAuth(HttpClient c, String email, String pw) async {
  final req = await c.postUrl(
      Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'));
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode({'identity': email, 'password': pw}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'Auth failed: $body';
  return (jsonDecode(body))['token'] as String;
}

Future<void> _patch(HttpClient c, String token, String name,
    Map<String, dynamic> rules) async {
  final req = await c.openUrl('PATCH', Uri.parse('$pbUrl/api/collections/$name'));
  req.headers.contentType = ContentType.json;
  req.headers.set('Authorization', token);
  req.write(jsonEncode(rules));
  final res = await req.close();
  if (res.statusCode != 200) {
    final body = await res.transform(utf8.decoder).join();
    throw 'PATCH failed: $body';
  }
}
