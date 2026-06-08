import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://api.needil.com';
  
  // 1. Authenticate as Superuser to get a token
  print('Authenticating as Superuser...');
  final authRes = await http.post(
    Uri.parse('$baseUrl/api/collections/_superusers/auth-with-password'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'identity': 'admin@klinik.com', 'password': 'admin@12345'}),
  );
  
  if (authRes.statusCode != 200) {
    print('Failed to authenticate: ${authRes.body}');
    return;
  }
  final token = jsonDecode(authRes.body)['token'];
  print('Got token: ${token.substring(0, 10)}...');

  // 2. Try fetching a file WITH Authorization header
  final fileUrl = '$baseUrl/api/files/pbc_3441013282/955thuiphvgj7tl/scaled_0be389ad_516e_467d_a7b3_a11848f757478341288470619053659_znlj1q2by5.jpg';
  
  print('Fetching file...');
  final fileRes = await http.get(
    Uri.parse(fileUrl),
    headers: {'Authorization': token},
  );
  print('Status code: ${fileRes.statusCode}');
  if (fileRes.statusCode != 200) {
    print('Response: ${fileRes.body}');
  } else {
    print('SUCCESS! File downloaded successfully (${fileRes.bodyBytes.length} bytes)');
  }
}
