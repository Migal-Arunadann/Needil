import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://127.0.0.1:8090');
  try {
    final result = await pb.collection('patients').getList(
      filter: 'doctor.clinic != ""',
    );
    print('Success: ${result.items.length}');
  } catch (e) {
    print('Error: $e');
  }
}
