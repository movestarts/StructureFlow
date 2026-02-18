import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../../services/account_service.dart';
import '../../services/data_service.dart';
import '../../services/builtin_data_service.dart';
import '../../services/database_service.dart';
import '../../models/kline_model.dart';
import '../../models/period.dart';
import 'setup_screen.dart';
import 'position_calculator_screen.dart';
import 'operation_analysis_screen.dart';
import 'settings_screen.dart';
import 'trade_history_screen.dart';
import 'main_screen.dart';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // 主题自适应色彩辅助
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _textMuted => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _dividerClr => _isDark ? AppColors.border : AppColors.lightDivider;
  Color get _borderClr => _isDark ? AppColors.borderLight : AppColors.lightBorder;
  Color get _surfaceClr => _isDark ? AppColors.bgSurface : AppColors.lightSurface;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomePage(),
            _buildPlaceholder('行情'),

            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomePage() {
    return Consumer<AccountService>(
      builder: (context, account, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部统计卡片
              _buildStatsCard(account),
              const SizedBox(height: 24),
              // K线训练营标题
              _buildSectionTitle(),
              const SizedBox(height: 16),
              // 训练模式卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrainingModeCard(
                      title: '现货训练 (只做多)',
                      icon: Icons.trending_up,
                      iconColor: AppColors.success,
                      headerBg: _isDark ? const Color(0xFF0C2E1F) : AppColors.spotHeaderBg,
                      modes: [
                        _TrainingMode('复盘模式', Icons.replay_circle_filled, TrainingType.spotReplay),
                        _TrainingMode('随机训练', Icons.shuffle, TrainingType.spotRandom),
                        _TrainingMode('裸K训练', Icons.candlestick_chart, TrainingType.spotNakedK),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTrainingModeCard(
                      title: '合约训练 (多空杠杆)',
                      icon: Icons.swap_vert,
                      iconColor: AppColors.primary,
                      headerBg: _isDark ? const Color(0xFF0F1A2E) : AppColors.futuresHeaderBg,
                      modes: [
                        _TrainingMode('复盘模式', Icons.replay_circle_filled, TrainingType.futuresReplay),
                        _TrainingMode('随机训练', Icons.shuffle, TrainingType.futuresRandom),
                        _TrainingMode('裸K训练', Icons.candlestick_chart, TrainingType.futuresNakedK),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // 常用工具
                    _buildToolsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(AccountService account) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 上半部分：余额和盈亏
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '账户余额',
                        style: TextStyle(color: _textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            account.balance.toStringAsFixed(2),
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('金币', style: TextStyle(color: _textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 50, width: 1, color: _dividerClr),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('盈亏', style: TextStyle(color: _textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            account.totalPnL.toStringAsFixed(2),
                            style: TextStyle(
                              color: account.totalPnL >= 0 ? AppColors.bullish : AppColors.bearish,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('金币', style: TextStyle(color: _textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: _dividerClr, height: 1),
            ),
            // 下半部分：统计数据
            Row(
              children: [
                _buildStatItem('交易次数', '${account.tradeCount}', _textPrimary),
                _buildStatItem('收益率', '${account.roi.toStringAsFixed(2)}%',
                    account.roi >= 0 ? AppColors.bullish : AppColors.bearish),
                _buildStatItem('胜率', '${account.winRate.toStringAsFixed(2)}%',
                    account.winRate >= 50 ? AppColors.success : _textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Column(
      children: [
        Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ).createShader(bounds),
            child: const Text(
              'K线训练营',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '提升您的交易技能与市场洞察力',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '训练模式',
                    style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showResetDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDark ? AppColors.bgSurface : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('重置账户', style: TextStyle(color: _textMuted, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('重置账户', style: TextStyle(color: _textPrimary)),
        content: Text('确定要重置所有训练数据吗？此操作不可恢复。',
            style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () {
              context.read<AccountService>().reset();
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingModeCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color headerBg,
    required List<_TrainingMode> modes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.15 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
      ),
      child: Column(
        children: [
          // 标题区 — 带浅色背景
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // 按钮区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: modes.map((m) => _buildModeButton(m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(_TrainingMode mode) {
    return InkWell(
      onTap: () => _onModeSelected(mode.type),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _surfaceClr,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(mode.icon, color: _textPrimary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(mode.label, style: TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ===== 常用工具 =====
  Widget _buildToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '常用工具',
          style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildToolCard(Icons.folder_open, '从存档开始', const Color(0xFFFF6B35)),
            _buildToolCard(Icons.data_object, '示例数据', const Color(0xFF10B981), onTap: _showBuiltinDataDialog),
            _buildToolCard(Icons.history, '历史记录', const Color(0xFF6B7280), onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TradeHistoryScreen()),
              );
            }),
            _buildToolCard(Icons.school, '新手教程', AppColors.success),
            _buildToolCard(Icons.calculate, '仓位计算', AppColors.primary, onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PositionCalculatorScreen()),
              );
            }),
            _buildToolCard(Icons.psychology_alt, '操作分析', const Color(0xFF0EA5E9), onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OperationAnalysisScreen()),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard(IconData icon, String label, Color iconColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 56) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _onModeSelected(TrainingType type) {
    // 随机训练模式：随机选择品种和时间
    if (type == TrainingType.futuresRandom) {
      _startRandomFuturesReplay();
    } else {
      // 其他模式（包括复盘模式）：进入配置页面
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SetupScreen(trainingType: type)),
      );
    }
  }

  /// 随机合约训练：随机品种+随机时间
  Future<void> _startRandomFuturesReplay() async {
    try {
      // 1. 加载所有期货合约文件
      final appDocDir = await getApplicationDocumentsDirectory();
      List<File> futuresFiles = [];

      final baseDir = Directory('${appDocDir.path}${Platform.pathSeparator}cryptotrainer${Platform.pathSeparator}csv');
      if (await baseDir.exists()) {
        final futuresDir = Directory('${baseDir.path}${Platform.pathSeparator}futures');
        if (await futuresDir.exists()) {
          futuresFiles = futuresDir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.csv')).toList();
        }
      }

      if (futuresFiles.isEmpty) {
        _showError('没有找到期货合约数据\n请先导入CSV文件');
        return;
      }

      // 2. 随机选择一个合约
      final random = Random();
      final selectedFile = futuresFiles[random.nextInt(futuresFiles.length)];
      final filename = selectedFile.path.split(Platform.pathSeparator).last;
      final instrumentCode = filename.replaceAll('.csv', '').replaceAll(RegExp(r'[_\-\d]'), '').toUpperCase();

      // 显示加载提示
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text('正在加载 $instrumentCode...', style: TextStyle(color: _textPrimary)),
              ],
            ),
          ),
        ),
      );

      // 3. 加载数据
      final service = DataService();
      final symbol = filename.replaceAll('.csv', '');
      final allData = await service.loadWithCache(selectedFile.path, symbol);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载提示

      if (allData.isEmpty) {
        _showError('数据加载失败或为空');
        return;
      }

      // 4. 随机选择起始时间（在前70%的数据范围内）
      final maxStartIndex = (allData.length * 0.7).floor();
      final minStartIndex = (allData.length * 0.1).floor(); // 跳过前10%，避免数据初期不稳定
      final randomStartIndex = minStartIndex + random.nextInt(maxStartIndex - minStartIndex);

      // 5. 显示简单配置对话框
      _showQuickConfigDialog(
        allData: allData,
        startIndex: randomStartIndex,
        instrumentCode: instrumentCode,
        csvPath: selectedFile.path,
      );
    } catch (e) {
      _showError('启动失败: $e');
    }
  }

  /// 显示快速配置对话框（类似图二）
  void _showQuickConfigDialog({
    required List<KlineModel> allData,
    required int startIndex,
    required String instrumentCode,
    required String csvPath,
  }) {
    int displayMode = 0; // 0=竖屏, 1=横屏
    bool enableStopLoss = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题
                    Text(
                      '止盈止损设置',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 显示模式
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '显示模式',
                        style: TextStyle(color: _textSecondary, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickModeOption(
                            label: '竖屏',
                            value: 0,
                            groupValue: displayMode,
                            onChanged: (v) => setDialogState(() => displayMode = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickModeOption(
                            label: '横屏',
                            value: 1,
                            groupValue: displayMode,
                            onChanged: (v) => setDialogState(() => displayMode = v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 启用止盈止损
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _surfaceClr,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '启用止盈止损',
                              style: TextStyle(color: _textPrimary, fontSize: 15),
                            ),
                          ),
                          Checkbox(
                            value: enableStopLoss,
                            onChanged: (v) => setDialogState(() => enableStopLoss = v ?? false),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: _borderClr),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('取消', style: TextStyle(color: _textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx); // 关闭对话框
                              // 启动训练
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Theme(
                                    data: AppTheme.darkTheme,
                                    child: MainScreen(
                                      allData: allData,
                                      startIndex: startIndex,
                                      limit: 200, // 默认200根K线
                                      instrumentCode: instrumentCode,
                                      initialPeriod: Period.m5,
                                      spotOnly: false,
                                      csvPath: csvPath,
                                    ),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '确认',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 快速配置对话框的单选选项
  Widget _buildQuickModeOption({
    required String label,
    required int value,
    required int groupValue,
    required ValueChanged<int> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : _surfaceClr,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : _borderClr,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : _textMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : _textPrimary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示错误提示
  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('提示', style: TextStyle(color: _textPrimary)),
        content: Text(message, style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: _cardBg,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: _textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: '行情'),

          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String label) {
    return Center(
      child: Text('$label - 开发中', style: TextStyle(color: _textSecondary, fontSize: 18)),
    );
  }

  // 显示内置示例数据对话框
  void _showBuiltinDataDialog() {
    final builtinService = BuiltinDataService();
    final symbols = builtinService.getBuiltinSymbols();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('内置示例数据'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '应用内置了真实的期货数据供您练习使用：',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...symbols.map((symbol) => _buildSymbolCard(symbol)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolCard(BuiltinSymbol symbol) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _loadBuiltinData(symbol),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          symbol.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          symbol.symbol,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: _textMuted),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                symbol.description,
                style: TextStyle(fontSize: 12, color: _textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadBuiltinData(BuiltinSymbol symbol) async {
    Navigator.pop(context); // 关闭对话框

    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在加载数据...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final db = DatabaseService();
      final data = await db.getKlines(symbol.symbol, symbol.period);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载提示

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据为空，请检查是否已导入')),
        );
        return;
      }

      // 跳转到复盘页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            allData: data,
            instrumentCode: symbol.symbol,
            startIndex: 100, // 从100根K线开始
            initialPeriod: Period.m5,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }
}

enum TrainingType {
  spotReplay,
  spotRandom,
  spotNakedK,
  futuresReplay,
  futuresRandom,
  futuresNakedK,
}

class _TrainingMode {
  final String label;
  final IconData icon;
  final TrainingType type;

  _TrainingMode(this.label, this.icon, this.type);
}
