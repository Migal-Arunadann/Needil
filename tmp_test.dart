import 'package:pocketbase/pocketbase.dart';
void main() async {
  final pb = PocketBase('http://127.0.0.1:8090');
  try {
    final result = await pb.collection('clinics').getList(filter: 'email="admin@test.com"');
    print('Found: ' + result.items.length.toString());
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
