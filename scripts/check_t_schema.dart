import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final req = await client.postUrl(Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'identity': 'psairampg@gmail.com', 'password': 'Valam\$13245687'}));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw 'Auth failed: $body';
    final token = (jsonDecode(body))['token'] as String;

    final req2 = await client.getUrl(Uri.parse('$pbUrl/api/collections/treatment_plans'));
    req2.headers.set('Authorization', token);
    final res2 = await req2.close();
    final body2 = await res2.transform(utf8.decoder).join();
    final col = jsonDecode(body2) as Map<String, dynamic>;
    
    final fields = List<Map<String, dynamic>>.from(col['fields'] as List? ?? []);
    print(fields.map((f) => f['name']).toList());
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    client.close();
  }
}
