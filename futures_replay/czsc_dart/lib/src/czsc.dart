/// CZSC 主类 - 缠论分析器
library;

import 'enum.dart';
import 'objects.dart';
import 'analyze.dart';

/// 缠论分析器
/// 
/// 用于分析K线数据，识别分型、笔、中枢
class CZSC {
  /// 原始K线序列
  final List<RawBar> _barsRaw = [];
  
  /// 未完成笔的无包含K线序列
  final List<NewBar> _barsUbi = [];
  
  /// 笔列表
  final List<BI> _biList = [];
  
  /// 交易标的代码
  late final String symbol;
  
  /// K线周期
  late final Freq freq;
  
  /// 最大保留笔数量
  final int maxBiNum;

  CZSC({
    required List<RawBar> bars,
    this.maxBiNum = 100,
  }) {
    if (bars.isEmpty) {
      throw ArgumentError('K线数据不能为空');
    }
    
    symbol = bars.first.symbol;
    freq = bars.first.freq;
    
    // 批量处理所有K线
    _processAllBars(bars);
    _updateBiAll();
  }

  /// 批量处理所有K线
  void _processAllBars(List<RawBar> bars) {
    for (final bar in bars) {
      _barsRaw.add(bar);
      
      if (_barsUbi.length < 2) {
        _barsUbi.add(NewBar(
          symbol: bar.symbol,
          id: bar.id,
          dt: bar.dt,
          freq: bar.freq,
          open: bar.open,
          close: bar.close,
          high: bar.high,
          low: bar.low,
          vol: bar.vol,
          amount: bar.amount,
          elements: [bar],
        ));
      } else {
        final k1 = _barsUbi[_barsUbi.length - 2];
        final k2 = _barsUbi[_barsUbi.length - 1];
        final result = removeInclude(k1, k2, bar);
        
        if (result.hasInclude) {
          _barsUbi[_barsUbi.length - 1] = result.newBar;
        } else {
          _barsUbi.add(result.newBar);
        }
      }
    }
  }

  /// 批量更新笔
  void _updateBiAll() {
    if (_barsUbi.length < 3) return;

    // 找第一个分型
    var fxs = checkFxs(_barsUbi);
    if (fxs.isEmpty) return;

    var fxA = fxs.first;
    final fxsA = fxs.where((x) => x.mark == fxA.mark);
    for (final fx in fxsA) {
      if ((fxA.mark == Mark.d && fx.low <= fxA.low) ||
          (fxA.mark == Mark.g && fx.high >= fxA.high)) {
        fxA = fx;
      }
    }

    // 移除 fxA 之前的 K 线
    _barsUbi.removeWhere((x) => x.dt.isBefore(fxA.elements.first.dt));

    // 循环识别笔
    while (_barsUbi.length >= 5) {
      final result = checkBi(_barsUbi);
      
      if (result.bi != null) {
        _biList.add(result.bi!);
        _barsUbi.clear();
        _barsUbi.addAll(result.remainBars);
      } else {
        break;
      }
    }
  }

  /// 原始K线列表
  List<RawBar> get barsRaw => List.unmodifiable(_barsRaw);
  
  /// 未完成笔的无包含K线序列
  List<NewBar> get barsUbi => List.unmodifiable(_barsUbi);
  
  /// 笔列表
  List<BI> get biList => List.unmodifiable(_biList);

  /// 分型列表（包括未完成笔中的分型）
  List<FX> get fxList {
    final fxs = <FX>[];
    for (final bi in _biList) {
      fxs.addAll(bi.fxs.skip(1));
    }
    final ubiFxs = checkFxs(_barsUbi);
    for (final x in ubiFxs) {
      if (fxs.isEmpty || x.dt.isAfter(fxs.last.dt)) {
        fxs.add(x);
      }
    }
    return fxs;
  }

  /// 中枢列表
  List<ZS> get zsList => getValidZsSeq(_biList);

  /// 已完成的笔
  List<BI> get finishedBis {
    if (_biList.isEmpty) return [];
    if (_barsUbi.length < 5) return _biList.sublist(0, _biList.length - 1);
    return _biList;
  }

  /// 最后一笔是否在延伸中
  bool get lastBiExtend {
    if (_biList.isEmpty) return false;
    
    final lastBi = _biList.last;
    if (lastBi.direction == Direction.up) {
      return _barsUbi.map((x) => x.high).reduce((a, b) => a > b ? a : b) > lastBi.high;
    } else {
      return _barsUbi.map((x) => x.low).reduce((a, b) => a < b ? a : b) < lastBi.low;
    }
  }

  /// 未完成的笔信息
  Map<String, dynamic>? get ubi {
    final ubiFxs = checkFxs(_barsUbi);
    if (_barsUbi.isEmpty || _biList.isEmpty || ubiFxs.isEmpty) return null;

    final rawBars = _barsUbi.expand((x) => x.rawBars).toList();
    final highBar = rawBars.reduce((a, b) => a.high > b.high ? a : b);
    final lowBar = rawBars.reduce((a, b) => a.high < b.high ? a : b);
    final direction = _biList.last.direction == Direction.down ? Direction.up : Direction.down;

    return {
      'symbol': symbol,
      'direction': direction,
      'high': highBar.high,
      'low': lowBar.low,
      'highBar': highBar,
      'lowBar': lowBar,
      'bars': _barsUbi,
      'rawBars': rawBars,
      'fxs': ubiFxs,
      'fxA': ubiFxs.first,
    };
  }

  @override
  String toString() {
    return '<CZSC~$symbol~$freq>';
  }
}
