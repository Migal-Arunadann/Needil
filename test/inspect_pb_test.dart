import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('inspect PB', () async {
    final pb = PocketBase('https://api.needil.com');
    try {
      print('=== START PB INSPECT ===');
      final sessions = await pb.collection('sessions').getList(perPage: 5, sort: '-created');
      print('Sessions found: ${sessions.items.length}');
      for (var s in sessions.items) {
        print('Session: ID=${s.id}, Patient=${s.getStringValue('patient')}, Date=${s.getStringValue('scheduled_date')}, Time=${s.getStringValue('scheduled_time')}, Num=${s.getIntValue('session_number')}, Status=${s.getStringValue('status')}');
      }

      final appts = await pb.collection('appointments').getList(perPage: 5, sort: '-created', filter: 'type = "session"');
      print('Appointments found: ${appts.items.length}');
      for (var a in appts.items) {
        print('Appt: ID=${a.id}, Patient=${a.getStringValue('patient')}, Date=${a.getStringValue('date')}, Time=${a.getStringValue('time')}, Status=${a.getStringValue('status')}');
      }
      print('=== END PB INSPECT ===');
    } catch (e) {
      print('Error during inspect: $e');
    }
  });
}
