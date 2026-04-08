import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    // We may need admin auth if the collection schema is protected. Let's try auth first.
    final authRes = await http.post(
      Uri.parse('http://127.0.0.1:8090/api/admins/auth-with-password'),
      body: jsonEncode({'identity': 'admin@pms.com', 'password': 'admin_password'}), // adjust or skip if no credentials
      headers: {'Content-Type': 'application/json'},
    );
    String token = '';
    if (authRes.statusCode == 200) {
      token = jsonDecode(authRes.body)['token'];
    }

    final headers = token.isNotEmpty ? {'Authorization': token} : <String, String>{};

    final sessRes = await http.get(Uri.parse('http://127.0.0.1:8090/api/collections/sessions'), headers: headers);
    print('sessions schema:');
    print(sessRes.body);

    final apptRes = await http.get(Uri.parse('http://127.0.0.1:8090/api/collections/appointments'), headers: headers);
    print('\nappointments schema:');
    print(apptRes.body);

  } catch(e) {
    print(e);
  }
}
