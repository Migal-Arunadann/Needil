import 'package:pocketbase/pocketbase.dart';

void main() async {
  try {
    final pb = PocketBase('http://127.0.0.1:8090');
    await pb.admins.authWithPassword('jarvis.ai@gmail.com', 'jarvis.ai');
    
    final sessions = await pb.collection('sessions').getList(
      sort: '+scheduled_date,+scheduled_time,+created',
      perPage: 20,
    );
    
    print('Sorted by scheduled_date,scheduled_time,created:');
    for (final r in sessions.items) {
      final s = 'Num: ' + r.getIntValue('session_number').toString() +
          ' | Date: ' + r.getStringValue('scheduled_date') +
          ' | Time: ' + r.getStringValue('scheduled_time') + 
          ' | ID: ' + r.id;
      print(s);
    }
  } catch (e) {
    print(e);
  }
}
