/// 缠论核心分析算法
/// 
/// 包含：
/// - 去除包含关系
/// - 分型识别
/// - 笔识别
/// - 中枢识别
library;

import 'enum.dart';
import 'objects.dart';

/// 全局配置
class CzscConfig {
  /// 最小笔长度（K线数量）
  static int minBiLen = 4;
  
  /// 最大保留笔数量
  static int maxBiNum = 100;
  
  /// 是否输出详细日志
  static bool verbose = false;
}

/// 去除包含关系
/// 
/// 输入三根K线，其中k1和k2为没有包含关系的K线，k3为原始K线
/// 返回 (是否有包含关系, 处理后的新K线)
RemoveIncludeResult removeInclude(NewBar k1, NewBar k2, RawBar k3) {
  Direction direction;
  
  if (k1.high < k2.high) {
    direction = Direction.up;
  } else if (k1.high > k2.high) {
    direction = Direction.down;
  } else {
    return RemoveIncludeResult(
      hasInclude: false,
      newBar: NewBar(
        symbol: k3.symbol,
        id: k3.id,
        dt: k3.dt,
        freq: k3.freq,
        open: k3.open,
        close: k3.close,
        high: k3.high,
        low: k3.low,
        vol: k3.vol,
        amount: k3.amount,
        elements: [k3],
      ),
    );
  }

  final k2ContainsK3 = (k2.high <= k3.high && k2.low >= k3.low) ||
      (k2.high >= k3.high && k2.low <= k3.low);

  if (k2ContainsK3) {
    double high, low;
    DateTime dt;

    if (direction == Direction.up) {
      high = k2.high > k3.high ? k2.high : k3.high;
      low = k2.low > k3.low ? k2.low : k3.low;
      dt = k2.high > k3.high ? k2.dt : k3.dt;
    } else {
      high = k2.high < k3.high ? k2.high : k3.high;
      low = k2.low < k3.low ? k2.low : k3.low;
      dt = k2.low < k3.low ? k2.dt : k3.dt;
    }

    final open = k3.open > k3.close ? high : low;
    final close = k3.open > k3.close ? low : high;
    final vol = k2.vol + k3.vol;
    final amount = k2.amount + k3.amount;

    final elements = <RawBar>[
      ...k2.elements.where((x) => x.dt != k3.dt).take(100),
      k3,
    ];

    return RemoveIncludeResult(
      hasInclude: true,
      newBar: NewBar(
        symbol: k3.symbol,
        id: k2.id,
        dt: dt,
        freq: k2.freq,
        open: open,
        close: close,
        high: high,
        low: low,
        vol: vol,
        amount: amount,
        elements: elements,
      ),
    );
  } else {
    return RemoveIncludeResult(
      hasInclude: false,
      newBar: NewBar(
        symbol: k3.symbol,
        id: k3.id,
        dt: k3.dt,
        freq: k3.freq,
        open: k3.open,
        close: k3.close,
        high: k3.high,
        low: k3.low,
        vol: k3.vol,
        amount: k3.amount,
        elements: [k3],
      ),
    );
  }
}

/// 去除包含关系结果
class RemoveIncludeResult {
  final bool hasInclude;
  final NewBar newBar;

  const RemoveIncludeResult({
    required this.hasInclude,
    required this.newBar,
  });
}

/// 检查分型
/// 
/// 输入三根无包含关系的K线，判断是否构成顶分型或底分型
FX? checkFx(NewBar k1, NewBar k2, NewBar k3) {
  if (k1.high < k2.high && k2.high > k3.high &&
      k1.low < k2.low && k2.low > k3.low) {
    return FX(
      symbol: k1.symbol,
      dt: k2.dt,
      mark: Mark.g,
      high: k2.high,
      low: k2.low,
      fx: k2.high,
      elements: [k1, k2, k3],
    );
  }

  if (k1.low > k2.low && k2.low < k3.low &&
      k1.high > k2.high && k2.high < k3.high) {
    return FX(
      symbol: k1.symbol,
      dt: k2.dt,
      mark: Mark.d,
      high: k2.high,
      low: k2.low,
      fx: k2.low,
      elements: [k1, k2, k3],
    );
  }

  return null;
}

/// 检查所有分型
/// 
/// 输入一串无包含关系K线，查找其中所有分型
List<FX> checkFxs(List<NewBar> bars) {
  final fxs = <FX>[];

  for (var i = 1; i < bars.length - 1; i++) {
    final fx = checkFx(bars[i - 1], bars[i], bars[i + 1]);
    if (fx != null) {
      if (fxs.isNotEmpty && fx.mark == fxs.last.mark) {
        if (CzscConfig.verbose) {
          print('checkFxs错误: ${bars[i].dt}, ${fx.mark}, ${fxs.last.mark}');
        }
      } else {
        fxs.add(fx);
      }
    }
  }

  return fxs;
}

