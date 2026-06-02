import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://api.needil.com');
  
  try {
    print('Fetching doctors...');
    final result = await pb.collection('doctors').getList(perPage: 50);
    print('Found ${result.items.length} doctors.');
    for (var doc in result.items) {
      print('Doctor: ID=${doc.id}, Name=${doc.getStringValue('name')}');
      print('  working_schedule raw: ${doc.data['working_schedule']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
