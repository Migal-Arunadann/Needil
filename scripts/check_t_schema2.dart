import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'identity': 'psairampg@gmail.com', 'password': 'Valam\$13245687'}));
    final res = await req.close();
    final token = (jsonDecode(await res.transform(utf8.decoder).join()))['token'] as String;

    final req2 = await client.getUrl(Uri.parse('$pbUrl/api/collections/treatment_plans'));
    req2.headers.set('Authorization', token);
    final res2 = await req2.close();
    print(await res2.transform(utf8.decoder).join());
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    client.close();
  }
}
