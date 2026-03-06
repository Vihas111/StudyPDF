import 'dart:convert';
import 'dart:io';

import 'package:studypdf/core/ai/ai_provider.dart';

class GroqProvider extends AIProvider {
  const GroqProvider();

  @override
  String get id => 'groq';

  @override
  String get displayName => 'Groq';

  @override
  Future<String> sendPrompt({
    required String prompt,
    required String context,
    String? apiKey,
  }) async {
    final key = apiKey?.trim() ?? '';
    if (key.isEmpty) {
      throw Exception(
        'Groq API key is missing. Add it in Settings > AI Settings.',
      );
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );

      final userPrompt =
          '''
User request:
$prompt

PDF/Web context:
$context
''';

      final payload = jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'temperature': 0.2,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a study assistant. Use provided context and be concise, clear, and accurate.',
          },
          {'role': 'user', 'content': userPrompt},
        ],
      });

      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString() ?? 'Unknown Groq error';
          throw Exception('Groq error (${response.statusCode}): $message');
        }
        throw Exception(
          'Groq request failed with status ${response.statusCode}.',
        );
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw Exception('Groq response did not include any choices.');
      }
      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw Exception('Groq response format is invalid (choice type).');
      }
      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        throw Exception('Groq response format is invalid (message missing).');
      }
      final content = message['content']?.toString().trim() ?? '';
      if (content.isEmpty) {
        throw Exception('Groq returned an empty response.');
      }
      return content;
    } on SocketException catch (e) {
      throw Exception('Network error while contacting Groq: ${e.message}');
    } on FormatException catch (_) {
      throw Exception('Invalid JSON received from Groq.');
    } finally {
      client.close(force: true);
    }
  }
}
