import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../services/account_service.dart';
import '../../models/trade_record.dart';
import 'trade_history_chart_screen.dart';

/// 交易历史记录页面
class TradeHistoryScreen extends StatefulWidget {
  const TradeHistoryScreen({super.key});

  @override
  State<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

class _TradeHistoryScreenState extends State<TradeHistoryScreen> {
  int _tabIndex = 0; // 0=每个仓位, 1=每日

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _textMuted => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _dividerClr => _isDark ? AppColors.border : AppColors.lightDivider;
  Color get _borderClr => _isDark ? AppColors.borderLight : AppColors.lightBorder;
  Color get _surfaceClr => _isDark ? AppColors.bgSurface : AppColors.lightSurface;

  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountService>(
      builder: (context, account, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: _cardBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: _textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('交易历史记录', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.delete_outline, color: _textMuted),
                onPressed: () => _showClearConfirm(account),
              ),
            ],
          ),
          body: Column(
            children: [
              // 顶部统计卡片
              _buildStatsCard(account),
              const SizedBox(height: 12),

              // Tab 切换
              _buildTabBar(),
              const SizedBox(height: 12),

              // 列表
              Expanded(
                child: _tabIndex == 0
                    ? _buildPositionList(account)
                    : _buildDailyList(account),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(AccountService account) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.15 : 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
      ),
      child: Column(
        children: [
          // 第一行: 总交易数、胜率、总盈亏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildStatCell('总交易数', '${account.tradeHistory.length}', _textPrimary),
                _buildStatCell('胜率', '${account.winRate.toStringAsFixed(1)}%',
                    account.winRate >= 50 ? AppColors.success : AppColors.error),
                _buildStatCell('总盈利', account.totalPnL.toStringAsFixed(2),
                    account.totalPnL >= 0 ? AppColors.success : AppColors.error),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Divider(height: 1, color: _dividerClr),
          ),
          // 第二行: 做多、做空、总手续费
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildStatCell('做多', '${account.longCount}', _textPrimary),
                _buildStatCell('做空', '${account.shortCount}', _textPrimary),
                _buildStatCell('总手续费', account.totalFees.toStringAsFixed(2), _textPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: _textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTab('每个仓位', 0),
          const SizedBox(width: 8),
          _buildTab('每 日', 1),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : _borderClr),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPositionList(AccountService account) {
    final trades = account.tradeHistory;
    if (trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, color: _textMuted, size: 48),
            const SizedBox(height: 12),
            Text('暂无交易记录', style: TextStyle(color: _textMuted, fontSize: 16)),
            const SizedBox(height: 4),
            Text('完成训练后交易会记录在此', style: TextStyle(color: _textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: trades.length,
      itemBuilder: (_, i) => _buildTradeCard(trades[i]),
    );
  }

  Widget _buildTradeCard(TradeRecord trade) {
    final pnlColor = trade.pnl >= 0 ? AppColors.bullish : AppColors.bearish;
    final pnlSign = trade.pnl >= 0 ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.12 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部: 品种 + 标签 + 盈亏
          Row(
            children: [
              // 头像
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.success, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(trade.instrumentCode[0], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trade.instrumentCode, style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildTag(trade.isLong ? '做多' : '做空', trade.isLong ? AppColors.bullish : AppColors.bearish),
                      const SizedBox(width: 6),
                      _buildTag(trade.type == 'spot' ? '现货' : '合约', AppColors.primary),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pnlSign${trade.pnl.toStringAsFixed(2)}',
                    style: TextStyle(color: pnlColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${trade.pnlPercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: pnlColor, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: _dividerClr),
          const SizedBox(height: 14),

          // 详情表格
          Row(
            children: [
              Expanded(child: _buildDetailItem('仓位', trade.quantity.toStringAsFixed(4))),
              Expanded(child: _buildDetailItem('手续费', trade.fee.toStringAsFixed(2), alignment: CrossAxisAlignment.end)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDetailItem('买入均价', trade.entryPrice.toStringAsFixed(2))),
              Expanded(child: _buildDetailItem('卖出均价', trade.closePrice.toStringAsFixed(2), alignment: CrossAxisAlignment.end)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDetailItem('开仓时间', _dateFmt.format(trade.entryTime))),
              Expanded(child: _buildDetailItem('平仓时间', _dateFmt.format(trade.closeTime), alignment: CrossAxisAlignment.end)),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailItem('训练时间', _dateFmt.format(trade.trainingTime)),
          const SizedBox(height: 14),

          // 查看K线按钮
          InkWell(
            onTap: () => _viewChart(trade),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('查看K线', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDetailItem(String label, String value, {CrossAxisAlignment alignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text('$label: $value', style: TextStyle(color: _textSecondary, fontSize: 12)),
      ],
    );
  }

  // 每日汇总
  Widget _buildDailyList(AccountService account) {
    final trades = account.tradeHistory;
    if (trades.isEmpty) {
      return Center(child: Text('暂无交易记录', style: TextStyle(color: _textMuted, fontSize: 16)));
    }

    // 按训练日期分组
    final Map<String, List<TradeRecord>> grouped = {};
    final dayFmt = DateFormat('yyyy-MM-dd');
    for (final t in trades) {
      final key = dayFmt.format(t.trainingTime);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(t);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (_, i) {
        final date = sortedKeys[i];
        final dayTrades = grouped[date]!;
        final dayPnL = dayTrades.fold(0.0, (sum, t) => sum + t.pnl);
        final dayWins = dayTrades.where((t) => t.isWin).length;
        final dayPnlColor = dayPnL >= 0 ? AppColors.bullish : AppColors.bearish;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.12 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
            border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('${i + 1}', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date, style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${dayTrades.length}笔交易 · 胜${dayWins}负${dayTrades.length - dayWins}', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${dayPnL >= 0 ? "+" : ""}${dayPnL.toStringAsFixed(2)}',
                    style: TextStyle(color: dayPnlColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewChart(TradeRecord trade) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeHistoryChartScreen(trade: trade),
      ),
    );
  }

  void _showClearConfirm(AccountService account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('清空历史', style: TextStyle(color: _textPrimary)),
        content: Text('确定要清空所有交易历史记录吗？此操作不可恢复。', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: _textMuted))),
          TextButton(
            onPressed: () {
              account.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
