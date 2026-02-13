/// 交易历史记录模型 - 用于持久化
class TradeRecord {
  final String id;
  final String instrumentCode;  // 品种代码
  final String direction;       // 'long' | 'short'
  final String type;            // 'spot' | 'futures'
  final double entryPrice;
  final double closePrice;
  final double quantity;
  final int leverage;
  final double pnl;
  final double fee;
  final DateTime entryTime;
  final DateTime closeTime;
  final DateTime trainingTime;  // 训练时间戳
  final String? csvPath;        // 原始CSV路径（用于查看K线）
  final int? startIndex;        // K线起始位置
  final int? visibleBars;       // 可见K线数量

  TradeRecord({
    required this.id,
    required this.instrumentCode,
    required this.direction,
    required this.type,
    required this.entryPrice,
    required this.closePrice,
    required this.quantity,
    required this.leverage,
    required this.pnl,
    required this.fee,
    required this.entryTime,
    required this.closeTime,
    required this.trainingTime,
    this.csvPath,
    this.startIndex,
    this.visibleBars,
  });

  double get pnlPercent {
    final cost = entryPrice * quantity;
    if (cost == 0) return 0;
    return (pnl / cost) * 100;
  }

  bool get isWin => pnl > 0;
  bool get isLong => direction == 'long';

  Map<String, dynamic> toJson() => {
    'id': id,
    'instrumentCode': instrumentCode,
    'direction': direction,
    'type': type,
    'entryPrice': entryPrice,
    'closePrice': closePrice,
    'quantity': quantity,
    'leverage': leverage,
    'pnl': pnl,
    'fee': fee,
    'entryTime': entryTime.toIso8601String(),
    'closeTime': closeTime.toIso8601String(),
    'trainingTime': trainingTime.toIso8601String(),
    'csvPath': csvPath,
    'startIndex': startIndex,
    'visibleBars': visibleBars,
  };

  factory TradeRecord.fromJson(Map<String, dynamic> json) {
    return TradeRecord(
      id: json['id'] as String,
      instrumentCode: json['instrumentCode'] as String? ?? 'RB',
      direction: json['direction'] as String? ?? 'long',
      type: json['type'] as String? ?? 'futures',
      entryPrice: (json['entryPrice'] as num).toDouble(),
      closePrice: (json['closePrice'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      leverage: (json['leverage'] as int?) ?? 1,
      pnl: (json['pnl'] as num).toDouble(),
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      entryTime: DateTime.parse(json['entryTime'] as String),
      closeTime: DateTime.parse(json['closeTime'] as String),
      trainingTime: DateTime.parse(json['trainingTime'] as String),
      csvPath: json['csvPath'] as String?,
      startIndex: json['startIndex'] as int?,
      visibleBars: json['visibleBars'] as int?,
    );
  }
}
