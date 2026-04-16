import 'package:pocketbase/pocketbase.dart';
void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  try { await pb.collection('clinics').requestPasswordReset('doesnotexist1111@test.com'); print('doesnotexist returned success (204)'); } catch (e) { print('doesnotexist error: ' + e.toString()); }
  try { await pb.collection('clinics').requestPasswordReset('admin@test.com'); print('admin returned success (204)'); } catch (e) { print('admin error: ' + e.toString()); }
}
