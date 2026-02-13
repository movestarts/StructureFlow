enum Direction {
  long,
  short;

  String get label => this == Direction.long ? '多' : '空';
}

class Trade {
  final String id;
  final DateTime entryTime;
  final double entryPrice;
  final Direction direction;
  final double quantity; // Lots
  final int leverage;
  
  // For simplicity, we track closed status
  final bool isOpen;
  final double? closePrice;
  final DateTime? closeTime;

  const Trade({
    required this.id,
    required this.entryTime,
    required this.entryPrice,
    required this.direction,
    required this.quantity,
    this.leverage = 1,
    this.isOpen = true,
    this.closePrice,
    this.closeTime,
  });

  Trade close(double price, DateTime time) {
    return Trade(
      id: id,
      entryTime: entryTime,
      entryPrice: entryPrice,
      direction: direction,
      quantity: quantity,
      leverage: leverage,
      isOpen: false,
      closePrice: price,
      closeTime: time,
    );
  }

  /// PnL 计算考虑杠杆
  double calculatePnL(double currentPrice) {
    final exitPrice = isOpen ? currentPrice : (closePrice ?? currentPrice);
    if (direction == Direction.long) {
      return (exitPrice - entryPrice) * quantity * leverage; 
    } else {
      return (entryPrice - exitPrice) * quantity * leverage;
    }
  }
  
  double get realizedPnL {
    if (isOpen) return 0;
    return calculatePnL(closePrice!);
  }

  /// 已占用保证金
  double get usedMargin => (entryPrice * quantity) / leverage;
}
