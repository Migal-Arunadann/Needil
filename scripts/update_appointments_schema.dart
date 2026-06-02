import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final baseUrl = 'http://YOUR_POCKETBASE_URL';
  final clinicRes = await http.post(
    Uri.parse('\$baseUrl/api/collections/clinics/auth-with-password'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'identity': 'admin@example.com',
      'password': 'admin_password'
    })
  );
}
