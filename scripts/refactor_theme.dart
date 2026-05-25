import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found');
    return;
  }

  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  final colorRegex = RegExp(r'\bAppColors\.([a-zA-Z0-9_]+)');
  final styleRegex = RegExp(r'\bAppTextStyles\.([a-zA-Z0-9_]+)');
  
  final ignoredFiles = [
    'app_colors.dart',
    'app_text_styles.dart',
    'app_colors_extension.dart',
    'app_text_styles_extension.dart',
    'app_theme.dart',
  ];

  int totalFilesModified = 0;

  for (final file in files) {
    if (ignoredFiles.any((i) => file.path.endsWith(i))) continue;

    String content = await file.readAsString();
    bool modified = false;

    if (colorRegex.hasMatch(content)) {
      content = content.replaceAllMapped(colorRegex, (match) {
        return 'context.colors.${match.group(1)}';
      });
      modified = true;
    }

    if (styleRegex.hasMatch(content)) {
      content = content.replaceAllMapped(styleRegex, (match) {
        return 'context.textStyles.${match.group(1)}';
      });
      modified = true;
    }

    if (modified) {
      if (!content.contains('package:pms_app/core/theme/app_theme.dart') && 
          !content.contains('app_theme.dart')) {
        // Insert import after the last import statement or at top
        final lines = content.split('\n');
        int lastImportIdx = -1;
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('import ')) {
            lastImportIdx = i;
          }
        }
        
        final importStr = "import 'package:pms_app/core/theme/app_theme.dart';\n";
        if (lastImportIdx != -1) {
          lines.insert(lastImportIdx + 1, importStr);
        } else {
          lines.insert(0, importStr);
        }
        content = lines.join('\n');
      }
      
      await file.writeAsString(content);
      totalFilesModified++;
    }
  }

  print('Successfully refactored $totalFilesModified files.');
}
