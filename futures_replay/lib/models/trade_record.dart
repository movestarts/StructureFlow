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
  final String? period;         // 训练周期 (e.g. 'm5', 'm30')
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
    this.period,
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
    'period': period,
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
      period: json['period'] as String?,
    );
  }

  // 这里的格式化最好在 Model 外部处理或统一，但为了方便 CSV 导出，直接在此实现
  // 注意：需要确保调用此方法前 DateFormat 可用，这里简单处理
  List<dynamic> toCsvRow() {
    // 简单格式化，避免引入 intl 依赖如果未引入 (虽然项目有 intl)
    // 格式：yyyy-MM-dd HH:mm
    String fmt(DateTime dt) {
      final y = dt.year;
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min';
    }

    return [
      id,
      instrumentCode,
      direction, // Long/Short
      fmt(entryTime),
      fmt(closeTime),
      entryPrice,
      closePrice,
      pnl,
      pnlPercent,
      quantity,
      period ?? '', // Period
      '', // Setup_Pattern
      '', // Mistake_Tag
      '', // Strategy_Notes
    ];
  }
}
