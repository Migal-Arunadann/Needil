import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final client = HttpClient();
  
  try {
    // 1. Let's see an existing appointment to grab valid patient, doctor, clinic IDs
    final qReq = await client.getUrl(Uri.parse('$pbUrl/api/collections/appointments/records?page=1&perPage=1'));
    final qRes = await qReq.close();
    final qBody = await qRes.transform(utf8.decoder).join();
    final qJson = jsonDecode(qBody);
    final items = qJson['items'] as List;
    
    if (items.isEmpty) {
        print("No appointments to clone.");
        return;
    }
    
    final validAppt = items.first;
    final patientId = validAppt['patient'];
    final doctorId = validAppt['doctor'];
    final clinicId = validAppt['clinic'];

    // 2. Test inserting 'session' WITHOUT clinic
    var test1Body = {
      'patient': patientId,
      'doctor': doctorId,
      'type': 'session',
      'date': '2026-03-20',
      'time': '10:00',
      'status': 'scheduled',
    };
    
    final req1 = await client.postUrl(Uri.parse('$pbUrl/api/collections/appointments/records'));
    req1.headers.contentType = ContentType.json;
    req1.write(jsonEncode(test1Body));
    final res1 = await req1.close();
    final res1Body = await res1.transform(utf8.decoder).join();
    print('TEST 1 (No Clinic, Type=session) -> ${res1.statusCode}: $res1Body');

    // 3. Test inserting 'session' WITH clinic
    var test2Body = {
      'patient': patientId,
      'doctor': doctorId,
      'clinic': clinicId,
      'type': 'session',
      'date': '2026-03-20',
      'time': '10:00',
      'status': 'scheduled',
    };
    final req2 = await client.postUrl(Uri.parse('$pbUrl/api/collections/appointments/records'));
    req2.headers.contentType = ContentType.json;
    req2.write(jsonEncode(test2Body));
    final res2 = await req2.close();
    final res2Body = await res2.transform(utf8.decoder).join();
    print('TEST 2 (With Clinic, Type=session) -> ${res2.statusCode}: $res2Body');

  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
