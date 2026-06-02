import 'dart:io';

void main() {
  final file = File('lib/features/patients/screens/patient_profile_screen.dart');
  var lines = file.readAsLinesSync();

  lines[208-1] = lines[208-1].replaceAll('const ', '');
  lines[1162-1] = lines[1162-1].replaceAll('const ', '');
  lines[1294-1] = lines[1294-1].replaceAll('const ', '');
  lines[1334-1] = lines[1334-1].replaceAll('const ', '');

  file.writeAsStringSync(lines.join('\n') + '\n');
}
