import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final email = 'admin@example.com';
  final pw = 'admin12345';
    String token = '';
  final client = HttpClient();
  try {
    // 1. Authenticate as admin
    final req = await client.postUrl(Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'identity': email, 'password': pw}));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    
    if (res.statusCode != 200) {
      print('Auth failed: $body');
      // We will try without auth to see if it gives a different error.
    } else {
       token = (jsonDecode(body))['token'] as String;
       print('Authenticated with token');
    }
  } catch (e) {
    print('Failed admin auth: $e');
  }

  // Test fetching the appointments schema
  try {
    final queryUrl = '$pbUrl/api/collections/appointments';
    print('Testing query: $queryUrl');
    
    final req2 = await client.getUrl(Uri.parse(queryUrl));
    if (token.isNotEmpty) {
      req2.headers.add('Authorization', 'Bearer $token');
    }
    final res2 = await req2.close();
    final body2 = await res2.transform(utf8.decoder).join();
    print('Response Code: ${res2.statusCode}');
    print('Response Body: $body2');
    
  } catch (e) {
    print('Query Error: $e');
  } finally {
    client.close();
  }
}
