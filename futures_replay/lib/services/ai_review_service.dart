import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class AiReviewResult {
  final int score;
  final String summary;
  final List<String> strengths;
  final List<String> risks;
  final List<String> suggestions;
  final String raw;

  const AiReviewResult({
    required this.score,
    required this.summary,
    required this.strengths,
    required this.risks,
    required this.suggestions,
    required this.raw,
  });
}

class AiReviewService {
  static const String _defaultEndpoint =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const String _defaultModel = 'glm-4.6v-flash';

  String _resolveApiKey() {
    final byDefine = const String.fromEnvironment(
      'ZHIPU_API_KEY',
      defaultValue: '',
    );
    if (byDefine.isNotEmpty) return byDefine;

    try {
      return Platform.environment['ZHIPU_API_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<AiReviewResult> reviewChartImage({
    required String imageBase64,
    required String userPrompt,
    String? apiKey,
    String? endpoint,
    String? model,
  }) async {
    final finalApiKey = (apiKey ?? '').trim().isNotEmpty
        ? apiKey!.trim()
        : _resolveApiKey();
    if (finalApiKey.isEmpty) {
      throw Exception(
        'Missing ZHIPU_API_KEY. Please pass --dart-define=ZHIPU_API_KEY=xxx',
      );
    }
    final finalEndpoint = (endpoint ?? '').trim().isEmpty
        ? _defaultEndpoint
        : endpoint!.trim();
    final finalModel =
        (model ?? '').trim().isEmpty ? _defaultModel : model!.trim();

    final payload = {
      'model': finalModel,
      'temperature': 0.2,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': 'You are a professional trading review copilot.',
        },
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': _buildPrompt(userPrompt.trim())},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/png;base64,$imageBase64'},
            },
          ],
        },
      ],
    };

    final resp = await http.post(
      Uri.parse(finalEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $finalApiKey',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('LLM request failed(${resp.statusCode}): ${resp.body}');
    }

    final obj = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = (obj['choices'] as List?) ?? const [];
    if (choices.isEmpty) {
      throw Exception('LLM response has no choices');
    }
    final msg =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
    final content = _readMessageContent(msg['content']);
    if (content.isEmpty) {
      throw Exception('LLM response content is empty');
    }

    final normalized = _extractFirstValidJsonObject(content);
    final data = jsonDecode(normalized) as Map<String, dynamic>;
    return AiReviewResult(
      score: ((data['score'] as num?)?.toInt() ?? 0).clamp(0, 100) as int,
      summary: (data['summary'] as String?) ?? '',
      strengths: _toStringList(data['strengths']),
      risks: _toStringList(data['risks']),
      suggestions: _toStringList(data['suggestions']),
      raw: normalized,
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  String _readMessageContent(dynamic rawContent) {
    if (rawContent is String) return rawContent.trim();
    if (rawContent is List) {
      final parts = <String>[];
      for (final item in rawContent) {
        if (item is Map<String, dynamic>) {
          final text = item['text'];
          if (text is String && text.trim().isNotEmpty) {
            parts.add(text.trim());
          }
        }
      }
      return parts.join('\n').trim();
    }
    return '';
  }

  String _extractFirstValidJsonObject(String text) {
    final cleaned = _cleanupModelText(text);
    if (cleaned.isEmpty) return cleaned;

    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) return cleaned;
    } catch (_) {
      // Not a pure JSON blob; continue extracting.
    }

    final candidates = <String>[];
    int depth = 0;
    int start = -1;
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{') {
        if (depth == 0) start = i;
        depth += 1;
      } else if (ch == '}') {
        if (depth > 0) {
          depth -= 1;
          if (depth == 0 && start >= 0) {
            candidates.add(cleaned.substring(start, i + 1));
            start = -1;
          }
        }
      }
    }

    for (final c in candidates) {
      try {
        final decoded = jsonDecode(c);
        if (decoded is Map<String, dynamic>) {
          return c;
        }
      } catch (_) {
        // Try next candidate.
      }
    }

    // Fallback to previous behavior for compatibility.
    final first = cleaned.indexOf('{');
    final last = cleaned.lastIndexOf('}');
    if (first >= 0 && last > first) {
      return cleaned.substring(first, last + 1);
    }
    return cleaned;
  }

  String _cleanupModelText(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll(
      RegExp(r'```(?:json)?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'```'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'<think\b[^>]*>[\s\S]*?<\/think>', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<\/?think\b[^>]*>', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  String _buildPrompt(String userPrompt) {
    return '''
You are a strict, professional trading review coach.
Based on the chart image and user context, output a standardized review.
User context:
$userPrompt

Output must be pure JSON (no markdown), with fields:
{
  "score": integer 0-100,
  "summary": "one-sentence verdict",
  "strengths": ["up to 3 strengths"],
  "risks": ["up to 3 issues"],
  "suggestions": ["up to 3 actionable suggestions"]
}
''';
  }
}
