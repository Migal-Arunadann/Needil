import 'package:pocketbase/pocketbase.dart';
void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  try {
    await pb.collection('clinics').create(body: {'email':'admin@test.com'});
  } catch (e) {
    print('admin@test.com: ' + e.toString());
  }
  try {
    await pb.collection('clinics').create(body: {'email':'doesnotexist999@test.com'});
  } catch (e) {
    print('doesnotexist999@test.com: ' + e.toString());
  }
}
