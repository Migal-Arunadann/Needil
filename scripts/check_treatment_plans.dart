import 'package:pocketbase/pocketbase.dart';
import 'dart:convert';

void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  await pb.admins.authWithPassword('admin@pms.com', 'admin123456');
  
  final collection = await pb.collections.getOne('treatment_plans');
  print('Treatment Plans Schema:');
  print(jsonEncode(collection.toJson()));
}
