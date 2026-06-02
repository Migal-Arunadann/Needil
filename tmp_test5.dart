import 'package:pocketbase/pocketbase.dart';
void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  final records = await pb.collection('clinics').getList(perPage:1);
  print('Unauthenticated list length: ' + records.items.length.toString());
}
