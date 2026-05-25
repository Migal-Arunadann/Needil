import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://api.needil.com'); // Assuming local backend
  try {
    await pb.admins.authWithPassword('admin@pms.com', 'admin123'); // Or some common admin, but we might not need auth if read is public
  } catch(e) {
    print('Auth failed, continuing as guest: $e');
  }

  try {
    final result = await pb.collection('sessions').getList(perPage: 1);
    if (result.items.isNotEmpty) {
      print('First session data:');
      print(result.items.first.toJson());
    } else {
      print('No sessions found.');
    }
  } catch (e) {
    print('Error fetching sessions: $e');
  }
}
