import 'package:pocketbase/pocketbase.dart';
void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  try {
    final result = await pb.collection('clinics').getList(filter: 'email="admin@test.com"');
    print('Found: ' + result.items.length.toString());
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
