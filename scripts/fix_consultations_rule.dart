import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';
  final adminEmail = 'admin@pms.com';
  final adminPassword = 'admin123456';
  
  final client = http.Client();
  try {
    // 1. Authenticate as admin
    final authRes = await client.post(
      Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identity': adminEmail,
        'password': adminPassword,
      }),
    );

    if (authRes.statusCode != 200) {
      print('Auth failed: ${authRes.body}');
      return;
    }

    final token = jsonDecode(authRes.body)['token'];
    print('Auth successful');

    // 2. Fetch the collections to find 'consultations'
    final colsRes = await client.get(
      Uri.parse('$pbUrl/api/collections?perPage=500'),
      headers: {'Authorization': token},
    );

    final colsData = jsonDecode(colsRes.body);
    final items = colsData['items'] as List;
    final consultationsCol = items.firstWhere(
      (c) => c['name'] == 'consultations',
      orElse: () => null,
    );

    if (consultationsCol == null) {
      print('Collection "consultations" not found.');
      return;
    }

    final colId = consultationsCol['id'];
    
    // 3. Update the deleteRule to empty string (public) or specific rule
    // We will set deleteRule to "" (allow all authenticated/unauthenticated depending on other rules, usually "" means anyone can delete) or "@request.auth.id != ''"
    // To match other collections usually it's ""
    final updateBody = {
      'deleteRule': '',
    };

    final updateRes = await client.patch(
      Uri.parse('$pbUrl/api/collections/$colId'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(updateBody),
    );

    if (updateRes.statusCode >= 200 && updateRes.statusCode < 300) {
      print('Successfully updated deleteRule for consultations.');
    } else {
      print('Update failed: ${updateRes.statusCode} - ${updateRes.body}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
