import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service that communicates with the self-hosted Ollama instance
/// running phi3:mini on the VPS.
class OllamaService {
  static const String _baseUrl = 'http://178.16.138.198:11434';
  static const String _model = 'phi3:mini';
  static const Duration _timeout = Duration(seconds: 60);

  OllamaService._();
  static final OllamaService instance = OllamaService._();

  /// Cleans up raw voice-dictated medical text into a clear, concise clinical
  /// note. Removes filler words, fixes grammar, and structures the output.
  ///
  /// Returns the cleaned-up text, or throws a [OllamaException] on failure.
  Future<String> summarizeVoiceText(String rawText) async {
    const systemPrompt =
        'You are a precise medical transcription assistant. '
        'Your task is to clean up raw voice-dictated clinical notes. '
        'Remove filler words, fix grammar, correct medical terminology, '
        'and produce a clear and concise clinical note. '
        'Do NOT add any explanations, disclaimers, or extra commentary. '
        'Return ONLY the cleaned medical note text and nothing else.';

    final userPrompt =
        'Clean up this voice-dictated clinical note:\n\n"$rawText"';

    return _generate(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  /// Low-level: calls the Ollama /api/generate endpoint and returns the
  /// complete response string.
  Future<String> _generate({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/generate');

    final body = jsonEncode({
      'model': _model,
      'system': systemPrompt,
      'prompt': userPrompt,
      'stream': false,
      'options': {
        'temperature': 0.3,
        'num_predict': 512,
      },
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw OllamaException(
          'Server returned ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (json['response'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        throw OllamaException('Empty response from Ollama.');
      }
      return text;
    } on OllamaException {
      rethrow;
    } catch (e) {
      throw OllamaException('Failed to reach Ollama: $e');
    }
  }
}

class OllamaException implements Exception {
  final String message;
  const OllamaException(this.message);

  @override
  String toString() => 'OllamaException: $message';
}
