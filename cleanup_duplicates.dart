import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://127.0.0.1:8090');
  
  // Authenticate as superuser to make sure we have permissions to fix the database
  try {
    await pb.admins.authWithPassword('admin@needil.com', 'admin1234');
    print('✅ Authenticated as admin');
  } catch (e) {
    print('⚠️ Admin auth failed. Attempting as normal user or assuming already authenticated. Error: $e');
  }

  // 1. Fetch all appointments scheduled for today that might be duplicated.
  // We'll look for appointments with the same linked_session_id.
  print('\nFetching appointments...');
  
  int deletedCount = 0;
  
  try {
    // Fetch all appointments. We'll group them by linked_session_id.
    final result = await pb.collection('appointments').getList(
      filter: 'linked_session_id != ""',
      perPage: 500,
    );
    
    final grouped = <String, List<RecordModel>>{};
    
    for (final appt in result.items) {
      final sessionId = appt.getStringValue('linked_session_id');
      grouped.putIfAbsent(sessionId, () => []).add(appt);
    }
    
    // Now look for any session that has MORE THAN ONE appointment linked to it
    for (final entry in grouped.entries) {
      final sessionId = entry.key;
      final appts = entry.value;
      
      if (appts.length > 1) {
        print('Found ${appts.length} appointments for Session $sessionId. Keeping one, deleting the rest...');
        
        // Sort by created date, keep the first one, delete the rest
        appts.sort((a, b) => a.created.compareTo(b.created));
        
        final keep = appts.first;
        final toDelete = appts.sublist(1);
        
        for (final appt in toDelete) {
          try {
            await pb.collection('appointments').delete(appt.id);
            deletedCount++;
            print('   Deleted duplicate appointment ${appt.id}');
          } catch (e) {
            print('   Failed to delete ${appt.id}: $e');
          }
        }
      }
    }
    
    print('\n✅ Cleanup complete. Deleted $deletedCount duplicate appointments.');
    
  } catch (e) {
    print('❌ Error during cleanup: $e');
  }
}
