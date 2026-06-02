import 'dart:io';
import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  await pb.admins.authWithPassword('admin@klinik.com', 'admin@12345');

  final plans = await pb.collection('treatment_plans').getList(perPage: 50);
  for (var plan in plans.items) {
    print('Plan ID: ${plan.id}, Patient: ${plan.getStringValue('patient')}, Consult: ${plan.getStringValue('consultation')}');
  }
}
