import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../../services/settings_service.dart';
import 'global_settings_screen.dart';
import 'shortcut_settings_screen.dart';
import 'llm_settings_screen.dart';
import 'llm_model_management_screen.dart';
import 'import_data_screen.dart';
import 'delete_data_screen.dart';

/// 设置页面 - 自适应浅色/深色主题
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardBg = isDark ? AppColors.bgCard : Colors.white;
    final dividerClr = isDark ? AppColors.border : AppColors.lightDivider;

    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '设置',
                  style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // 外观与偏好
              _buildSectionHeader('外观与偏好'),
              const SizedBox(height: 8),
              _buildSettingsGroup(context, isDark, cardBg, dividerClr, textPrimary, textMuted, [
                _SettingsItem(
                  icon: Icons.language,
                  iconBg: const Color(0xFF3B82F6),
                  title: '语言',
                  subtitle: '选择应用语言',
                  onTap: () => _showLanguageDialog(context, isDark, cardBg, textPrimary, textMuted),
                ),
                _SettingsItem(
                  icon: Icons.palette,
                  iconBg: const Color(0xFFF59E0B),
                  title: '主题设置',
                  subtitle: settings.appThemeMode == 'light' ? '白天模式' : '夜间模式',
                  onTap: () => _showThemeDialog(context, settings, isDark, cardBg, textPrimary, textMuted),
                ),
                _SettingsItem(
                  icon: Icons.trending_up,
                  iconBg: const Color(0xFFEF4444),
                  title: '涨跌颜色',
                  subtitle: settings.priceColorMode == 'redUpGreenDown' ? '红涨绿跌' : '绿涨红跌',
                  onTap: () => _showColorDialog(context, settings, isDark, cardBg, textPrimary, textMuted),
                ),
              ]),
              const SizedBox(height: 24),

              // 系统配置
              _buildSectionHeader('系统配置'),
              const SizedBox(height: 8),
              _buildSettingsGroup(context, isDark, cardBg, dividerClr, textPrimary, textMuted, [
                _SettingsItem(
                  icon: Icons.tune,
                  iconBg: const Color(0xFF8B5CF6),
                  title: '通用全局设置',
                  subtitle: '在线模式、K线数量、随机范围、手续费',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSettingsScreen()));
                  },
                ),
                _SettingsItem(
                  icon: Icons.keyboard,
                  iconBg: const Color(0xFF3B82F6),
                  title: '快捷键设置',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ShortcutSettingsScreen()));
                  },
                ),
                _SettingsItem(
                  icon: Icons.smart_toy_outlined,
                  iconBg: const Color(0xFF10B981),
                  title: '大模型配置',
                  subtitle: 'Provider / API Key / Endpoint / Model',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LlmSettingsScreen()));
                  },
                ),
                _SettingsItem(
                  icon: Icons.manage_accounts_outlined,
                  iconBg: const Color(0xFF0EA5E9),
                  title: '大模型管理',
                  subtitle: '管理多个模型与能力标签',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LlmModelManagementScreen()));
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // 数据管理
              _buildSectionHeader('数据管理'),
              const SizedBox(height: 8),
              _buildSettingsGroup(context, isDark, cardBg, dividerClr, textPrimary, textMuted, [
                _SettingsItem(icon: Icons.download, iconBg: const Color(0xFF3B82F6), title: '下载数据', subtitle: '获取更多历史行情'),
                _SettingsItem(icon: Icons.upload, iconBg: const Color(0xFF10B981), title: '导入数据', subtitle: '导入本地CSV', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportDataScreen()));
                }),
                _SettingsItem(icon: Icons.delete_outline, iconBg: const Color(0xFFEF4444), title: '删除数据', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteDataScreen()));
                }),
              ]),
              const SizedBox(height: 24),

              // 其它
              _buildSectionHeader('其它'),
              const SizedBox(height: 8),
              _buildSettingsGroup(context, isDark, cardBg, dividerClr, textPrimary, textMuted, [
                _SettingsItem(icon: Icons.info_outline, iconBg: const Color(0xFF6B7280), title: '关于', subtitle: 'v1.0.0'),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color dividerClr,
    Color textPrimary,
    Color textMuted,
    List<_SettingsItem> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: isLast ? const Radius.circular(16) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: item.iconBg.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, color: item.iconBg, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(item.subtitle!, style: TextStyle(color: textMuted, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: textMuted, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 66),
                  child: Divider(height: 1, color: dividerClr),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ===== 主题设置弹窗 =====
  void _showThemeDialog(BuildContext context, SettingsService settings, bool isDark, Color cardBg, Color textPrimary, Color textMuted) {
    String appTheme = settings.appThemeMode;
    String chartTheme = settings.chartThemeMode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主题设置', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  Text('应用界面', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildThemeOption('☀️', '白天模式', appTheme == 'light', textPrimary, textMuted,
                    () => setDialogState(() => appTheme = 'light')),
                  _buildThemeOption('🌙', '夜间模式', appTheme == 'dark', textPrimary, textMuted,
                    () => setDialogState(() => appTheme = 'dark')),
                  const SizedBox(height: 16),

                  Text('K线图表', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildThemeOption('📈', '白天模式', chartTheme == 'light', textPrimary, textMuted,
                    () => setDialogState(() => chartTheme = 'light')),
                  _buildThemeOption('📊', '夜间模式', chartTheme == 'dark', textPrimary, textMuted,
                    () => setDialogState(() => chartTheme = 'dark')),
                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        settings.appThemeMode = appTheme;
                        settings.chartThemeMode = chartTheme;
                        settings.save();
                        Navigator.pop(ctx);
                      },
                      child: const Text('确认', style: TextStyle(color: AppColors.primary, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(String emoji, String label, bool selected, Color textPrimary, Color textMuted, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: textPrimary, fontSize: 15))),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_off,
              color: selected ? AppColors.primary : textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ===== 涨跌颜色弹窗 =====
  void _showColorDialog(BuildContext context, SettingsService settings, bool isDark, Color cardBg, Color textPrimary, Color textMuted) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('涨跌颜色', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildColorOption(
                Icons.trending_up, Colors.green, '绿涨红跌', textPrimary,
                settings.priceColorMode == 'greenUpRedDown',
                isDark ? AppColors.bgSurface : AppColors.lightSurface,
                () { settings.priceColorMode = 'greenUpRedDown'; settings.save(); Navigator.pop(ctx); },
              ),
              const SizedBox(height: 8),
              _buildColorOption(
                Icons.trending_up, Colors.red, '红涨绿跌', textPrimary,
                settings.priceColorMode == 'redUpGreenDown',
                isDark ? AppColors.bgSurface : AppColors.lightSurface,
                () { settings.priceColorMode = 'redUpGreenDown'; settings.save(); Navigator.pop(ctx); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(IconData icon, Color color, String label, Color textPrimary, bool selected, Color selectedBg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ===== 语言弹窗 =====
  void _showLanguageDialog(BuildContext context, bool isDark, Color cardBg, Color textPrimary, Color textMuted) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('语言设置', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildLangOption('🇨🇳', '简体中文', true, textPrimary, () => Navigator.pop(ctx)),
              _buildLangOption('🇺🇸', 'English', false, textPrimary, () => Navigator.pop(ctx)),
              _buildLangOption('🇯🇵', '日本語', false, textPrimary, () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangOption(String emoji, String label, bool selected, Color textPrimary, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: textPrimary, fontSize: 15)),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  _SettingsItem({required this.icon, required this.iconBg, required this.title, this.subtitle, this.onTap});
}
