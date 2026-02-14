import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../../models/kline_model.dart';
import '../../services/account_service.dart';
import '../../models/trade_record.dart';
import 'trade_history_chart_screen.dart';
import 'session_detail_screen.dart';

/// 交易历史记录页面
class TradeHistoryScreen extends StatefulWidget {
  const TradeHistoryScreen({super.key});

  @override
  State<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

class _TradeHistoryScreenState extends State<TradeHistoryScreen> {
  int _tabIndex = 0; // 0=每个仓位, 1=每日
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _textMuted => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _dividerClr => _isDark ? AppColors.border : AppColors.lightDivider;
  Color get _borderClr => _isDark ? AppColors.borderLight : AppColors.lightBorder;
  Color get _surfaceClr => _isDark ? AppColors.bgSurface : AppColors.lightSurface;

  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
      if (_isSelectionMode) _tabIndex = 0; // Force to item view
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<TradeRecord> trades) {
    setState(() {
      if (_selectedIds.length == trades.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(trades.map((t) => t.id));
      }
    });
  }

  Future<void> _exportData(List<TradeRecord> data) async {
    if (data.isEmpty) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final List<List<dynamic>> rows = [];
      
      // Header matching AI analysis needs
      final header = [
        // Trade Metadata
        'Trade_ID', 'Symbol', 'Direction', 'Entry_Time', 'Close_Time',
        'Entry_Price', 'Exit_Price', 'PnL', 'PnL_Percent', 'Quantity', 
        'Setup_Pattern', 'Trend_Context', 'Mistake_Tag', 'Strategy_Notes',
        // Candle Data
        'Bar_Time', 'Open', 'High', 'Low', 'Close', 'Volume', 'Bar_Type' 
      ];
      rows.add(header);

      final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

      for (var trade in data) {
        // Trade metadata common for all rows of this trade
        final meta = [
          trade.id,
          trade.instrumentCode,
          trade.direction,
          dateFmt.format(trade.entryTime),
          dateFmt.format(trade.closeTime),
          trade.entryPrice,
          trade.closePrice,
          trade.pnl,
          trade.pnlPercent,
          trade.quantity,
          '', '', '', '' // Empty AI fields
        ];

        // 1. Try to load K-line data
        List<KlineModel> klines = [];
        if (trade.csvPath != null && trade.csvPath!.isNotEmpty) {
          final file = File(trade.csvPath!);
          if (await file.exists()) {
             try {
               final bytes = await file.readAsBytes();
               String content;
               try {
                 content = utf8.decode(bytes);
               } catch (_) {
                 content = latin1.decode(bytes);
               }
               
               final csvRows = const CsvToListConverter(eol: '\n').convert(content);
               for (int i = 0; i < csvRows.length; i++) {
                 var row = csvRows[i];
                 if (row.isEmpty) continue;
                 // Skip header if present (check if first col is double)
                 if (i == 0) {
                   try { double.parse(row[1].toString()); } catch (_) { continue; }
                 }
                 try {
                   klines.add(KlineModel.fromList(row));
                 } catch (_) {}
               }
             } catch (e) {
               debugPrint('Error reading kline for trade ${trade.id}: $e');
             }
          }
        }

        if (klines.isNotEmpty) {
           // 2. Find range [Entry - 100, Close]
           int entryIdx = klines.indexWhere((k) => k.time.isAtSameMomentAs(trade.entryTime) || k.time.isAfter(trade.entryTime));
           if (entryIdx == -1) entryIdx = klines.length - 1;

           int startIdx = (entryIdx - 100).clamp(0, klines.length - 1);
           
           int closeIdx = klines.indexWhere((k) => k.time.isAtSameMomentAs(trade.closeTime) || k.time.isAfter(trade.closeTime));
           if (closeIdx == -1) closeIdx = klines.length - 1;
           
           // Ensure closeIdx covers the trade duration
           if (closeIdx < startIdx) closeIdx = klines.length - 1;

           // 3. Generate rows
           for (int i = startIdx; i <= closeIdx; i++) {
             final k = klines[i];
             String barType = 'Context';
             if (i >= entryIdx && i <= closeIdx) barType = 'Active';
             
             final row = List.from(meta)
               ..addAll([
                 dateFmt.format(k.time),
                 k.open,
                 k.high,
                 k.low,
                 k.close,
                 k.volume,
                 barType
               ]);
             rows.add(row);
           }
        } else {
          // Fallback: If no Kline data, just add one row with empty candle data
           final row = List.from(meta)..addAll(['', '', '', '', '', '', 'No_Data']);
           rows.add(row);
        }
      }
      
      final csvData = const ListToCsvConverter().convert(rows);
      // Add BOM for Excel compatibility
      final csvContent = '\uFEFF$csvData';
      
      // Hide loading
      if (mounted) Navigator.pop(context);

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: '保存 CSV 文件 (含K线数据)',
          fileName: 'trade_history_full_${DateFormat('MMdd_HHmm').format(DateTime.now())}.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          if (!outputFile.toLowerCase().endsWith('.csv')) {
             outputFile = '$outputFile.csv';
          }
          final file = File(outputFile);
          await file.writeAsString(csvContent);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存到: $outputFile')));
          }
        }
      } else {
        // Mobile: Use Share Sheet
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/trade_history.csv';
        final file = File(path);
        await file.writeAsString(csvContent);
        
        await Share.shareXFiles([XFile(path)], text: 'Exported Trade History with K-line Data');
      }
      
      if (_isSelectionMode) _toggleSelectionMode();

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountService>(
      builder: (context, account, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: _cardBg,
            elevation: 0,
            leading: _isSelectionMode
                ? IconButton(
                    icon: Icon(Icons.close, color: _textPrimary),
                    onPressed: _toggleSelectionMode,
                  )
                : IconButton(
                    icon: Icon(Icons.arrow_back, color: _textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
            title: Text(
              _isSelectionMode ? '已选择 ${_selectedIds.length} 项' : '交易历史记录',
              style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            actions: [
              if (_isSelectionMode)
                TextButton(
                  onPressed: () => _selectAll(account.tradeHistory),
                  child: Text(
                    _selectedIds.length == account.tradeHistory.length ? '取消全选' : '全选',
                    style: const TextStyle(color: AppColors.primary, fontSize: 16),
                  ),
                )
              else ...[
                PopupMenuButton<String>(
                  icon: Icon(Icons.ios_share, color: _textPrimary), 
                  onSelected: (val) {
                    if (val == 'select') _toggleSelectionMode();
                    if (val == 'export_all') _exportData(account.tradeHistory);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'select', child: Text('进入选择模式', style: TextStyle(color: _textPrimary))),
                    PopupMenuItem(value: 'export_all', child: Text('导出全部数据', style: TextStyle(color: _textPrimary))),
                  ],
                  color: _cardBg,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: _textMuted),
                  onPressed: () => _showClearConfirm(account),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (!_isSelectionMode) ...[
                _buildStatsCard(account),
                const SizedBox(height: 12),
                _buildTabBar(),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _tabIndex == 0
                    ? _buildPositionList(account)
                    : _buildDailyList(account),
              ),
            ],
          ),
          bottomNavigationBar: _isSelectionMode
              ? BottomAppBar(
                  color: _cardBg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton(
                      onPressed: _selectedIds.isEmpty ? null : () {
                         final selected = account.tradeHistory.where((t) => _selectedIds.contains(t.id)).toList();
                         _exportData(selected);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: _textMuted.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('导出选中 (${_selectedIds.length})', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                )
              : null,
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
          _buildTab('每一局', 1),
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
    // ... existing implementation but update _viewChart call
    final pnlColor = trade.pnl >= 0 ? AppColors.bullish : AppColors.bearish;
    final pnlSign = trade.pnl >= 0 ? '+' : '';

    final content = Container(
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
          Row(
            children: [
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

          InkWell(
            onTap: () => _viewChart([trade]),
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

    if (_isSelectionMode) {
      final isSelected = _selectedIds.contains(trade.id);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _toggleSelection(trade.id),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (v) => _toggleSelection(trade.id),
                  activeColor: AppColors.primary,
                  side: BorderSide(color: _textMuted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Expanded(child: IgnorePointer(child: content)),
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onLongPress: () {
          _toggleSelectionMode();
          _toggleSelection(trade.id);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: content
        ),
      );
    }
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

  // 每一局汇总 (Expandable List)
  Widget _buildDailyList(AccountService account) {
    final trades = account.tradeHistory;
    if (trades.isEmpty) {
      return Center(child: Text('暂无交易记录', style: TextStyle(color: _textMuted, fontSize: 16)));
    }

    // Group by Training Time (Session)
    final Map<String, List<TradeRecord>> grouped = {};
    for (final t in trades) {
      final key = t.trainingTime.toIso8601String();
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(t);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (_, i) {
        final key = sortedKeys[i];
        final sessionTrades = grouped[key]!;
        
        return _buildSessionCard(sessionTrades);
      },
    );
  }

  Widget _buildSessionCard(List<TradeRecord> sessionTrades) {
    final firstTrade = sessionTrades.first;
    
    // Calculate Session Stats
    final totalPnL = sessionTrades.fold(0.0, (sum, t) => sum + t.pnl);
    final wins = sessionTrades.where((t) => t.isWin).length;
    final winRate = sessionTrades.isEmpty ? 0.0 : (wins / sessionTrades.length * 100);
    final pnlColor = totalPnL >= 0 ? AppColors.bullish : AppColors.bearish; // Using theme colors
    
    // Time calculations
    DateTime startTime = sessionTrades.first.entryTime;
    DateTime endTime = sessionTrades.first.closeTime;
    for (var t in sessionTrades) {
      if (t.entryTime.isBefore(startTime)) startTime = t.entryTime;
      if (t.closeTime.isAfter(endTime)) endTime = t.closeTime;
    }
    final duration = endTime.difference(startTime);
    final durationStr = duration.inHours > 0 
        ? '${duration.inHours}小时${duration.inMinutes.remainder(60)}分钟' 
        : '${duration.inMinutes}分钟';

    // Sort trades by entry time
    final sortedTrades = List<TradeRecord>.from(sessionTrades)..sort((a, b) => a.entryTime.compareTo(b.entryTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.12 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          // Header (Summary Card)
          title: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insert_chart, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(firstTrade.instrumentCode, style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        _buildTag(firstTrade.type == 'spot' ? '现货' : '合约', Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '训练时间: ${_dateFmt.format(firstTrade.trainingTime)}', 
                      style: TextStyle(color: _textSecondary, fontSize: 12)
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    '${totalPnL >= 0 ? "+" : ""}${totalPnL.toStringAsFixed(2)}',
                    style: TextStyle(color: pnlColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${winRate.toStringAsFixed(2)}%',
                    style: TextStyle(color: winRate >= 50 ? AppColors.success : _textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          // Expanded Content (Details)
          children: [
             Divider(color: _dividerClr, height: 24),
             
             // Detailed Stats Grid
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _buildDetailItem('开始', _dateFmt.format(startTime)),
                 _buildDetailItem('结束', _dateFmt.format(endTime), alignment: CrossAxisAlignment.end),
               ],
             ),
             const SizedBox(height: 12),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _buildDetailItem('时间跨度', durationStr),
                 _buildDetailItem('战绩统计', '$wins胜 / ${sessionTrades.length - wins}负', alignment: CrossAxisAlignment.end),
               ],
             ),
             const SizedBox(height: 12),
             Align(
                alignment: Alignment.centerRight,
                child: Text('总成交/胜率: ${sessionTrades.length}笔 / ${winRate.toStringAsFixed(1)}%', style: TextStyle(color: _textSecondary, fontSize: 12)),
             ),
             
             const SizedBox(height: 20),
             Align(
               alignment: Alignment.centerLeft,
               child: Text('交易明细 (${sessionTrades.length}笔)', style: TextStyle(color: _textMuted, fontSize: 13)),
             ),
             const SizedBox(height: 10),
             
             // Trade List
             ...sortedTrades.map((trade) {
                final tPnlColor = trade.pnl >= 0 ? AppColors.bullish : AppColors.bearish;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _surfaceClr,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildTag(trade.direction == 'long' ? '多' : '空', trade.isLong ? AppColors.bullish : AppColors.bearish),
                      const SizedBox(width: 12),
                      Text('${trade.entryPrice.toStringAsFixed(1)} → ${trade.closePrice.toStringAsFixed(1)}', 
                           style: TextStyle(color: _textSecondary, fontSize: 14)),
                      const Spacer(),
                      Text('${trade.pnl >= 0 ? "+" : ""}${trade.pnl.toStringAsFixed(2)}', 
                           style: TextStyle(color: tPnlColor, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
             }),
             
             const SizedBox(height: 16),
             
             // Review Button
             Align(
               alignment: Alignment.centerRight,
               child: ElevatedButton.icon(
                 onPressed: () => _viewChart(sessionTrades),
                 icon: const Icon(Icons.history, size: 18),
                 label: const Text('回顾整局走势'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.primary.withOpacity(0.1),
                   foregroundColor: AppColors.primary,
                   elevation: 0,
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }

  void _viewChart(List<TradeRecord> trades) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeHistoryChartScreen(sessionTrades: trades),
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
