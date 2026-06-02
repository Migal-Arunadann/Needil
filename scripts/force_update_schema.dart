import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/force_update_schema.dart <admin_email> <admin_password>');
    exit(1);
  }
  
  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final token = await _adminAuth(client, args[0], args[1]);
    
    print('📦 Fetching appointments collection...');
    final req = await client.getUrl(Uri.parse('$pbUrl/api/collections/appointments'));
    req.headers.set('Authorization', token);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final col = jsonDecode(body) as Map<String, dynamic>;
    
    final fields = List<Map<String, dynamic>>.from(col['fields'] as List? ?? []);
    
    // Find type field and update it
    final typeField = fields.firstWhere((f) => f['name'] == 'type');
    typeField['values'] = ['call_by', 'walk_in', 'session'];
    
    // Find status field and make sure it has all statuses
    final statusField = fields.firstWhere((f) => f['name'] == 'status');
    statusField['values'] = ['scheduled', 'in_progress', 'completed', 'cancelled', 'waiting'];
    
    print('🚀 Updating schema...');
    final patchReq = await client.openUrl('PATCH', Uri.parse('$pbUrl/api/collections/${col['id']}'));
    patchReq.headers.contentType = ContentType.json;
    patchReq.headers.set('Authorization', token);
    patchReq.write(jsonEncode({'fields': fields}));
    
    final patchRes = await patchReq.close();
    final patchBody = await patchRes.transform(utf8.decoder).join();
    if (patchRes.statusCode == 200) {
      print('✅ Schema updated successfully!');
    } else {
      print('❌ Failed to patch: $patchBody');
    }
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    client.close();
  }
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
