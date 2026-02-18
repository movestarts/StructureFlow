import 'dart:io';
import 'dart:convert';
import 'package:czsc_dart/czsc_dart.dart';

void main() async {
  print('=== Dart czsc_dart 分析 RB.csv (详细调试) ===\n');

  // 读取 CSV 文件
  final file = File('../RB.csv');
  final lines = await file.readAsLines();
  print('读取到 ${lines.length - 1} 条数据');

  // 解析 CSV 数据
  final bars = <RawBar>[];
  for (var i = 1; i < lines.length; i++) {
    final parts = lines[i].split(',');
    if (parts.length < 6) continue;

    try {
      final bar = RawBar(
        symbol: parts[8].trim(),
        id: i - 1,
        dt: DateTime.parse(parts[0].trim()),
        freq: Freq.f5,
        open: double.parse(parts[1].trim()),
        high: double.parse(parts[2].trim()),
        low: double.parse(parts[3].trim()),
        close: double.parse(parts[4].trim()),
        vol: double.parse(parts[5].trim()),
        amount: parts.length > 6 ? double.tryParse(parts[6].trim()) ?? 0 : 0,
      );
      bars.add(bar);
    } catch (e) {}
  }

  print('成功解析 ${bars.length} 条K线数据');

  // 取最近 2000 条数据
  final recentBars = bars.length > 2000 ? bars.sublist(bars.length - 2000) : bars;
  print('使用最近 ${recentBars.length} 条数据进行分析...\n');

  // 手动测试笔识别
  print('=== 手动测试笔识别 ===');
  
  // 去除包含关系
  final barsUbi = <NewBar>[];
  for (final bar in recentBars) {
    if (barsUbi.length < 2) {
      barsUbi.add(NewBar(
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
      final k1 = barsUbi[barsUbi.length - 2];
      final k2 = barsUbi[barsUbi.length - 1];
      final result = removeInclude(k1, k2, bar);
      
      if (result.hasInclude) {
        barsUbi[barsUbi.length - 1] = result.newBar;
      } else {
        barsUbi.add(result.newBar);
      }
    }
  }
  print('去除包含后: ${barsUbi.length} 条');

  // 找分型
  var fxs = checkFxs(barsUbi);
  print('分型数量: ${fxs.length}');

  // 找第一个分型
  var fxA = fxs.first;
  final fxsA = fxs.where((x) => x.mark == fxA.mark);
  for (final fx in fxsA) {
    if ((fxA.mark == Mark.d && fx.low <= fxA.low) ||
        (fxA.mark == Mark.g && fx.high >= fxA.high)) {
      fxA = fx;
    }
  }
  print('第一个分型: ${fxA.mark.label} ${fxA.dt} fx=${fxA.fx}');

  // 移除 fxA 之前的 K 线
  var workBars = barsUbi.where((x) => !x.dt.isBefore(fxA.elements.first.dt)).toList();
  print('移除前段后剩余: ${workBars.length} 条');

  // 循环识别笔
  final biList = <BI>[];
  var iteration = 0;
  
  while (workBars.length >= 5 && iteration < 100) {
    iteration++;
    print('\n--- 迭代 $iteration ---');
    print('workBars 长度: ${workBars.length}');
    
    final currentFxs = checkFxs(workBars);
    print('当前分型数量: ${currentFxs.length}');
    
    if (currentFxs.length < 2) {
      print('分型不足，退出');
      break;
    }
    
    final result = checkBi(workBars);
    print('checkBi 结果: bi=${result.bi != null}, remainBars=${result.remainBars.length}');
    
    if (result.bi != null) {
      final bi = result.bi!;
      print('找到笔: ${bi.direction.label} ${bi.sdt} -> ${bi.edt}, high=${bi.high}, low=${bi.low}');
      biList.add(bi);
      workBars = result.remainBars;
    } else {
      print('未找到笔，退出');
      break;
    }
  }

  print('\n=== 最终结果 ===');
  print('找到 ${biList.length} 笔');
  
  // 输出中枢
  final zsList = getValidZsSeq(biList);
  print('有效中枢: ${zsList.length}');
}
