import 'dart:io';
import 'dart:convert';
import 'package:czsc_dart/czsc_dart.dart';

void main() async {
  print('=== Dart czsc_dart 分析 RB.csv ===\n');

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
  print('时间范围: ${bars.first.dt} ~ ${bars.last.dt}');

  // 取最近 2000 条数据
  final recentBars = bars.length > 2000 ? bars.sublist(bars.length - 2000) : bars;
  print('使用最近 ${recentBars.length} 条数据进行分析...\n');

  // 创建 CZSC 分析器
  final czsc = CZSC(bars: recentBars);

  // 输出分析结果
  print('=== Dart czsc_dart 分析结果 ===');
  print('笔数量: ${czsc.biList.length}');

  // 输出笔详情
  print('\n=== 所有笔详情 ===');
  for (var i = 0; i < czsc.biList.length; i++) {
    final bi = czsc.biList[i];
    print('笔 ${i + 1}: ${bi.direction.label} ${bi.sdt} -> ${bi.edt}, high=${bi.high.toStringAsFixed(2)}, low=${bi.low.toStringAsFixed(2)}');
  }

  // 输出中枢详情
  print('\n=== 中枢详情 ===');
  print('有效中枢数量: ${czsc.zsList.length}');
  for (var i = 0; i < czsc.zsList.length; i++) {
    final zs = czsc.zsList[i];
    print('\n中枢 ${i + 1}:');
    print('  起始时间: ${zs.sdt}');
    print('  结束时间: ${zs.edt}');
    print('  上沿: ${zs.zg.toStringAsFixed(2)}');
    print('  下沿: ${zs.zd.toStringAsFixed(2)}');
    print('  中轴: ${zs.zz.toStringAsFixed(2)}');
    print('  笔数: ${zs.biCount}');
  }

  // 获取所有中枢（包括无效的）
  final allZs = getZsSeq(czsc.biList);
  print('\n=== 所有中枢（包括无效） ===');
  print('原始中枢数量: ${allZs.length}');
  for (var i = 0; i < allZs.length; i++) {
    final zs = allZs[i];
    print('中枢 ${i + 1}: 笔数=${zs.biCount}, zg=${zs.zg.toStringAsFixed(2)}, zd=${zs.zd.toStringAsFixed(2)}');
  }

  // 输出 JSON 结果供对比
  final result = {
    'bi_count': czsc.biList.length,
    'zs_count': czsc.zsList.length,
    'bis': czsc.biList.map((bi) => {
      'sdt': bi.sdt.toIso8601String(),
      'edt': bi.edt.toIso8601String(),
      'direction': bi.direction == Direction.up ? 'up' : 'down',
      'high': bi.high,
      'low': bi.low,
    }).toList(),
    'zs': czsc.zsList.map((zs) => {
      'sdt': zs.sdt.toIso8601String(),
      'edt': zs.edt.toIso8601String(),
      'zg': zs.zg,
      'zd': zs.zd,
      'zz': zs.zz,
      'bi_count': zs.biCount,
    }).toList(),
  };

  final outputFile = File('dart_result.json');
  await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  print('\n结果已保存到 dart_result.json');
}
