import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../../services/settings_service.dart';

/// 通用全局设置 - 全屏页面 (主题自适应)
class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> {
  late bool _isOnlineMode;
  late Set<String> _allowedMarkets;
  late Set<String> _allowedPeriods;

  late TextEditingController _klineCountCtrl;
  late TextEditingController _reservedCtrl;
  late TextEditingController _spotMakerCtrl;
  late TextEditingController _spotTakerCtrl;
  late TextEditingController _futuresMakerCtrl;
  late TextEditingController _futuresTakerCtrl;
  late TextEditingController _dataDirCtrl;

  String _defaultCacheDir = '';

  // 主题自适应色彩辅助
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _textMuted => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _dividerClr => _isDark ? AppColors.border : AppColors.lightDivider;
  Color get _borderClr => _isDark ? AppColors.borderLight : AppColors.lightBorder;
  Color get _inputFill => _isDark ? AppColors.bgSurface : Colors.white;
  Color get _infoBg => _isDark ? const Color(0xFF0F1A2E) : AppColors.futuresHeaderBg;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _isOnlineMode = s.isOnlineMode;
    _allowedMarkets = Set.from(s.allowedMarkets);
    _allowedPeriods = Set.from(s.allowedPeriods);

    _klineCountCtrl = TextEditingController(text: '${s.initialKlineCount}');
    _reservedCtrl = TextEditingController(text: '${s.minReservedKlines}');
    _spotMakerCtrl = TextEditingController(text: s.spotMakerFee.toStringAsFixed(3));
    _spotTakerCtrl = TextEditingController(text: s.spotTakerFee.toStringAsFixed(3));
    _futuresMakerCtrl = TextEditingController(text: s.futuresMakerFee.toStringAsFixed(3));
    _futuresTakerCtrl = TextEditingController(text: s.futuresTakerFee.toStringAsFixed(3));
    _dataDirCtrl = TextEditingController(text: s.dataCacheDir);

