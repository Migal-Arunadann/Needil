library;

import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://127.0.0.1:8090';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/add_appointment_workflow_fields.dart <admin_email> <admin_password>');
    exit(1);
  }
  
  final client = HttpClient();
  try {
    print('🔐 Authenticating as Admin...');
    final token = await _adminAuth(client, args[0], args[1]);
    print('✅ Authenticated\n');

    print('📦 Fetching appointments collection...');
    final aCol = await _getCollection(client, token, 'appointments');
    final aFields = List<Map<String, dynamic>>.from(aCol['fields'] as List? ?? []);

    _addIfMissing(aFields, {'name': 'consultation_end_time', 'type': 'date', 'required': false});
    _addIfMissing(aFields, {'name': 'patient_details_saved', 'type': 'bool', 'required': false});
    _addIfMissing(aFields, {'name': 'patient_details_partial', 'type': 'bool', 'required': false});
    _addIfMissing(aFields, {'name': 'treatment_plan_partial', 'type': 'bool', 'required': false});
    _addIfMissing(aFields, {'name': 'linked_treatment_plan_id', 'type': 'text', 'required': false});

    await _patchCollection(client, token, aCol['id'] as String, aFields);
    print('\n🎉 All workflow fields added to appointments collection!');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

void _addIfMissing(List<Map<String, dynamic>> fields, Map<String, dynamic> field) {
  final name = field['name'] as String;
  if (!fields.any((f) => f['name'] == name)) {
    fields.add(field);
    print('   + Queueing field: $name (${field['type']})');
  } else {
    print('   ✓ Already exists: $name');
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
