import 'dart:convert';
import 'dart:io';

import 'package:studypdf/core/ai/ai_provider.dart';

/// Default model used when the user hasn't picked one yet. Verified against
/// OpenRouter's public model catalog at the time this was written — kept in
/// sync manually since OpenRouter's free-tier lineup changes over time (see
/// [OpenRouterProvider.fetchFreeModels] for the live list).
const String openRouterDefaultModel = 'minimax/minimax-m3:free';

/// A free OpenRouter model, as returned by the models catalog.
class OpenRouterFreeModel {
  const OpenRouterFreeModel({
    required this.id,
    required this.name,
    this.contextLength,
  });

  final String id;
  final String name;
  final int? contextLength;
}

/// OpenRouter is an OpenAI-compatible aggregator that fronts many models
/// (including a rotating catalog of genuinely free ones, no card required)
/// behind a single API key. This is the default AI provider for StudyPDF.
class OpenRouterProvider extends AIProvider {
  const OpenRouterProvider();

  @override
  String get id => 'openrouter';

  @override
  String get displayName => 'OpenRouter';

  @override
  Future<String> sendPrompt({
    required String prompt,
    required String context,
    String? apiKey,
    String? model,
  }) async {
    final key = apiKey?.trim() ?? '';
    if (key.isEmpty) {
      throw Exception(
        'OpenRouter API key is missing. Add it in Settings > AI Settings.',
      );
    }
    final selectedModel = (model == null || model.trim().isEmpty)
        ? openRouterDefaultModel
        : model.trim();

    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      // OpenRouter uses these to attribute usage on its public leaderboards;
      // optional, but good etiquette for a free-tier consumer.
      request.headers.set('HTTP-Referer', 'https://github.com/studypdf');
      request.headers.set('X-Title', 'StudyPDF');

      final userPrompt =
          '''
User request:
$prompt

PDF/Web context:
$context
''';

      final payload = jsonEncode({
        'model': selectedModel,
        'temperature': 0.2,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a study assistant. Use the provided PDF/web context. If context is insufficient, say so explicitly.',
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
          final message =
              error['message']?.toString() ?? 'Unknown OpenRouter error';
          throw Exception(
            'OpenRouter error (${response.statusCode}) on model "$selectedModel": $message',
          );
        }
        throw Exception(
          'OpenRouter request failed with status ${response.statusCode}.',
        );
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw Exception('OpenRouter response did not include any choices.');
      }
      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw Exception('OpenRouter response format is invalid (choice type).');
      }
      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        throw Exception(
          'OpenRouter response format is invalid (message missing).',
        );
      }
      final content = message['content']?.toString().trim() ?? '';
      if (content.isEmpty) {
        throw Exception('OpenRouter returned an empty response.');
      }
      return content;
    } on SocketException catch (e) {
      throw Exception('Network error while contacting OpenRouter: ${e.message}');
    } on FormatException catch (_) {
      throw Exception('Invalid JSON received from OpenRouter.');
    } finally {
      client.close(force: true);
    }
  }

  /// Fetches OpenRouter's current free-tier model catalog (models whose id
  /// ends in `:free`). This is a public, unauthenticated endpoint. Returns
  /// an empty list on any failure rather than throwing, since this is used
  /// to populate a settings dropdown and a network hiccup shouldn't block
  /// the rest of Settings from working.
  Future<List<OpenRouterFreeModel>> fetchFreeModels() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('https://openrouter.ai/api/v1/models'),
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! List) {
        return const [];
      }
      final free = <OpenRouterFreeModel>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final modelId = item['id']?.toString() ?? '';
        if (!modelId.endsWith(':free')) {
          continue;
        }
        free.add(
          OpenRouterFreeModel(
            id: modelId,
            name: item['name']?.toString() ?? modelId,
            contextLength: (item['context_length'] as num?)?.toInt(),
          ),
        );
      }
      free.sort((a, b) => a.name.compareTo(b.name));
      return free;
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }
}
