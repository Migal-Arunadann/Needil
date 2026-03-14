import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final client = HttpClient();
  
  try {
    final qReq = await client.getUrl(Uri.parse('$pbUrl/api/collections/sessions/records?page=1&perPage=1'));
    final qRes = await qReq.close();
    final qBody = await qRes.transform(utf8.decoder).join();
    
    print('SESSIONS TEST: ${qRes.statusCode}');
    print(qBody);

  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
