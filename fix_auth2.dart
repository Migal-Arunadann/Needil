import 'dart:io';

void main() {
  final file = File('lib/core/services/auth_service.dart');
  final content = file.readAsStringSync();
  final index = content.indexOf('  String _parseError(ClientException e) {');
  if (index != -1) {
    final newContent = content.substring(0, index) + '''  String _parseError(ClientException e) {
    try {
      return e.toString();
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }
}
''';
    file.writeAsStringSync(newContent);
    print('Fixed');
  } else {
    print('Not found');
  }
}
