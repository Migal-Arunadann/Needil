import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://api.needil.com';
  
  final credentials = [
    {'email': 'admin@klinik.com', 'pass': 'admin@12345'},
    {'email': 'admin@pms.com', 'pass': 'admin123'},
    {'email': 'admin@example.com', 'pass': 'admin_password'},
    {'email': 'admin@needil.com', 'pass': 'admin123'},
  ];

  for (var cred in credentials) {
    print('Trying ${cred['email']}...');
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admins/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity': cred['email'],
          'password': cred['pass'],
        }),
      );
      print('Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        print('SUCCESS with ${cred['email']}! Token: ${jsonDecode(res.body)['token']}');
        return;
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
