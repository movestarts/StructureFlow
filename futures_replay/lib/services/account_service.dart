import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trade_record.dart';

/// 全局账户服务 - 持久化训练结果 + 交易历史
class AccountService extends ChangeNotifier {
  double balance = 100000.0; // 初始资金 10万
  double totalPnL = 0.0;
  int tradeCount = 0;
  int winCount = 0;

  /// 交易历史记录
  List<TradeRecord> tradeHistory = [];

  double get roi => balance != 0 ? ((balance - 100000) / 100000 * 100) : 0.0;
  double get winRate => tradeCount > 0 ? (winCount / tradeCount * 100) : 0.0;

  /// 总手续费
  double get totalFees => tradeHistory.fold(0.0, (sum, t) => sum + t.fee);

  /// 做多次数
  int get longCount => tradeHistory.where((t) => t.isLong).length;

  /// 做空次数
  int get shortCount => tradeHistory.where((t) => !t.isLong).length;

  AccountService() {
    _loadFromDisk();
  }

  /// 训练结束后提交结果
  void submitSessionResult({
    required double sessionPnL,
    required int sessionTradeCount,
    required int sessionWinCount,
  }) {
    balance += sessionPnL;
    totalPnL += sessionPnL;
    tradeCount += sessionTradeCount;
    winCount += sessionWinCount;
    notifyListeners();
    _saveToDisk();
  }

  /// 添加交易记录
  void addTradeRecord(TradeRecord record) {
    tradeHistory.insert(0, record); // 新的排在前面
    notifyListeners();
    _saveHistoryToDisk();
  }

  /// 批量添加交易记录
  void addTradeRecords(List<TradeRecord> records) {
    for (final r in records) {
      tradeHistory.insert(0, r);
    }
    notifyListeners();
    _saveHistoryToDisk();
  }

  /// 清空交易历史
  void clearHistory() {
    tradeHistory.clear();
    notifyListeners();
    _saveHistoryToDisk();
  }

  /// 重置账户
  void reset() {
    balance = 100000.0;
    totalPnL = 0.0;
    tradeCount = 0;
    winCount = 0;
    tradeHistory.clear();
    notifyListeners();
    _saveToDisk();
    _saveHistoryToDisk();
  }

  // ===== 本地持久化 =====

  Future<String> get _filePath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/account_data.json';
  }

  Future<String> get _historyPath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/trade_history.json';
  }

  Future<void> _loadFromDisk() async {
    try {
      final path = await _filePath;
      final file = File(path);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        balance = (json['balance'] as num?)?.toDouble() ?? 100000.0;
        totalPnL = (json['totalPnL'] as num?)?.toDouble() ?? 0.0;
        tradeCount = (json['tradeCount'] as int?) ?? 0;
        winCount = (json['winCount'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('加载账户数据失败: $e');
    }

    // 加载交易历史
    try {
      final path = await _historyPath;
      final file = File(path);
      if (await file.exists()) {
        final jsonList = jsonDecode(await file.readAsString()) as List;
        tradeHistory = jsonList
            .map((j) => TradeRecord.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('加载交易历史失败: $e');
    }

    notifyListeners();
  }

  Future<void> _saveToDisk() async {
    try {
      final path = await _filePath;
      final file = File(path);
      await file.writeAsString(jsonEncode({
        'balance': balance,
        'totalPnL': totalPnL,
        'tradeCount': tradeCount,
        'winCount': winCount,
      }));
    } catch (e) {
      debugPrint('保存账户数据失败: $e');
    }
  }

  Future<void> _saveHistoryToDisk() async {
    try {
      final path = await _historyPath;
      final file = File(path);
      await file.writeAsString(jsonEncode(
        tradeHistory.map((t) => t.toJson()).toList(),
      ));
    } catch (e) {
      debugPrint('保存交易历史失败: $e');
    }
  }
}
