/// 缠论核心数据结构定义
library;

import 'package:collection/collection.dart';
import 'enum.dart';

/// 原始K线数据
class RawBar {
  /// 交易标的代码
  final String symbol;
  
  /// K线序号（必须升序）
  final int id;
  
  /// 时间
  final DateTime dt;
  
  /// K线周期
  final Freq freq;
  
  /// 开盘价
  final double open;
  
  /// 收盘价
  final double close;
  
  /// 最高价
  final double high;
  
  /// 最低价
  final double low;
  
  /// 成交量
  final double vol;
  
  /// 成交金额
  final double amount;

  const RawBar({
    required this.symbol,
    required this.id,
    required this.dt,
    required this.freq,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.vol,
    this.amount = 0,
  });

  /// 上影线
  double get upper => high - (open > close ? open : close);

  /// 下影线
  double get lower => (open < close ? open : close) - low;

  /// 实体
  double get solid => (open - close).abs();

  /// 复制并修改部分字段
  RawBar copyWith({
    String? symbol,
    int? id,
    DateTime? dt,
    Freq? freq,
    double? open,
    double? close,
    double? high,
    double? low,
    double? vol,
    double? amount,
  }) {
    return RawBar(
      symbol: symbol ?? this.symbol,
      id: id ?? this.id,
      dt: dt ?? this.dt,
      freq: freq ?? this.freq,
      open: open ?? this.open,
      close: close ?? this.close,
      high: high ?? this.high,
      low: low ?? this.low,
      vol: vol ?? this.vol,
      amount: amount ?? this.amount,
    );
  }

  @override
  String toString() {
    return 'RawBar(symbol: $symbol, dt: $dt, open: $open, close: $close, high: $high, low: $low)';
  }
}

/// 去除包含关系后的K线
class NewBar {
  /// 交易标的代码
  final String symbol;
  
  /// K线序号
  final int id;
  
  /// 时间
  final DateTime dt;
  
  /// K线周期
  final Freq freq;
  
  /// 开盘价
  final double open;
  
  /// 收盘价
  final double close;
  
  /// 最高价
  final double high;
  
  /// 最低价
  final double low;
  
  /// 成交量
  final double vol;
  
  /// 成交金额
  final double amount;
  
  /// 具有包含关系的原始K线列表
  final List<RawBar> elements;

  const NewBar({
    required this.symbol,
    required this.id,
    required this.dt,
    required this.freq,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.vol,
    this.amount = 0,
    this.elements = const [],
  });

  /// 原始K线列表
  List<RawBar> get rawBars => elements;

  /// 复制并修改部分字段
  NewBar copyWith({
    String? symbol,
    int? id,
    DateTime? dt,
    Freq? freq,
    double? open,
    double? close,
    double? high,
    double? low,
    double? vol,
    double? amount,
    List<RawBar>? elements,
  }) {
    return NewBar(
      symbol: symbol ?? this.symbol,
      id: id ?? this.id,
      dt: dt ?? this.dt,
      freq: freq ?? this.freq,
      open: open ?? this.open,
      close: close ?? this.close,
      high: high ?? this.high,
      low: low ?? this.low,
      vol: vol ?? this.vol,
      amount: amount ?? this.amount,
      elements: elements ?? this.elements,
    );
  }

  @override
  String toString() {
    return 'NewBar(dt: $dt, high: $high, low: $low)';
  }
}

/// 分型
class FX {
  /// 交易标的代码
  final String symbol;
  
  /// 分型时间（中间K线的时间）
  final DateTime dt;
  
  /// 分型标记（顶/底）
  final Mark mark;
  
  /// 分型最高价
  final double high;
  
  /// 分型最低价
  final double low;
  
  /// 分型值（顶分型为high，底分型为low）
  final double fx;
  
  /// 构成分型的三根K线
  final List<NewBar> elements;

  const FX({
    required this.symbol,
    required this.dt,
    required this.mark,
    required this.high,
    required this.low,
    required this.fx,
    this.elements = const [],
  });

  /// 构成分型的无包含关系K线
  List<NewBar> get newBars => elements;

  /// 构成分型的原始K线
  List<RawBar> get rawBars {
    final result = <RawBar>[];
    for (final e in elements) {
      result.addAll(e.rawBars);
    }
    return result;
  }

  /// 分型力度描述
  String get powerStr {
    if (elements.length != 3) return '';
    final k1 = elements[0];
    final k2 = elements[1];
    final k3 = elements[2];

    if (mark == Mark.d) {
      if (k3.close > k1.high) {
        return '强';
      } else if (k3.close > k2.high) {
        return '中';
      } else {
        return '弱';
      }
    } else {
      if (k3.close < k1.low) {
        return '强';
      } else if (k3.close < k2.low) {
        return '中';
      } else {
        return '弱';
      }
    }
  }

