import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../../services/account_service.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _currentIndex == 0 ? _buildHomePage() : _buildPlaceholder(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomePage() {
    return Consumer<AccountService>(
      builder: (context, account, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildStatsCard(account),
              const SizedBox(height: 32),
              _buildSectionTitle(),
              const SizedBox(height: 20),
              _buildTrainingModeCard(
                title: '现货训练 (只做多)',
                icon: Icons.trending_up,
                iconColor: AppColors.success,
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
                modes: [
                  _TrainingMode('复盘模式', Icons.replay_circle_filled, TrainingType.futuresReplay),
                  _TrainingMode('随机训练', Icons.shuffle, TrainingType.futuresRandom),
                  _TrainingMode('裸K训练', Icons.candlestick_chart, TrainingType.futuresNakedK),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(AccountService account) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2332),
            Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
                      const Text(
                        '账户余额',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        account.balance.toStringAsFixed(2),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '金币',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 60,
                  width: 1,
                  color: AppColors.border,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '盈亏',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        account.totalPnL.toStringAsFixed(2),
                        style: TextStyle(
                          color: account.totalPnL >= 0 ? AppColors.bullish : AppColors.bearish,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '金币',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: AppColors.border, height: 1),
            ),
            // 下半部分：统计数据
            Row(
              children: [
                _buildStatItem('交易次数', '${account.tradeCount}', AppColors.textPrimary),
                _buildStatItem('收益率', '${account.roi.toStringAsFixed(2)}%',
                    account.roi >= 0 ? AppColors.bullish : AppColors.bearish),
                _buildStatItem('胜率', '${account.winRate.toStringAsFixed(2)}%',
                    account.winRate >= 50 ? AppColors.bullish : AppColors.textSecondary),
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
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            '提升您的交易技能与市场洞察力',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '训练模式',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // 重置按钮
            GestureDetector(
              onTap: () => _showResetDialog(),
              child: const Text(
                '重置账户',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('重置账户', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('确定要重置所有训练数据吗？此操作不可恢复。',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
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
    required List<_TrainingMode> modes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: modes.map((m) => _buildModeButton(m)).toList(),
            ),
          ],
        ),
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
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight, width: 1),
            ),
            child: Icon(
              mode.icon,
              color: AppColors.textSecondary,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mode.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _onModeSelected(TrainingType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetupScreen(trainingType: type),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: '行情',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: '交易所',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    const labels = ['', '行情', '交易所', '设置'];
    return Center(
      child: Text(
        '${labels[_currentIndex]} - 开发中',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 18),
      ),
    );
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
