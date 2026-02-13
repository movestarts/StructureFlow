import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局账户服务 - 持久化训练结果
class AccountService extends ChangeNotifier {
  double balance = 100000.0; // 初始资金 10万
  double totalPnL = 0.0;
  int tradeCount = 0;
  int winCount = 0;

  double get roi => balance != 0 ? ((balance - 100000) / 100000 * 100) : 0.0;
  double get winRate => tradeCount > 0 ? (winCount / tradeCount * 100) : 0.0;

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

  /// 重置账户
  void reset() {
    balance = 100000.0;
    totalPnL = 0.0;
    tradeCount = 0;
    winCount = 0;
    notifyListeners();
    _saveToDisk();
  }

  // ===== 本地持久化 =====

  Future<String> get _filePath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/account_data.json';
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
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载账户数据失败: $e');
    }
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
}
