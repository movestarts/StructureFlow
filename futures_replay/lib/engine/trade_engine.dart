import 'package:flutter/foundation.dart';
import '../models/trade_model.dart';
import '../models/kline_model.dart';

class TradeEngine extends ChangeNotifier {
  double balance;
  final List<Trade> allTrades = []; // All trades (open + closed)
  final List<Trade> activePositions = [];

  TradeEngine({this.balance = 1000000}); // Default 1M

  // Getters
  double get floatingPnL {
    if (activePositions.isEmpty) return 0;
    return 0; // Placeholder, need update method
  }

  double get totalEquity => balance + floatingPnL;
  
  List<Trade> get closedTrades => allTrades.where((t) => !t.isOpen).toList();

  void placeOrder(Direction dir, double quantity, double price, DateTime time) {
    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entryTime: time,
      entryPrice: price,
      direction: dir,
      quantity: quantity,
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
