import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final client = HttpClient();
  
  // Test body replicating the exact payload from TreatmentService
  final body = {
    'patient': '4qhb3ce7cmco6pq', // Using any valid-looking patient ID or blank
    'doctor': 'z44b9r3f1y9q9w2', // Any valid-looking doctor ID
    'type': 'session', // THIS is what likely fails
    'date': '2026-03-20',
    'time': '10:00',
    'status': 'scheduled',
  };

  try {
    final req = await client.postUrl(Uri.parse('$pbUrl/api/collections/appointments/records'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();
    
    print('STATUS: ${res.statusCode}');
    print('RESPONSE: $resBody');
    
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
