import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final baseUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';
  final clinicRes = await http.post(
    Uri.parse('\$baseUrl/api/collections/clinics/auth-with-password'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'identity': 'admin@example.com', // wait, do we have admin credentials? No, we don't.
      'password': 'password123'
    })
  );
}
