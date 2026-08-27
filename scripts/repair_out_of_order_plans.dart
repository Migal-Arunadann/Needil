import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';

void main(List<String> args) async {
  final url = Platform.environment['POCKETBASE_URL'] ?? 'https://api.needil.com';
  stdout.write('PocketBase Admin Email [admin@needil.com]: ');
  final emailInput = stdin.readLineSync()?.trim();
  final email = emailInput?.isNotEmpty == true ? emailInput! : 'admin@needil.com';

  stdout.write('PocketBase Admin Password: ');
  final pass = stdin.readLineSync()?.trim() ?? '';

  final pb = PocketBase(url);

  try {
    await pb.admins.authWithPassword(email, pass);
    print('✓ Authenticated as Admin successfully.');
  } catch (e) {
    print('❌ Auth failed: $e');
    return;
  }

  print('\nScanning for out-of-order treatment plans...');
  final plans = await pb.collection('treatment_plans').getFullList(
    filter: 'status = "active" || status = "manual_review"',
  );

  int fixedPlans = 0;

  for (final plan in plans) {
    final sessions = await pb.collection('sessions').getFullList(
      filter: 'treatment_plan = "${plan.id}"',
      sort: 'session_number',
    );

    if (sessions.length < 2) continue;

    bool hasInversion = false;
    for (int i = 1; i < sessions.length; i++) {
      final prevDateStr = sessions[i - 1].getStringValue('scheduled_date');
      final currDateStr = sessions[i].getStringValue('scheduled_date');
      final prevDt = DateTime.tryParse(prevDateStr);
      final currDt = DateTime.tryParse(currDateStr);

      if (prevDt != null && currDt != null) {
        if (!currDt.isAfter(prevDt)) {
          hasInversion = true;
          print('⚠️ Plan ${plan.id} (Patient: ${plan.getStringValue("patient")}) has out-of-order sessions:');
          print('   Session ${sessions[i-1].getIntValue("session_number")} on $prevDateStr');
          print('   Session ${sessions[i].getIntValue("session_number")} on $currDateStr');
          break;
        }
      }
    }

    if (hasInversion) {
      // Re-align sessions from first pending session
      DateTime cursor = DateTime.now();
      final intervalDays = plan.getIntValue('interval_days') > 0 ? plan.getIntValue('interval_days') : 1;

      for (final s in sessions) {
        final status = s.getStringValue('status');
        if (status == 'completed' || status == 'cancelled') {
          final dt = DateTime.tryParse(s.getStringValue('scheduled_date'));
          if (dt != null) cursor = dt.add(Duration(days: intervalDays));
          continue;
        }

        final dateStr = DateFormat('yyyy-MM-dd').format(cursor);
        await pb.collection('sessions').update(s.id, body: {
          'scheduled_date': dateStr,
          'is_rescheduled': true,
        });

        // Sync linked appointments
        final appts = await pb.collection('appointments').getFullList(
          filter: 'linked_session_id = "${s.id}"',
        );
        for (final a in appts) {
          await pb.collection('appointments').update(a.id, body: {
            'date': dateStr,
          });
        }

        print('   -> Realigned Session ${s.getIntValue("session_number")} to $dateStr');
        cursor = cursor.add(Duration(days: intervalDays));
      }
      fixedPlans++;
    }
  }

  print('\n✓ Scan complete. Repaired $fixedPlans out-of-order plan(s).');
}
