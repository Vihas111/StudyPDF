import 'dart:convert';
import 'dart:io';

import 'package:studypdf/core/ai/ai_provider.dart';

class GeminiProvider extends AIProvider {
  const GeminiProvider();

  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  Future<String> sendPrompt({
    required String prompt,
    required String context,
    String? apiKey,
  }) async {
    final key = apiKey?.trim() ?? '';
    if (key.isEmpty) {
      throw Exception(
        'Gemini API key is missing. Add it in Settings > AI Settings.',
      );
    }

    final client = HttpClient();
    try {
      final modelCandidates = await _resolveModelCandidates(client, key);

      final userPrompt =
          '''
User request:
$prompt

PDF context:
$context
''';

      final payload = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'You are a study assistant. Use the provided PDF context. If context is insufficient, say so explicitly.',
              },
              {'text': userPrompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.2},
      });

      for (final model in modelCandidates) {
        for (final version in const ['v1beta', 'v1']) {
          final responseText = await _tryGenerate(
            client: client,
            apiKey: key,
            apiVersion: version,
            model: model,
            payload: payload,
          );
          if (responseText != null) {
            return responseText;
          }
        }
      }

      throw Exception(
        'No compatible Gemini model was available for this API key. Try another key or check model access in Google AI Studio.',
      );
    } on SocketException catch (e) {
      throw Exception('Network error while contacting Gemini: ${e.message}');
    } on FormatException catch (_) {
      throw Exception('Invalid JSON received from Gemini.');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<String>> _resolveModelCandidates(
    HttpClient client,
    String key,
  ) async {
    final discovered = await _listModels(client, key);
    if (discovered.isNotEmpty) {
      return discovered;
    }
    return const [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ];
  }

  Future<List<String>> _listModels(HttpClient client, String key) async {
    final request = await client.getUrl(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models'),
    );
    request.headers.set('x-goog-api-key', key);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final models = decoded['models'];
    if (models is! List) {
      return const [];
    }

    final out = <String>[];
    for (final item in models) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final methodsRaw = item['supportedGenerationMethods'];
      final methods = (methodsRaw is List)
          ? methodsRaw
                .map((m) => m.toString().toLowerCase())
                .toList(growable: false)
          : const <String>[];
      if (!methods.contains('generatecontent')) {
        continue;
      }

      final nameRaw = item['name']?.toString() ?? '';
      final baseRaw = item['baseModelId']?.toString() ?? '';
      final modelName = baseRaw.isNotEmpty
          ? baseRaw
          : nameRaw.replaceFirst(RegExp(r'^models/'), '');
      if (modelName.startsWith('gemini-')) {
        out.add(modelName);
      }
    }

    final deduped = <String>{...out}.toList(growable: false);
    deduped.sort((a, b) => a.compareTo(b));
    return deduped.reversed.toList(growable: false);
  }

  Future<String?> _tryGenerate({
    required HttpClient client,
    required String apiKey,
    required String apiVersion,
    required String model,
    required String payload,
  }) async {
    final request = await client.postUrl(
      Uri.parse(
        'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent',
      ),
    );
    request.headers.set('x-goog-api-key', apiKey);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    request.add(utf8.encode(payload));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = (error is Map<String, dynamic>)
          ? error['message']?.toString() ?? ''
          : '';
      final lower = message.toLowerCase();
      final modelUnavailable =
          response.statusCode == 404 ||
          lower.contains('not found') ||
          lower.contains('not supported');
      if (modelUnavailable) {
        return null;
      }
      throw Exception(
        'Gemini error (${response.statusCode}) on model "$model": ${message.isEmpty ? 'Request failed' : message}',
      );
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return null;
    }
    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      return null;
    }
    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      return null;
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return null;
    }

    final text = parts
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text']?.toString() ?? '')
        .join('\n')
        .trim();
    return text.isEmpty ? null : text;
  }
}
