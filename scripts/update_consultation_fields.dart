/// Adds new fields to the consultations collection for the V2 form.
///
/// Run: dart run scripts/update_consultation_fields.dart <email> <password>
import 'dart:io';
import 'dart:convert';

const String pbUrl = 'https://api.needil.com';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/update_consultation_fields.dart <email> <password>');
    exit(1);
  }

  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final token = await _adminAuth(client, args[0], args[1]);
    print('✅ Authenticated\n');

    print('📦 Fetching consultations collection...');
    final col = await _getCollection(client, token, 'consultations');
    final colId = col['id'] as String;
    final fields = List<Map<String, dynamic>>.from(col['fields'] as List? ?? []);

    final newFields = [
      'previous_treatments',
      'pain_areas',
      'past_surgeries',
      'sugar_level',
      'vit_d3',
      'vit_b12',
      'thyroid_level',
      'cholesterol_level'
    ];

    for (final f in newFields) {
      _addIfMissing(fields, {
        'name': f,
        'type': 'text',
        'required': false,
        'presentable': false,
        'hidden': false,
        'system': false,
      });
    }

    print('⏳ Patching collection...');
    await _patchCollection(client, token, colId, fields);
    print('\n✅ consultations collection updated.');
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
