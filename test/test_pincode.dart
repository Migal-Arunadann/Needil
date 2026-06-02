import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

Future<void> main() async {
  final pin = '560001';
  
  // Test local IOClient with certificate override
  try {
    final innerClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host == 'api.postalpincode.in';
      };
    final client = IOClient(innerClient);
    
    final url = 'https://api.postalpincode.in/pincode/$pin';
    print('GET $url (with local IOClient)');
    final res = await client.get(Uri.parse(url));
    print('Status Code: ${res.statusCode}');
    if (res.body.length > 500) {
      print('Body: ${res.body.substring(0, 500)}');
    } else {
      print('Body: ${res.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
