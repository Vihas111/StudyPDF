import 'package:studypdf/core/ai/ai_provider.dart';

class OllamaProvider extends AIProvider {
  const OllamaProvider();

  @override
  String get id => 'ollama';

  @override
  String get displayName => 'Ollama';

  @override
  Future<String> sendPrompt({
    required String prompt,
    required String context,
    String? apiKey,
  }) async {
    return 'Ollama mock response for: $prompt';
  }
}
