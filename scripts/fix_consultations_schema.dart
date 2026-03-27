import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://YOUR_POCKETBASE_URL';

Future<void> main() async {
  final email = 'admin@example.com';
  final pw = 'admin_password';
  
  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final token = await _adminAuth(client, email, pw);
    print('✅ Authenticated\\n');

    print('📦 Fetching consultations collection...');
    final col = await _getCollection(client, token, 'consultations');
    final colId = col['id'] as String;

    final fields = List<Map<String, dynamic>>.from(col['fields'] as List? ?? []);

    _addIfMissing(fields, {
      'name': 'status',
      'type': 'select',
      'required': false,
      'presentable': false,
      'hidden': false,
      'system': false,
      'maxSelect': 1,
      'values': ['ongoing', 'completed']
    });

    await _patchCollection(client, token, colId, fields);
    print('✅ consultations fields updated\\n');
    
  } catch (e) {
    print('❌ Error: $e');
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
    print('   ✓ field exists: $name');
  }
}

Future<Map<String, dynamic>> _getCollection(HttpClient client, String token, String name) async {
  final req = await client.getUrl(Uri.parse('$pbUrl/api/collections/$name'));
  req.headers.set('Authorization', token);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'GET $name failed: $body';
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<void> _patchCollection(HttpClient client, String token, String id, List<Map<String, dynamic>> fields) async {
  final req = await client.openUrl('PATCH', Uri.parse('$pbUrl/api/collections/$id'));
  req.headers.contentType = ContentType.json;
  req.headers.set('Authorization', token);
  req.write(jsonEncode({'fields': fields}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'PATCH failed: $body';
}

Future<String> _adminAuth(HttpClient c, String email, String pw) async {
  final req = await c.postUrl(Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'));
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode({'identity': email, 'password': pw}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'Auth failed: $body';
  return (jsonDecode(body))['token'] as String;
}
