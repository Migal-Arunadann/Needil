import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://YOUR_POCKETBASE_URL';

Future<void> main() async {
  final email = 'admin@example.com';
  final pw = 'admin_password';
  
  final client = HttpClient();
  try {
    final token = await _adminAuth(client, email, pw);
    final req = await client.getUrl(Uri.parse('$pbUrl/api/collections/appointments'));
    req.headers.set('Authorization', token);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    
    if (res.statusCode == 200) {
      final data = jsonDecode(body);
      final fields = data['fields'] as List;
      for (var f in fields) {
        if (f['name'] == 'type') {
           print('TYPE FIELD: $f');
        }
      }
    } else {
      print('Failed: $body');
    }
  } catch (e) {
    print('Error: $e');
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
