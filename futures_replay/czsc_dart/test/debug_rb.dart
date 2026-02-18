import 'dart:io';
import 'dart:convert';
import 'package:czsc_dart/czsc_dart.dart';

void main() async {
  print('=== Dart czsc_dart 分析 RB.csv (调试模式) ===\n');

  // 读取 CSV 文件
  final file = File('../RB.csv');
  if (!await file.exists()) {
    print('错误: 找不到 RB.csv 文件');
    exit(1);
  }

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
    } catch (e) {
      // 跳过解析错误的行
    }
  }

  print('成功解析 ${bars.length} 条K线数据');

  // 取最近 200 条数据进行调试
  final recentBars = bars.length > 200 ? bars.sublist(bars.length - 200) : bars;
  print('使用最近 ${recentBars.length} 条数据进行调试...\n');

  // 手动测试去除包含关系
  print('=== 测试去除包含关系 ===');
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
  print('原始K线: ${recentBars.length}');
  print('去除包含后: ${barsUbi.length}');

  // 测试分型识别
  print('\n=== 测试分型识别 ===');
  final fxs = checkFxs(barsUbi);
  print('分型数量: ${fxs.length}');
  if (fxs.isNotEmpty) {
    print('前5个分型:');
    for (var i = 0; i < (fxs.length > 5 ? 5 : fxs.length); i++) {
      final fx = fxs[i];
      print('  分型${i+1}: ${fx.mark.label} ${fx.dt} fx=${fx.fx}');
    }
  }

  // 测试笔识别
  print('\n=== 测试笔识别 ===');
  if (fxs.length >= 2) {
    final result = checkBi(barsUbi);
    print('checkBi 返回: bi=${result.bi}, remainBars=${result.remainBars.length}');
    
    if (result.bi != null) {
      print('第一笔: ${result.bi!.direction.label} ${result.bi!.sdt} -> ${result.bi!.edt}');
    }
  }

  // 使用 CZSC 类
  print('\n=== 使用 CZSC 类 ===');
  final czsc = CZSC(bars: recentBars);
  print('笔数量: ${czsc.biList.length}');
  print('barsUbi 长度: ${czsc.barsUbi.length}');
  
  // 检查 barsUbi 中的分型
  final ubiFxs = checkFxs(czsc.barsUbi);
  print('barsUbi 中分型数量: ${ubiFxs.length}');
}