  /// 成交量力度
  double get powerVolume {
    if (elements.length != 3) return 0;
    return elements.fold(0.0, (sum, x) => sum + x.vol);
  }

  /// 是否有重叠中枢
  bool get hasZs {
    if (elements.length != 3) return false;
    final zd = elements.map((x) => x.low).reduce((a, b) => a > b ? a : b);
    final zg = elements.map((x) => x.high).reduce((a, b) => a < b ? a : b);
    return zg >= zd;
  }

  @override
  String toString() {
    return 'FX(dt: $dt, mark: $mark, high: $high, low: $low, fx: $fx)';
  }
}

/// 笔
class BI {
  /// 交易标的代码
  final String symbol;
  
  /// 起始分型
  final FX fxA;
  
  /// 结束分型
  final FX fxB;
  
  /// 笔方向
  final Direction direction;
  
  /// 笔中的分型列表
  final List<FX> fxs;
  
  /// 笔中的K线列表
  final List<NewBar> bars;

  const BI({
    required this.symbol,
    required this.fxA,
    required this.fxB,
    required this.direction,
    this.fxs = const [],
    this.bars = const [],
  });

  /// 笔的起始时间
  DateTime get sdt => fxA.dt;

  /// 笔的结束时间
  DateTime get edt => fxB.dt;

  /// 笔的最高价
  double get high {
    if (direction == Direction.up) {
      return fxB.high;
    } else {
      return fxA.high;
    }
  }

  /// 笔的最低价
  double get low {
    if (direction == Direction.up) {
      return fxA.low;
    } else {
      return fxB.low;
    }
  }

  /// 笔的价格变化
  double get power => (high - low).abs();

  /// 笔的长度（K线数量）
  int get length => bars.length;

  /// 笔的原始K线
  List<RawBar> get rawBars {
    final result = <RawBar>[];
    for (final bar in bars) {
      result.addAll(bar.rawBars);
    }
    return result;
  }

  @override
  String toString() {
    return 'BI(sdt: $sdt, edt: $edt, direction: $direction, high: $high, low: $low)';
  }
}

/// 中枢
class ZS {
  /// 构成中枢的笔列表
  final List<BI> bis;

  ZS({required this.bis}) {
    if (bis.isEmpty) {
      throw ArgumentError('中枢必须至少包含一笔');
    }
  }

  /// 交易标的代码
  String get symbol => bis.first.symbol;

  /// 中枢起始时间
  DateTime get sdt => bis.first.sdt;

  /// 中枢结束时间
  DateTime get edt => bis.last.edt;

  /// 中枢第一笔方向
  Direction get sdir => bis.first.direction;

  /// 中枢最后一笔方向
  Direction get edir => bis.last.direction;

  /// 中枢上沿（前3笔的最小高点）
  double get zg {
    if (bis.length < 3) {
      return bis.map((b) => b.high).reduce((a, b) => a < b ? a : b);
    }
    return bis.take(3).map((b) => b.high).reduce((a, b) => a < b ? a : b);
  }

  /// 中枢下沿（前3笔的最大低点）
  double get zd {
    if (bis.length < 3) {
      return bis.map((b) => b.low).reduce((a, b) => a > b ? a : b);
    }
    return bis.take(3).map((b) => b.low).reduce((a, b) => a > b ? a : b);
  }

  /// 中枢中轴
  double get zz => zd + (zg - zd) / 2;

  /// 中枢最高点
  double get gg => bis.map((b) => b.high).reduce((a, b) => a > b ? a : b);

  /// 中枢最低点
  double get dd => bis.map((b) => b.low).reduce((a, b) => a < b ? a : b);

  /// 中枢是否有效
  bool get isValid {
    if (zg < zd) return false;

    for (final bi in bis) {
      if (zg >= bi.high && bi.high >= zd) continue;
      if (zg >= bi.low && bi.low >= zd) continue;
      if (bi.high >= zg && zg > zd && zd >= bi.low) continue;
      return false;
    }
    return true;
  }

  /// 中枢笔数
  int get biCount => bis.length;

  /// 中枢高度
  double get height => zg - zd;

  @override
  String toString() {
    return 'ZS(sdt: $sdt, edt: $edt, zg: ${zg.toStringAsFixed(2)}, zd: ${zd.toStringAsFixed(2)}, bis: ${bis.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ZS) return false;
    return const ListEquality().equals(bis, other.bis);
  }

  @override
  int get hashCode => Object.hashAll(bis);
}
