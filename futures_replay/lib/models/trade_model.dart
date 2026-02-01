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
      isOpen: false,
      closePrice: price,
      closeTime: time,
    );
  }

  double calculatePnL(double currentPrice) {
    final exitPrice = isOpen ? currentPrice : (closePrice ?? currentPrice);
    if (direction == Direction.long) {
      return (exitPrice - entryPrice) * quantity; 
    } else {
      return (entryPrice - exitPrice) * quantity;
    }
  }
  
  double get realizedPnL {
    if (isOpen) return 0;
    return calculatePnL(closePrice!);
  }
}
