import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://api.needil.com');
  // Need to auth as a clinic to read doctors?
  // Actually let's try reading as admin if possible, or auth with a user.
  // Wait, I don't have the login credentials.
  // Can I read doctors collection without auth?
  try {
    final result = await pb.collection('doctors').getList(page: 1, perPage: 5);
    for (var doc in result.items) {
      print('Doctor: ${doc.getStringValue('name')}');
      print('Schedule: ${doc.getListValue('working_schedule')}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
