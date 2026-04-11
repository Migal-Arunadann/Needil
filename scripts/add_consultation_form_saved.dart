/// Adds the `consultation_form_saved` bool field to the appointments collection.
///
/// Run: dart run scripts/add_consultation_form_saved.dart <email> <password>
library;

import 'dart:io';
import 'dart:convert';

const String pbUrl =
    'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/add_consultation_form_saved.dart <email> <password>');
    exit(1);
  }

  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final token = await _adminAuth(client, args[0], args[1]);
    print('✅ Authenticated\n');

    print('📦 Fetching appointments collection...');
    final col = await _getCollection(client, token, 'appointments');
    final colId = col['id'] as String;
    final fields = List<Map<String, dynamic>>.from(col['fields'] as List? ?? []);

    _addIfMissing(fields, {
      'name': 'consultation_form_saved',
      'type': 'bool',
      'required': false,
      'presentable': false,
      'hidden': false,
      'system': false,
    });

    await _patchCollection(client, token, colId, fields);
    print('\n✅ appointments collection updated.');
    print('🎉 Done! The consultation_form_saved field is now available.');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

void _addIfMissing(List<Map<String, dynamic>> fields, Map<String, dynamic> field) {
  final name = field['name'] as String;
  if (!fields.any((f) => f['name'] == name)) {
    fields.add(field);
    print('   + adding field: $name');
  } else {
    print('   ✓ field already exists: $name (no change needed)');
  }
}

Future<Map<String, dynamic>> _getCollection(
    HttpClient client, String token, String name) async {
  final req = await client.getUrl(Uri.parse('$pbUrl/api/collections/$name'));
  req.headers.set('Authorization', token);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'GET $name failed: $body';
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<void> _patchCollection(HttpClient client, String token,
    String id, List<Map<String, dynamic>> fields) async {
  final req = await client.openUrl('PATCH', Uri.parse('$pbUrl/api/collections/$id'));
  req.headers.contentType = ContentType.json;
  req.headers.set('Authorization', token);
  req.write(jsonEncode({'fields': fields}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'PATCH failed: $body';
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
