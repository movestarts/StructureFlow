import 'package:flutter/foundation.dart';
import '../models/trade_model.dart';

class TradeEngine extends ChangeNotifier {
  double balance;
  final List<Trade> allTrades = []; // All trades (open + closed)
  final List<Trade> activePositions = [];

  TradeEngine({this.balance = 1000000}); // Default 1M

  // Getters
  double get totalEquity => balance + calculateFloatingPnL(0); // need price
  
  List<Trade> get closedTrades => allTrades.where((t) => !t.isOpen).toList();

  /// 可用保证金 = 余额 - 已占用保证金
  double get availableMargin {
    double usedMargin = 0;
    for (var p in activePositions) {
      usedMargin += (p.entryPrice * p.quantity) / p.leverage;
    }
    return balance - usedMargin;
  }

  void placeOrder(Direction dir, double quantity, double price, DateTime time, {int leverage = 1}) {
    // 检查保证金是否足够
    final requiredMargin = (price * quantity) / leverage;
    if (requiredMargin > availableMargin) return;

    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entryTime: time,
      entryPrice: price,
      direction: dir,
      quantity: quantity,
      leverage: leverage,
    );
    activePositions.add(trade);
    allTrades.add(trade);
    notifyListeners();
  }

  void closeAll(double price, DateTime time) {
    for (var t in activePositions) {
      var closed = t.close(price, time);
      balance += closed.realizedPnL;
      
      // Replace in allTrades
      final idx = allTrades.indexWhere((tr) => tr.id == t.id);
      if (idx != -1) {
        allTrades[idx] = closed;
      }
    }
    activePositions.clear();
    notifyListeners();
  }
  
  double calculateFloatingPnL(double currentPrice) {
    double total = 0;
    for (var p in activePositions) {
      total += p.calculatePnL(currentPrice);
    }
    return total;
  }
}