/// 检查一笔
/// 
/// 输入一串无包含关系K线，查找其中的一笔
CheckBiResult checkBi(List<NewBar> bars) {
  final minBiLen = CzscConfig.minBiLen;
  final fxs = checkFxs(bars);

  if (fxs.length < 2) {
    return CheckBiResult(bi: null, remainBars: bars);
  }

  final fxA = fxs.first;
  Direction direction;
  FX? fxB;

  if (fxA.mark == Mark.d) {
    direction = Direction.up;
    final candidates = fxs.where((x) =>
        x.mark == Mark.g && x.dt.isAfter(fxA.dt) && x.fx > fxA.fx).toList();
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => a.dt.compareTo(b.dt));
      for (final candidate in candidates) {
        final barsA = bars.where((x) =>
            !x.dt.isBefore(fxA.elements.first.dt) &&
            !x.dt.isAfter(candidate.elements.last.dt)).toList();
        
        final abInclude = (fxA.high > candidate.high && fxA.low < candidate.low) ||
            (fxA.high < candidate.high && fxA.low > candidate.low);
        
        if (!abInclude && barsA.length >= minBiLen) {
          fxB = candidate;
          break;
        }
      }
    }
  } else {
    direction = Direction.down;
    final candidates = fxs.where((x) =>
        x.mark == Mark.d && x.dt.isAfter(fxA.dt) && x.fx < fxA.fx).toList();
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => a.dt.compareTo(b.dt));
      for (final candidate in candidates) {
        final barsA = bars.where((x) =>
            !x.dt.isBefore(fxA.elements.first.dt) &&
            !x.dt.isAfter(candidate.elements.last.dt)).toList();
        
        final abInclude = (fxA.high > candidate.high && fxA.low < candidate.low) ||
            (fxA.high < candidate.high && fxA.low > candidate.low);
        
        if (!abInclude && barsA.length >= minBiLen) {
          fxB = candidate;
          break;
        }
      }
    }
  }

  if (fxB == null) {
    return CheckBiResult(bi: null, remainBars: bars);
  }

  final fxBNotNull = fxB;
  final barsA = bars.where((x) =>
      !x.dt.isBefore(fxA.elements.first.dt) &&
      !x.dt.isAfter(fxBNotNull.elements.last.dt)).toList();
  final barsB = bars.where((x) => !x.dt.isBefore(fxBNotNull.elements.first.dt)).toList();

  final fxsInBi = fxs.where((x) =>
      !x.dt.isBefore(fxA.elements.first.dt) &&
      !x.dt.isAfter(fxBNotNull.elements.last.dt)).toList();

  return CheckBiResult(
    bi: BI(
      symbol: fxA.symbol,
      fxA: fxA,
      fxB: fxB,
      direction: direction,
      fxs: fxsInBi,
      bars: barsA,
    ),
    remainBars: barsB,
  );
}

/// 检查笔结果
class CheckBiResult {
  final BI? bi;
  final List<NewBar> remainBars;

  const CheckBiResult({
    required this.bi,
    required this.remainBars,
  });
}

/// 获取中枢序列
/// 
/// 输入连续笔列表，返回中枢序列
List<ZS> getZsSeq(List<BI> bis) {
  final zsList = <ZS>[];

  if (bis.isEmpty) return zsList;

  for (final bi in bis) {
    if (zsList.isEmpty) {
      zsList.add(ZS(bis: [bi]));
      continue;
    }

    final zs = zsList.last;
    if (zs.bis.isEmpty) {
      zsList[zsList.length - 1] = ZS(bis: [bi]);
    } else {
      final isUpAndBreak = bi.direction == Direction.up && bi.high < zs.zd;
      final isDownAndBreak = bi.direction == Direction.down && bi.low > zs.zg;

      if (isUpAndBreak || isDownAndBreak) {
        zsList.add(ZS(bis: [bi]));
      } else {
        zsList[zsList.length - 1] = ZS(bis: [...zs.bis, bi]);
      }
    }
  }

  return zsList;
}

/// 获取有效中枢序列
/// 
/// 过滤掉无效中枢（zg < zd 或笔数小于3）
List<ZS> getValidZsSeq(List<BI> bis) {
  final allZs = getZsSeq(bis);
  return allZs.where((zs) => zs.bis.length >= 3 && zs.isValid).toList();
}
