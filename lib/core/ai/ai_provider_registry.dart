import 'package:studypdf/core/ai/ai_provider.dart';
import 'package:studypdf/core/ai/providers/gemini_provider.dart';
import 'package:studypdf/core/ai/providers/groq_provider.dart';
import 'package:studypdf/core/ai/providers/openai_provider.dart';
import 'package:studypdf/core/ai/providers/ollama_provider.dart';

class AIProviderRegistry {
  AIProviderRegistry()
    : _providers = const {
        'openai': OpenAIProvider(),
        'groq': GroqProvider(),
        'gemini': GeminiProvider(),
        'ollama': OllamaProvider(),
      };

  final Map<String, AIProvider> _providers;

  AIProvider resolve(String id) {
    return _providers[id] ?? const OpenAIProvider();
  }

  List<AIProvider> get all => _providers.values.toList(growable: false);
}
