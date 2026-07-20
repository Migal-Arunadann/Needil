import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://127.0.0.1:8090');
  try {
    final result = await pb.collection('patients').getList(
      filter: 'phone = "7401001939" || phone = "7401001930"',
    );
    print('Found ${result.items.length} patients');
    for (var r in result.items) {
      print('Patient: ${r.getStringValue('full_name')}, phone: ${r.getStringValue('phone')}, clinic: ${r.getStringValue('clinic')}, doctor: ${r.getStringValue('doctor')}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
