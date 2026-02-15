class LlmProfile {
  final String id;
  final String name;
  final String provider;
  final String apiKey;
  final String endpoint;
  final String model;
  final bool supportsVision;
  final bool supportsText;

  const LlmProfile({
    required this.id,
    required this.name,
    required this.provider,
    required this.apiKey,
    required this.endpoint,
    required this.model,
    required this.supportsVision,
    required this.supportsText,
  });

  LlmProfile copyWith({
    String? id,
    String? name,
    String? provider,
    String? apiKey,
    String? endpoint,
    String? model,
    bool? supportsVision,
    bool? supportsText,
  }) {
    return LlmProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsText: supportsText ?? this.supportsText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider,
        'apiKey': apiKey,
        'endpoint': endpoint,
        'model': model,
        'supportsVision': supportsVision,
        'supportsText': supportsText,
      };

  factory LlmProfile.fromJson(Map<String, dynamic> json) {
    return LlmProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      provider: json['provider'] as String? ?? 'custom',
      apiKey: json['apiKey'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      model: json['model'] as String? ?? '',
      supportsVision: json['supportsVision'] as bool? ?? true,
      supportsText: json['supportsText'] as bool? ?? true,
    );
  }
}