    _loadDefaultDir();
  }

  Future<void> _loadDefaultDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      setState(() => _defaultCacheDir = '${dir.path}\\cryptotrainer\\csv');
    } catch (_) {}
  }

  @override
  void dispose() {
    _klineCountCtrl.dispose();
    _reservedCtrl.dispose();
    _spotMakerCtrl.dispose();
    _spotTakerCtrl.dispose();
    _futuresMakerCtrl.dispose();
    _futuresTakerCtrl.dispose();
    _dataDirCtrl.dispose();
    super.dispose();
  }

  void _restoreDefaults() {
    setState(() {
      _isOnlineMode = false;
      _allowedMarkets = {'crypto', 'futures'};
      _allowedPeriods = {'1M', '5M', '10M', '15M', '30M', '1H', '2H', '4H', '12H', '1D'};
      _klineCountCtrl.text = '350';
      _reservedCtrl.text = '300';
      _spotMakerCtrl.text = '0.050';
      _spotTakerCtrl.text = '0.100';
      _futuresMakerCtrl.text = '0.025';
      _futuresTakerCtrl.text = '0.050';
      _dataDirCtrl.text = '';
    });
  }

  void _save() {
    final s = context.read<SettingsService>();
    s.isOnlineMode = _isOnlineMode;
    s.initialKlineCount = int.tryParse(_klineCountCtrl.text) ?? 350;
    s.minReservedKlines = int.tryParse(_reservedCtrl.text) ?? 300;
    s.allowedMarkets = Set.from(_allowedMarkets);
    s.allowedPeriods = Set.from(_allowedPeriods);
    s.spotMakerFee = double.tryParse(_spotMakerCtrl.text) ?? 0.050;
    s.spotTakerFee = double.tryParse(_spotTakerCtrl.text) ?? 0.100;
    s.futuresMakerFee = double.tryParse(_futuresMakerCtrl.text) ?? 0.025;
    s.futuresTakerFee = double.tryParse(_futuresTakerCtrl.text) ?? 0.050;
    s.dataCacheDir = _dataDirCtrl.text;
    s.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: Text('通用全局设置', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _cardBg,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.close, color: _textPrimary), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOnlineMode(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('图表参数'),
                  const SizedBox(height: 12),
                  _buildLabeledInput('图表初始加载 K线数量', Icons.bar_chart, _klineCountCtrl,
                      helperText: '训练时图表默认展示的数据长度 (建议 200-500)'),
                  const SizedBox(height: 24),
                  _buildSectionTitle('随机/裸K模式设置'),
                  const SizedBox(height: 12),
                  _buildLabeledInput('随机/裸K 预留最少K线', Icons.show_chart, _reservedCtrl,
                      helperText: '防止随机到的开始K线过于靠后，导致没有足够的后续行情'),
                  const SizedBox(height: 20),
                  _buildLabel('随机模式允许加载的市场类型:'),
                  const SizedBox(height: 8),
                  _buildMarketChips(),
                  const SizedBox(height: 20),
                  _buildLabel('随机模式允许加载的 K线周期:'),
                  const SizedBox(height: 8),
                  _buildPeriodChips(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('交易手续费 (%)'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildFeeInput('现货 限价(Maker)', _spotMakerCtrl)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFeeInput('现货 市价(Taker)', _spotTakerCtrl)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildFeeInput('合约 限价(Maker)', _futuresMakerCtrl)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFeeInput('合约 市价(Taker)', _futuresTakerCtrl)),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle('数据存储'),
                  const SizedBox(height: 12),
                  _buildDataDirField(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildOnlineMode() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.15 : 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
      ),
      child: Column(
        children: [
          _buildModeRow('在线模式 (Online)', Icons.cloud_done, AppColors.primary, _isOnlineMode,
            (_) => setState(() => _isOnlineMode = true)),
          Divider(height: 1, color: _dividerClr, indent: 16, endIndent: 16),
          _buildModeRow('离线模式 (Offline)', Icons.cloud_off, _textMuted, !_isOnlineMode,
            (_) => setState(() => _isOnlineMode = false)),
          if (!_isOnlineMode)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _infoBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('离线模式：需要先下载或导入数据 (稳定，无网可用) (依赖下载或者导入的数据)',
                      style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeRow(String title, IconData trailing, Color trailingColor, bool selected, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : _textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w500))),
            Icon(trailing, color: trailingColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildLabel(String text) {
    return Text(text, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500));
  }

  Widget _buildLabeledInput(String label, IconData icon, TextEditingController ctrl, {String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: _textPrimary, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: _inputFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderClr)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderClr)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        if (helperText != null)
          Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(helperText, style: TextStyle(color: _textMuted, fontSize: 12))),
      ],
    );
  }

  Widget _buildMarketChips() {
    return Row(children: [
      _buildToggleChip('加密货币', 'crypto', _allowedMarkets),
      const SizedBox(width: 10),
      _buildToggleChip('国内期货', 'futures', _allowedMarkets),
    ]);
  }

  Widget _buildPeriodChips() {
    final periods = ['1M', '5M', '10M', '15M', '30M', '1H', '2H', '4H', '12H', '1D'];
    return Wrap(spacing: 8, runSpacing: 8, children: periods.map((p) => _buildToggleChip(p, p, _allowedPeriods)).toList());
  }

  Widget _buildToggleChip(String label, String value, Set<String> set) {
    final selected = set.contains(value);
    return GestureDetector(
      onTap: () => setState(() { selected ? set.remove(value) : set.add(value); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : _borderClr),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[const Icon(Icons.check, color: Colors.white, size: 16), const SizedBox(width: 4)],
            Text(label, style: TextStyle(color: selected ? Colors.white : _textSecondary, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeInput(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: _textPrimary, fontSize: 15),
          decoration: InputDecoration(
            suffixText: '%',
            suffixStyle: TextStyle(color: _textMuted, fontSize: 14),
            filled: true,
            fillColor: _inputFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderClr)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderClr)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDataDirField() {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderClr)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(children: [
              Icon(Icons.table_chart, color: _textMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _dataDirCtrl,
                  style: TextStyle(color: _textPrimary, fontSize: 14),
                  decoration: InputDecoration(hintText: '数据缓存目录 (CSV)', hintStyle: TextStyle(color: _textMuted), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                ),
              ),
              IconButton(icon: Icon(Icons.folder_open, color: _textMuted), onPressed: _pickDirectory),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: Text('留空则使用默认文档目录', style: TextStyle(color: _textMuted, fontSize: 12))),
          if (_defaultCacheDir.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text('当前使用默认路径: $_defaultCacheDir', style: TextStyle(color: AppColors.primary, fontSize: 11))),
        ],
      ),
    );
  }

  Future<void> _pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择数据缓存目录');
    if (result != null) setState(() => _dataDirCtrl.text = result);
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        TextButton.icon(
          onPressed: _restoreDefaults,
          icon: Icon(Icons.restore, color: AppColors.error, size: 18),
          label: Text('恢复默认', style: TextStyle(color: AppColors.error, fontSize: 14)),
        ),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: _textSecondary, fontSize: 15))),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.grid_view_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('保存配置', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }
}
