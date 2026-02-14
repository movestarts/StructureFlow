import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../models/trade_record.dart';
import 'trade_history_chart_screen.dart';

class SessionDetailScreen extends StatelessWidget {
  final List<TradeRecord> trades;
  final String dateKey;

  const SessionDetailScreen({
    super.key,
    required this.trades,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) return const SizedBox();

    final firstTrade = trades.first;
    final symbol = firstTrade.instrumentCode;
    final isFutures = firstTrade.type == 'futures';
    
    // Calculate stats
    double totalPnL = 0;
    int wins = 0;
    DateTime startTime = trades.first.entryTime;
    DateTime endTime = trades.first.closeTime;

    for (var t in trades) {
      totalPnL += t.pnl;
      if (t.isWin) wins++;
      if (t.entryTime.isBefore(startTime)) startTime = t.entryTime;
      if (t.closeTime.isAfter(endTime)) endTime = t.closeTime;
    }

    final duration = endTime.difference(startTime);
    final durationStr = _formatDuration(duration);
    final winRate = (wins / trades.length * 100);
    final pnlColor = totalPnL >= 0 ? AppColors.bullish : AppColors.bearish;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Sort trades by entry time
    final sortedTrades = List<TradeRecord>.from(trades)..sort((a, b) => a.entryTime.compareTo(b.entryTime));

    return Scaffold(
      backgroundColor: AppColors.lightBg, // Using light theme as base base on screenshot
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${symbol} ${isFutures ? "合约" : "现货"}', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card (Summary)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.show_chart, color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(symbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(isFutures ? "合约" : "现货", style: const TextStyle(color: Colors.purple, fontSize: 10)),
                                  ),
                                ],
                              ),
                              Text('训练时间: ${dateFormat.format(firstTrade.trainingTime)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${totalPnL >= 0 ? "+" : ""}${totalPnL.toStringAsFixed(2)}', style: TextStyle(color: pnlColor, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('${(totalPnL / 1000000 * 100).toStringAsFixed(2)}%', style: TextStyle(color: pnlColor, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem('开始', dateFormat.format(startTime)),
                          _buildInfoItem('结束', dateFormat.format(endTime)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem('时间跨度', durationStr),
                          _buildInfoItem('战绩统计', '$wins胜 / ${trades.length - wins}负', valueColor: Colors.black),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                         child: Text('总成交/胜率: ${trades.length}笔 / ${winRate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                Text('交易明细 (${trades.length}笔)', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 10),

                // Trade List
                ...sortedTrades.map((trade) {
                  final tPnlColor = trade.pnl >= 0 ? AppColors.bullish : AppColors.bearish;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(trade.direction == 'long' ? Icons.arrow_upward : Icons.arrow_downward, 
                             color: trade.direction == 'long' ? AppColors.bullish : AppColors.bearish, size: 20),
                        const SizedBox(width: 12),
                        Text('${trade.entryPrice.toStringAsFixed(1)} → ${trade.closePrice.toStringAsFixed(1)}', 
                             style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        const Spacer(),
                        Text('${trade.pnl >= 0 ? "+" : ""}${trade.pnl.toStringAsFixed(2)}', 
                             style: TextStyle(color: tPnlColor, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),

          // Floating Action Button for "Review Full Walkthrough"
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TradeHistoryChartScreen(sessionTrades: trades),
                  ),
                );
              },
              backgroundColor: const Color(0xFFE0F2F1), // Light teal bg
              icon: const Icon(Icons.history, color: Color(0xFF00695C)),
              label: const Text('回顾整局走势', style: TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor ?? Colors.grey[800], fontSize: 13)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}小时${d.inMinutes.remainder(60)}分钟';
    }
    return '${d.inMinutes}分钟';
  }
}
