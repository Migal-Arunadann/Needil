import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';
  
  print('Authenticating admin...');
  final authRes = await http.post(
    Uri.parse('$baseUrl/api/admins/auth-with-password'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'identity': 'admin@klinik.com',
      'password': 'admin@12345',
    }),
  );

  if (authRes.statusCode != 200) {
    print('Failed to authenticate: ${authRes.statusCode} - ${authRes.body}');
    return;
  }

  final authData = jsonDecode(authRes.body);
  final token = authData['token'] as String;
  print('Authenticated successfully!');

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Admin $token',
  };

  print('Fetching recent treatment plans...');
  final plansRes = await http.get(
    Uri.parse('$baseUrl/api/collections/treatment_plans/records?sort=-created&perPage=10'),
    headers: headers,
  );

  if (plansRes.statusCode != 200) {
    print('Failed to fetch plans: ${plansRes.statusCode} - ${plansRes.body}');
    return;
  }

  final plansData = jsonDecode(plansRes.body);
  final plans = plansData['items'] as List;
  
  for (var plan in plans) {
    final planId = plan['id'];
    final patientId = plan['patient'];
    final consultId = plan['consultation'];
    final status = plan['status'];
    
    // Fetch patient name
    var patientName = 'Unknown';
    try {
      final patRes = await http.get(
        Uri.parse('$baseUrl/api/collections/patients/records/$patientId'),
        headers: headers,
      );
      if (patRes.statusCode == 200) {
        final pat = jsonDecode(patRes.body);
        patientName = pat['full_name'] ?? 'Unknown';
      }
    } catch (_) {}

    print('\nPlan: ID=$planId, Patient=$patientName, Consultation=$consultId, Status=$status');

    final sessionsRes = await http.get(
      Uri.parse('$baseUrl/api/collections/sessions/records?filter=treatment_plan="${planId}"&sort=session_number'),
      headers: headers,
    );
    if (sessionsRes.statusCode == 200) {
      final sessionsData = jsonDecode(sessionsRes.body);
      final sessions = sessionsData['items'] as List;
      for (var s in sessions) {
        print('  Session #${s['session_number']}: ID=${s['id']}, Date=${s['scheduled_date']}, Status=${s['status']}');
      }
    } else {
      print('  Failed to fetch sessions: ${sessionsRes.body}');
    }
  }
}
