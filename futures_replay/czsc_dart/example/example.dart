/// CZSC Dart 使用示例
/// 
/// 展示如何使用czsc_dart进行缠论分析

import 'package:czsc_dart/czsc_dart.dart';

void main() {
  print('=== 缠论分析示例 ===\n');

  // 1. 创建K线数据
  final bars = generateKlines(300);
  print('生成了 ${bars.length} 根K线数据\n');

  // 2. 创建分析器
  final czsc = CZSC(bars: bars);

  // 3. 输出分析结果
  print('=== 分析结果 ===');
  print('K线数量: ${czsc.barsRaw.length}');
  print('笔数量: ${czsc.biList.length}');
  print('中枢数量: ${czsc.zsList.length}\n');

  // 4. 输出笔信息
  if (czsc.biList.isNotEmpty) {
    print('=== 笔列表 ===');
    for (var i = 0; i < czsc.biList.length; i++) {
      final bi = czsc.biList[i];
      print('笔${i + 1}: ${bi.direction.label} '
          '${bi.sdt.toString().substring(0, 10)} -> ${bi.edt.toString().substring(0, 10)} '
          'high=${bi.high.toStringAsFixed(2)} low=${bi.low.toStringAsFixed(2)}');
    }
    print('');
  }

  // 5. 输出中枢信息
  if (czsc.zsList.isNotEmpty) {
    print('=== 中枢列表 ===');
    for (var i = 0; i < czsc.zsList.length; i++) {
      final zs = czsc.zsList[i];
      print('中枢${i + 1}: ${zs.sdt.toString().substring(0, 10)} -> ${zs.edt.toString().substring(0, 10)}');
      print('  上沿(zg): ${zs.zg.toStringAsFixed(2)}');
      print('  下沿(zd): ${zs.zd.toStringAsFixed(2)}');
      print('  中轴(zz): ${zs.zz.toStringAsFixed(2)}');
      print('  高点: ${zs.gg.toStringAsFixed(2)}');
      print('  低点: ${zs.dd.toStringAsFixed(2)}');
      print('  笔数: ${zs.biCount}');
      print('  有效: ${zs.isValid}');
      print('');
    }
  }

  // 6. 输出分型信息
  if (czsc.fxList.isNotEmpty) {
    print('=== 分型列表 (最近10个) ===');
    final recentFxs = czsc.fxList.length > 10 
        ? czsc.fxList.sublist(czsc.fxList.length - 10) 
        : czsc.fxList;
    for (var i = 0; i < recentFxs.length; i++) {
      final fx = recentFxs[i];
      print('分型: ${fx.mark.label} ${fx.dt.toString().substring(0, 10)} '
          'fx=${fx.fx.toStringAsFixed(2)} 力度=${fx.powerStr}');
    }
  }

  // 7. 演示增量更新
  print('\n=== 增量更新演示 ===');
  final newBar = RawBar(
    symbol: 'DEMO',
    id: bars.length,
    dt: DateTime.now(),
    freq: Freq.d,
    open: 100,
    close: 102,
    high: 105,
    low: 98,
    vol: 1000,
  );
  czsc.update(newBar);
  print('添加新K线后，笔数量: ${czsc.biList.length}');
}

/// 生成模拟K线数据
List<RawBar> generateKlines(int count) {
  final bars = <RawBar>[];
  var price = 100.0;
  var trend = 1; // 1=上涨, -1=下跌
  var trendCount = 0;
  final random = _SimpleRandom(42);

  for (var i = 0; i < count; i++) {
    // 随机改变趋势
    trendCount++;
    if (trendCount > 10 + random.nextInt(20)) {
      trend = -trend;
      trendCount = 0;
    }

    // 计算价格变化
    final baseChange = trend * (0.5 + random.nextDouble() * 2);
    final noise = (random.nextDouble() - 0.5) * 1;
    final change = baseChange + noise;

    final open = price;
    final close = price + change;
    final high = (open > close ? open : close) + random.nextDouble() * 1.5;
    final low = (open < close ? open : close) - random.nextDouble() * 1.5;

    bars.add(RawBar(
      symbol: 'DEMO',
      id: i,
      dt: DateTime(2024, 1, 1).add(Duration(days: i)),
      freq: Freq.d,
      open: double.parse(open.toStringAsFixed(2)),
      close: double.parse(close.toStringAsFixed(2)),
      high: double.parse(high.toStringAsFixed(2)),
      low: double.parse(low.toStringAsFixed(2)),
      vol: 1000.0 + random.nextInt(500),
      amount: 10000.0 + random.nextInt(5000),
    ));

    price = close;
  }

  return bars;
}

/// 简单随机数生成器
class _SimpleRandom {
  int _seed;
  _SimpleRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed / 0x7FFFFFFF;
  }

  int nextInt(int max) {
    return (nextDouble() * max).floor();
  }
}
