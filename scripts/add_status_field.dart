import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://127.0.0.1:8090');
  
  try {
    // Authenticate as admin
    await pb.admins.authWithPassword('admin@example.com', 'admin_password'); // Replace with actual credentials
    print('Authenticated');
  } catch (e) {
    print('Auth failed (ensure admin credentials are correct in the script or run without auth if rules allow): $e');
  }

  try {
    final record = await pb.collections.getOne('consultations');
    
    // Check if status already exists
    final schema = record.schema;
    final exists = schema.any((f) => f.name == 'status');
    
    if (exists) {
      print('Status field already exists!');
      return;
    }

    // Prepare new schema field
    schema.add(
      SchemaField(
        name: 'status',
        type: 'select',
        options: {
          'maxSelect': 1,
          'values': ['ongoing', 'completed'],
        },
      ),
    );

    await pb.collections.update('consultations', body: {
      'schema': schema.map((f) => f.toJson()).toList(),
    });

    print('Successfully added the status field!');
  } catch (e) {
    print('Failed to update schema: $e');
  }
}
