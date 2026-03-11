import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  
  try {
    print('Testing clinic creation...');
    final record = await pb.collection('clinics').create(body: {
      'name': 'Test Clinic',
      'username': 'testclinic99',
      'password': 'password123',
      'passwordConfirm': 'password123',
      'bed_count': 5,
      'clinic_id': 'TST99',
    });
    print('Clinic created! ID: ${record.id}');
    
    print('Testing authWithPassword...');
    final auth = await pb.collection('clinics').authWithPassword('testclinic99', 'password123');
    print('Auth successful! Token: ${auth.token}');
    
  } catch (e) {
    if (e is ClientException) {
      print('PocketBase Error: ${e.response}');
    } else {
      print('Error: $e');
    }
  }
}
