class AISettings {
  const AISettings({required this.provider, required this.model, this.apiKey});

  final String provider;
  final String model;
  final String? apiKey;
}
