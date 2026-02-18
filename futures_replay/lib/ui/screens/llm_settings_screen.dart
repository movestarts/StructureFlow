import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/llm_profile.dart';
import '../../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'llm_model_management_screen.dart';

class LlmSettingsScreen extends StatelessWidget {
  const LlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.bgCard : Colors.white;
    final textPrimary =
        isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final borderClr = isDark ? AppColors.borderLight : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.lightBg,
      appBar: AppBar(
        title: Text('大模型配置', style: TextStyle(color: textPrimary)),
        iconTheme: IconThemeData(color: textPrimary),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          final visionCandidates = settings.visionEnabledProfiles;
          final textCandidates = settings.textEnabledProfiles;
          final visionId = visionCandidates.any(
                  (e) => e.id == settings.llmVisionProfileId)
              ? settings.llmVisionProfileId
              : (visionCandidates.isNotEmpty ? visionCandidates.first.id : null);
          final textId =
              textCandidates.any((e) => e.id == settings.llmTextProfileId)
                  ? settings.llmTextProfileId
                  : (textCandidates.isNotEmpty ? textCandidates.first.id : null);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  cardBg: cardBg,
                  borderClr: borderClr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '任务绑定',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: visionId,
                        decoration: const InputDecoration(
                          labelText: '图像点评使用模型',
                        ),
                        items: visionCandidates
                            .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text('${e.name} (${e.model})'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          settings.setTaskProfileBinding(visionProfileId: v);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: textId,
                        decoration: const InputDecoration(
                          labelText: '文本分析使用模型',
                        ),
                        items: textCandidates
                            .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text('${e.name} (${e.model})'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          settings.setTaskProfileBinding(textProfileId: v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildCard(
                  cardBg: cardBg,
                  borderClr: borderClr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前图像模型配置',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCurrentProfileInfo(
                        context,
                        settings.getVisionProfile(),
                        textSecondary,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LlmModelManagementScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings_suggest),
                          label: const Text('大模型管理'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '调用时不再手改代码。图像点评固定走“图像点评使用模型”，未来文本复盘走“文本分析使用模型”。',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required Color cardBg,
    required Color borderClr,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderClr),
      ),
      child: child,
    );
  }

  Widget _buildCurrentProfileInfo(
    BuildContext context,
    LlmProfile profile,
    Color textSecondary,
  ) {
    return Text(
      '名称: ${profile.name}\n'
      'Provider: ${profile.provider}\n'
      'Model: ${profile.model}\n'
      'Endpoint: ${profile.endpoint}',
      style: TextStyle(color: textSecondary, height: 1.4),
    );
  }
}
