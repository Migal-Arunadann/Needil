import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://api.needil.com';
  
  try {
    print('Querying sessions...');
    final res = await http.get(Uri.parse('$baseUrl/api/collections/sessions/records?page=1&perPage=10&sort=-created'));
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['items'] as List;
      print('Found ${items.length} sessions:');
      for (var item in items) {
        print('  ID=${item['id']}, plan=${item['treatment_plan']}, num=${item['session_number']}, date=${item['scheduled_date']}, status=${item['status']}');
      }
    } else {
      print('Body: ${res.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
