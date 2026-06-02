import 'package:pocketbase/pocketbase.dart';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final pb = PocketBase(pbUrl);
  
  final body = {
    'patient': '4qhb3ce7cmco6pq', // valid-looking format
    'doctor': 'z44b9r3f1y9q9w2', 
    'type': 'session', 
    'date': '2026-03-20',
    'time': '10:00',
    'status': 'scheduled',
  };

  try {
    await pb.collection('appointments').create(body: body);
    print('SUCCESS');
  } on ClientException catch (e) {
    print('POCKETBASE VALIDATION ERROR:');
    print(e.response);
  } catch (e) {
    print('OTHER ERROR: $e');
  }
}
