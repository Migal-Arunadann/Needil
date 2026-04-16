import 'package:pocketbase/pocketbase.dart';
void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  try {
    await pb.collection('clinics').authWithPassword('admin@test.com', 'wrongpassword_123');
  } catch (e) {
    print('admin@test.com exists? ' + e.toString());
  }
  try {
    await pb.collection('clinics').authWithPassword('doesnotexist999@test.com', 'wrongpassword_123');
  } catch (e) {
    print('doesnotexist999@test.com exists? ' + e.toString());
  }
}
