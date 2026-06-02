import 'dart:io';

void main() {
  final file = File('lib/features/patients/screens/patient_profile_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''      case SessionStatus.waiting:   return context.colors.warning;''',
    '''      case SessionStatus.waiting:   return context.colors.warning;
      case SessionStatus.inProgress:return context.colors.primary;'''
  );

  content = content.replaceFirst(
    '''      case SessionStatus.waiting:   return 'Waiting';''',
    '''      case SessionStatus.waiting:   return 'Waiting';
      case SessionStatus.inProgress:return 'In Progress';'''
  );

  file.writeAsStringSync(content);
}
