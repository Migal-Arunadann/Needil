import 'package:pocketbase/pocketbase.dart';
import 'dart:convert';

void main() async {
  final pb = PocketBase('http://YOUR_POCKETBASE_URL');
  await pb.admins.authWithPassword('admin@example.com', 'admin_password');
  
  final collection = await pb.collections.getOne('treatment_plans');
  print('Treatment Plans Schema:');
  print(jsonEncode(collection.toJson()));
}
