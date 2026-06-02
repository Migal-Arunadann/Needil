import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final client = HttpClient();
  try {
    final queryUrl = '$pbUrl/api/collections/appointments/records?page=1&perPage=5';
    final req = await client.getUrl(Uri.parse(queryUrl));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    
    if (res.statusCode == 200) {
      final json = jsonDecode(body);
      final items = json['items'] as List;
      for (var item in items) {
        print('Appt: ${item['type']} | ${item['status']}');
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
