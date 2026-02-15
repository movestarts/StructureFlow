import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/ai_review_record.dart';
import '../../services/database_service.dart';
import '../theme/app_theme.dart';

class OperationAnalysisScreen extends StatefulWidget {
  const OperationAnalysisScreen({super.key});

  @override
  State<OperationAnalysisScreen> createState() => _OperationAnalysisScreenState();
}

class _OperationAnalysisScreenState extends State<OperationAnalysisScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  bool _isLoading = true;
  String? _error;
  List<AiReviewRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _databaseService.loadAiReviews();
      if (!mounted) return;
      setState(() {
        _records = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.bgCard : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('操作分析'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : _records.isEmpty
                  ? Center(
                      child: Text(
                        '暂无AI分析记录',
                        style: TextStyle(color: textMuted, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final item = _records[index];
                        final scoreColor =
                            item.score >= 70 ? AppColors.bullish : AppColors.warning;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () => _showDetail(item),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.instrumentCode} · ${item.period}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.score}',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_dateFmt.format(item.createdAt)}  关联仓位: ${item.tradeIds.length}',
                                    style: TextStyle(color: textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Future<void> _showDetail(AiReviewRecord item) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final content = StringBuffer()
          ..writeln('总评: ${item.summary}');
        if (item.strengths.isNotEmpty) {
          content.writeln('\n优点:');
          for (final s in item.strengths) {
            content.writeln('- $s');
          }
        }
        if (item.risks.isNotEmpty) {
          content.writeln('\n问题:');
          for (final s in item.risks) {
            content.writeln('- $s');
          }
        }
        if (item.suggestions.isNotEmpty) {
          content.writeln('\n建议:');
          for (final s in item.suggestions) {
            content.writeln('- $s');
          }
        }

        return AlertDialog(
          title: Text('AI分析 · ${item.score}分'),
          content: SingleChildScrollView(
            child: Text(content.toString().trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
