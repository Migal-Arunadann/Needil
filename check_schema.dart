import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://localhost:8090');
  try {
    final collection = await pb.collections.getOne('sessions');
    print('Collection: ${collection.name}');
    for (final field in collection.fields) {
      print('- ${field.name} (${field.type})');
    }
  } catch (e) {
    print('Error: $e');
  }
}
