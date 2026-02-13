import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../../services/settings_service.dart';

/// 快捷键设置页面 (主题自适应)
class ShortcutSettingsScreen extends StatefulWidget {
  const ShortcutSettingsScreen({super.key});

  @override
  State<ShortcutSettingsScreen> createState() => _ShortcutSettingsScreenState();
}

class _ShortcutSettingsScreenState extends State<ShortcutSettingsScreen> {
  late String _buy, _sell, _close, _nextBar, _prevBar;
  String? _editingField;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _textMuted => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _borderClr => _isDark ? AppColors.borderLight : AppColors.lightBorder;
  Color get _surfaceClr => _isDark ? AppColors.bgSurface : AppColors.lightSurface;
  Color get _dividerClr => _isDark ? AppColors.border : AppColors.lightDivider;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _buy = s.shortcutBuy;
    _sell = s.shortcutSell;
    _close = s.shortcutClose;
    _nextBar = s.shortcutNextBar;
    _prevBar = s.shortcutPrevBar;
  }

  void _save() {
    final s = context.read<SettingsService>();
    s.shortcutBuy = _buy;
    s.shortcutSell = _sell;
    s.shortcutClose = _close;
    s.shortcutNextBar = _nextBar;
    s.shortcutPrevBar = _prevBar;
    s.save();
  }

  void _restoreDefaults() {
    setState(() { _buy = 'S'; _sell = 'B'; _close = 'P'; _nextBar = '→'; _prevBar = '←'; _editingField = null; });
    _save();
  }

  void _onKeyEvent(KeyEvent event) {
    if (_editingField == null || event is! KeyDownEvent) return;

    String label;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) { label = '→'; }
    else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { label = '←'; }
    else if (event.logicalKey == LogicalKeyboardKey.arrowUp) { label = '↑'; }
    else if (event.logicalKey == LogicalKeyboardKey.arrowDown) { label = '↓'; }
    else {
      final keyLabel = event.logicalKey.keyLabel;
      if (keyLabel.isEmpty || keyLabel.length > 1) return;
      label = keyLabel.toUpperCase();
    }

    setState(() {
      switch (_editingField) {
        case 'buy': _buy = label; break;
        case 'sell': _sell = label; break;
        case 'close': _close = label; break;
        case 'nextBar': _nextBar = label; break;
        case 'prevBar': _prevBar = label; break;
      }
      _editingField = null;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.keyboard, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('快捷键设置', style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                Center(child: Text('点击快捷键可重新设置，支持字母键和方向键', style: TextStyle(color: _textSecondary, fontSize: 14))),
                const SizedBox(height: 28),

                _buildShortcutRow(icon: Icons.arrow_upward, iconColor: const Color(0xFFFF6B35), label: '买入 (做多)', value: _buy, field: 'buy'),
                Divider(height: 1, color: _dividerClr),
                _buildShortcutRow(icon: Icons.arrow_downward, iconColor: AppColors.primary, label: '卖出 (做空)', value: _sell, field: 'sell'),
                Divider(height: 1, color: _dividerClr),
                _buildShortcutRow(icon: Icons.close, iconColor: AppColors.error, label: '平仓', value: _close, field: 'close'),
                Divider(height: 1, color: _dividerClr),
                _buildShortcutRow(icon: Icons.arrow_forward, iconColor: AppColors.primary, label: '下一根K线', value: _nextBar, field: 'nextBar'),
                Divider(height: 1, color: _dividerClr),
                _buildShortcutRow(icon: Icons.arrow_back, iconColor: AppColors.primary, label: '上一根K线', value: _prevBar, field: 'prevBar'),
                const SizedBox(height: 32),

                // 恢复默认
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _restoreDefaults,
                    icon: const Icon(Icons.restore, color: Color(0xFFFF6B35), size: 18),
                    label: const Text('恢复默认设置', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF6B35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 默认快捷键提示框
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderClr)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('💡 ', style: TextStyle(fontSize: 16)),
                        Text('默认快捷键设置：', style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 12),
                      _buildDefaultRow('S', '买入 (做多)'),
                      const SizedBox(height: 8),
                      _buildDefaultRow('B', '卖出 (做空)'),
                      const SizedBox(height: 8),
                      _buildDefaultRow('P', '平仓'),
                      const SizedBox(height: 8),
                      _buildDefaultRow('→', '下一根K线'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('关闭', style: TextStyle(color: _textSecondary, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutRow({required IconData icon, required Color iconColor, required String label, required String value, required String field}) {
    final isEditing = _editingField == field;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w500))),
        GestureDetector(
          onTap: () => setState(() => _editingField = isEditing ? null : field),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52, height: 42,
            decoration: BoxDecoration(
              color: isEditing ? AppColors.primary : _surfaceClr,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isEditing ? AppColors.primary : _borderClr, width: isEditing ? 2 : 1),
              boxShadow: isEditing ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 8)] : null,
            ),
            child: Center(
              child: isEditing
                  ? const Text('...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                  : Text(value, style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildDefaultRow(String key, String desc) {
    return Row(children: [
      Container(
        width: 32, height: 28,
        decoration: BoxDecoration(color: _surfaceClr, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderClr)),
        child: Center(child: Text(key, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 12),
      Text(desc, style: TextStyle(color: _textSecondary, fontSize: 13)),
    ]);
  }
}
