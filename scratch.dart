import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://api.needil.com');
  
  try {
    final result = await pb.collection('sessions').getList(page: 1, perPage: 1);
    if (result.items.isNotEmpty) {
      print(result.items.first.toJson());
    } else {
      print('No sessions found');
    }
  } catch (e) {
    print('Error: $e');
  }
}
