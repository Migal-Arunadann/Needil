import 'dart:io';

void main() async {
  final lines = await File('analyze_machine_utf8.txt').readAsLines();
  final errors = lines.where((l) => l.contains('error -')).toList();
  
  Map<String, List<int>> fileToLines = {};
  for (var err in errors) {
    if (err.contains('Invalid constant value') || 
        err.contains('Const variables must be initialized') || 
        err.contains('The fields in a const record literal must be constants') || 
        err.contains('The values in a const list literal must be constants') ||
        err.contains('The default value of an optional parameter must be constant')) {
      final parts = err.split(' - ');
      final fileInfo = parts[2].split(':'); 
      final filePath = fileInfo[0].trim();
      final lineNum = int.parse(fileInfo[1]);
      
      fileToLines.putIfAbsent(filePath, () => []).add(lineNum);
    }
  }

  int fixedCount = 0;
  for (var filePath in fileToLines.keys) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    
    final fileLines = await file.readAsLines();
    final errorLines = fileToLines[filePath]!.toSet();
    bool modified = false;
    
    for (var lineNum in errorLines) {
      if (lineNum - 1 < fileLines.length) {
        // scan backwards up to 15 lines to find the nearest 'const '
        int scanStart = lineNum - 1;
        int minScan = scanStart - 15;
        if (minScan < 0) minScan = 0;
        
        for (int i = scanStart; i >= minScan; i--) {
           String line = fileLines[i];
           if (line.contains('const ')) {
              // we only want to replace the LAST occurrence of 'const ' on that line
              int lastIndex = line.lastIndexOf('const ');
              line = line.replaceRange(lastIndex, lastIndex + 6, '');
              fileLines[i] = line;
              modified = true;
              fixedCount++;
              break;
           }
        }
      }
    }
    
    if (modified) {
      await file.writeAsString(fileLines.join('\n'));
    }
  }
  print('Removed const from $fixedCount lines.');
}
