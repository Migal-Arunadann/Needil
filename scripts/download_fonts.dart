import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final fonts = [
    'Inter:wght@400;500;600;700',
    'Plus+Jakarta+Sans:wght@400;500;600;700',
    'Cormorant+Garamond:wght@400;500;600;700'
  ];

  final client = http.Client();

  for (final font in fonts) {
    print('Fetching CSS for $font...');
    final url = Uri.parse('https://fonts.googleapis.com/css2?family=$font');
    // Spoof a really old Android user agent to force Google Fonts to return .ttf files
    final response = await client.get(url, headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; U; Android 4.1.1; en-gb; Build/KLP) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Safari/534.30'
    });

    if (response.statusCode != 200) {
      print('Failed to fetch CSS for $font');
      continue;
    }

    final css = response.body;
    
    // Parse CSS to extract font names and URLs
    final RegExp fontFaceRegex = RegExp(r'@font-face\s*\{([^}]+)\}');
    final matches = fontFaceRegex.allMatches(css);
    
    for (final match in matches) {
      final block = match.group(1)!;
      final familyMatch = RegExp(r"font-family:\s*'([^']+)'").firstMatch(block);
      final weightMatch = RegExp(r"font-weight:\s*(\d+)").firstMatch(block);
      final urlMatch = RegExp(r"url\(([^)]+)\)").firstMatch(block);
      
      if (familyMatch != null && weightMatch != null && urlMatch != null) {
        final family = familyMatch.group(1)!.replaceAll(' ', '');
        final weight = weightMatch.group(1)!;
        final fontUrl = urlMatch.group(1)!;
        
        final weightName = _getWeightName(weight);
        final fileName = '$family-$weightName.ttf';
        
        print('Downloading $fileName from $fontUrl...');
        final fontRes = await client.get(Uri.parse(fontUrl));
        
        if (fontRes.statusCode == 200) {
          final file = File('assets/google_fonts/$fileName');
          await file.writeAsBytes(fontRes.bodyBytes);
          print('Saved $fileName');
        } else {
          print('Failed to download $fileName');
        }
      }
    }
  }
  
  client.close();
  print('Done!');
}

String _getWeightName(String weight) {
  switch (weight) {
    case '100': return 'Thin';
    case '200': return 'ExtraLight';
    case '300': return 'Light';
    case '400': return 'Regular';
    case '500': return 'Medium';
    case '600': return 'SemiBold';
    case '700': return 'Bold';
    case '800': return 'ExtraBold';
    case '900': return 'Black';
    default: return 'Regular';
  }
}
