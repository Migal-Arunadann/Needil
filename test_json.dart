import 'dart:convert';

void main() {
  final jsonStr = '{"day":"Monday","start":"09:00","end":"17:00","breaks":[{"start":"13:00","end":"14:00"}]}';
  final json = jsonDecode(jsonStr);
  print(json['breaks'].runtimeType); // e.g. List<dynamic>
  
  try {
    List<Map<String, String>> breaks = [];
    final rawBreaks = json['breaks'];
    if (rawBreaks is List && rawBreaks.isNotEmpty) {
      breaks = rawBreaks.map((b) {
        final m = b as Map<String, dynamic>;
        return {'start': m['start'] as String, 'end': m['end'] as String};
      }).toList();
    }
    print('Parsed breaks: $breaks');
  } catch (e) {
    print('Error: $e');
  }
}
