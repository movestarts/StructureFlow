import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trade_record.dart';
import 'database_service.dart';

List<Map<String, dynamic>> _decodeTradeHistoryJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

/// Global account service: persistent training summary + trade history.
class AccountService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  double balance = 100000.0; // Initial capital
  double totalPnL = 0.0;
  int tradeCount = 0;
  int winCount = 0;

  /// Trade history records, newest first.
  List<TradeRecord> tradeHistory = [];

  double _cachedTotalFees = 0.0;
  int _cachedLongCount = 0;
  int _cachedShortCount = 0;

  double get roi => balance != 0 ? ((balance - 100000) / 100000 * 100) : 0.0;
  double get winRate => tradeCount > 0 ? (winCount / tradeCount * 100) : 0.0;

  /// Total fees.
  double get totalFees => _cachedTotalFees;

  /// Number of long trades.
  int get longCount => _cachedLongCount;

  /// Number of short trades.
  int get shortCount => _cachedShortCount;

  AccountService() {
    _loadFromDisk();
  }

  /// Submit summary from one finished session.
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

  /// Add one trade record.
  void addTradeRecord(TradeRecord record) {
    tradeHistory.insert(0, record);
    _applyTradeRecordDelta(record, adding: true);
    notifyListeners();
    _saveHistoryToDisk();
  }

  /// Add multiple trade records.
  void addTradeRecords(List<TradeRecord> records) {
    for (final r in records) {
      tradeHistory.insert(0, r);
      _applyTradeRecordDelta(r, adding: true);
    }
    notifyListeners();
    _saveHistoryToDisk();
  }

  /// Clear history.
  void clearHistory() {
    tradeHistory.clear();
    _recomputeTradeHistoryStats();
    notifyListeners();
    _saveHistoryToDisk();
    _db.clearAiReviews();
  }

  /// Reset account and history.
  void reset() {
    balance = 100000.0;
    totalPnL = 0.0;
    tradeCount = 0;
    winCount = 0;
    tradeHistory.clear();
    _recomputeTradeHistoryStats();
    notifyListeners();
    _saveToDisk();
    _saveHistoryToDisk();
    _db.clearAiReviews();
  }

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
      debugPrint('Load account data failed: $e');
    }

    bool loadedFromDb = false;
    try {
      final dbHistory = await _db.loadTradeHistory();
      if (dbHistory.isNotEmpty) {
        tradeHistory = dbHistory;
        loadedFromDb = true;
      }
    } catch (e) {
      debugPrint('Load trade history from Isar failed: $e');
    }

    if (!loadedFromDb) {
      try {
        final path = await _historyPath;
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          final shouldUseIsolate = content.length > 64 * 1024;
          final jsonList = shouldUseIsolate
              ? await compute(_decodeTradeHistoryJson, content)
              : _decodeTradeHistoryJson(content);
          tradeHistory = jsonList.map(TradeRecord.fromJson).toList();

          if (tradeHistory.isNotEmpty) {
            await _db.saveTradeHistorySnapshot(tradeHistory);
          }
        }
      } catch (e) {
        debugPrint('Load trade history failed: $e');
      }
    }

    _recomputeTradeHistoryStats();
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
      debugPrint('Save account data failed: $e');
    }
  }

  Future<void> _saveHistoryToDisk() async {
    try {
      final path = await _historyPath;
      final file = File(path);
      await file.writeAsString(jsonEncode(
        tradeHistory.map((t) => t.toJson()).toList(),
      ));

      await _db.saveTradeHistorySnapshot(tradeHistory);
    } catch (e) {
      debugPrint('Save trade history failed: $e');
    }
  }

  void _applyTradeRecordDelta(TradeRecord record, {required bool adding}) {
    final sign = adding ? 1 : -1;
    _cachedTotalFees += sign * record.fee;
    if (record.isLong) {
      _cachedLongCount += sign;
    } else {
      _cachedShortCount += sign;
    }
  }

  void _recomputeTradeHistoryStats() {
    double feeSum = 0.0;
    int long = 0;
    int short = 0;
    for (final t in tradeHistory) {
      feeSum += t.fee;
      if (t.isLong) {
        long += 1;
      } else {
        short += 1;
      }
    }
    _cachedTotalFees = feeSum;
    _cachedLongCount = long;
    _cachedShortCount = short;
  }
}
