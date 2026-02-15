import '../services/ai_review_service.dart';

class AiReviewRecord {
  final String id;
  final DateTime createdAt;
  final String instrumentCode;
  final String period;
  final String prompt;
  final int score;
  final String summary;
  final List<String> strengths;
  final List<String> risks;
  final List<String> suggestions;
  final String rawJson;
  final List<String> tradeIds;

  const AiReviewRecord({
    required this.id,
    required this.createdAt,
    required this.instrumentCode,
    required this.period,
    required this.prompt,
    required this.score,
    required this.summary,
    required this.strengths,
    required this.risks,
    required this.suggestions,
    required this.rawJson,
    required this.tradeIds,
  });

  factory AiReviewRecord.fromResult({
    required String id,
    required DateTime createdAt,
    required String instrumentCode,
    required String period,
    required String prompt,
    required AiReviewResult result,
    required List<String> tradeIds,
  }) {
    return AiReviewRecord(
      id: id,
      createdAt: createdAt,
      instrumentCode: instrumentCode,
      period: period,
      prompt: prompt,
      score: result.score,
      summary: result.summary,
      strengths: List<String>.from(result.strengths),
      risks: List<String>.from(result.risks),
      suggestions: List<String>.from(result.suggestions),
      rawJson: result.raw,
      tradeIds: List<String>.from(tradeIds),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'instrumentCode': instrumentCode,
        'period': period,
        'prompt': prompt,
        'score': score,
        'summary': summary,
        'strengths': strengths,
        'risks': risks,
        'suggestions': suggestions,
        'rawJson': rawJson,
        'tradeIds': tradeIds,
      };

  factory AiReviewRecord.fromJson(Map<String, dynamic> json) {
    return AiReviewRecord(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      instrumentCode: json['instrumentCode'] as String? ?? '',
      period: json['period'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? '',
      strengths: _toStringList(json['strengths']),
      risks: _toStringList(json['risks']),
      suggestions: _toStringList(json['suggestions']),
      rawJson: json['rawJson'] as String? ?? '',
      tradeIds: _toStringList(json['tradeIds']),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
}
