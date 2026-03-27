import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://YOUR_POCKETBASE_URL');
  
  try {
    // Auth as superuser
    await pb.admins.authWithPassword('admin@example.com', 'admin_password');
    
    for (final col in ['clinics', 'doctors']) {
      // 1. Delete all existing records first to avoid unique constraint violations
      final records = await pb.collection(col).getFullList();
      print('Deleting \${records.length} existing records in $col...');
      for (final r in records) {
        await pb.collection(col).delete(r.id);
      }
      
      // 2. Add username field & unique constraint
      final collectionRecord = await pb.collections.getOne(col);
      final data = collectionRecord.toJson();
      
      final fields = List<Map<String, dynamic>>.from(data['fields'] ?? []);
      if (!fields.any((f) => f['name'] == 'username')) {
        fields.add({
          'name': 'username',
          'type': 'text',
          'required': true,
          'options': {
            'min': 3,
            'max': 100,
            'pattern': '^[a-zA-Z0-9_.]+\$',
          },
        });
      }
      
      final indexes = List<String>.from(data['indexes'] ?? []);
      final idxStr = 'CREATE UNIQUE INDEX `idx_username_${collectionRecord.id}` ON `$col` (`username`)';
      if (!indexes.contains(idxStr)) {
        indexes.add(idxStr);
      }
      
      final authOptions = Map<String, dynamic>.from(data['passwordAuth'] ?? {});
      authOptions['identityFields'] = ['email', 'username'];
      
      // Update collection
      await pb.collections.update(col, body: {
        'fields': fields,
        'indexes': indexes,
        'passwordAuth': authOptions,
      });
      print('✅ $col configured for username auth');
    }
    
  } catch (e) {
    if (e is ClientException) {
      print('PocketBase Error: \${e.response}');
    } else {
      print('Error: \$e');
    }
  }
}
