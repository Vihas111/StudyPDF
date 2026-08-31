import 'package:studypdf/core/ai/ai_provider.dart';
import 'package:studypdf/core/ai/providers/gemini_provider.dart';
import 'package:studypdf/core/ai/providers/groq_provider.dart';
import 'package:studypdf/core/ai/providers/openai_provider.dart';
import 'package:studypdf/core/ai/providers/ollama_provider.dart';
import 'package:studypdf/core/ai/providers/openrouter_provider.dart';

class AIProviderRegistry {
  AIProviderRegistry()
    : _providers = const {
        // OpenRouter first: it's the default provider (one free-tier key
        // instead of juggling a separate signup per provider).
        'openrouter': OpenRouterProvider(),
        'openai': OpenAIProvider(),
        'groq': GroqProvider(),
        'gemini': GeminiProvider(),
        'ollama': OllamaProvider(),
      };

  final Map<String, AIProvider> _providers;

  AIProvider resolve(String id) {
    return _providers[id] ?? const OpenRouterProvider();
  }

  List<AIProvider> get all => _providers.values.toList(growable: false);
}
