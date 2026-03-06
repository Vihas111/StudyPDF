abstract class AIProvider {
  const AIProvider();

  String get id;
  String get displayName;

  Future<String> sendPrompt({
    required String prompt,
    required String context,
    String? apiKey,
  });
}
