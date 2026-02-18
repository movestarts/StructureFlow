import 'dart:io';
import 'dart:convert';
import 'package:czsc_dart/czsc_dart.dart';

void main() async {
  print('=== 用 Python 笔数据测试 Dart 中枢识别 ===\n');

  // 读取 Python 导出的笔数据
  final biFile = File('../python_bis.json');
  if (!await biFile.exists()) {
    print('错误: 找不到 python_bis.json');
    exit(1);
  }

  final biJson = jsonDecode(await biFile.readAsString()) as List;
  print('读取到 ${biJson.length} 笔数据');

  // 转换为 Dart BI 对象
  final bis = <BI>[];
  for (final item in biJson) {
    final bi = BI(
      symbol: 'RB',
      fxA: FX(
        symbol: 'RB',
        dt: DateTime.parse(item['sdt']),
        mark: item['direction'] == 'up' ? Mark.d : Mark.g,
        high: item['high'],
        low: item['low'],
        fx: item['direction'] == 'up' ? item['low'] : item['high'],
        elements: [],
      ),
      fxB: FX(
        symbol: 'RB',
        dt: DateTime.parse(item['edt']),
        mark: item['direction'] == 'up' ? Mark.g : Mark.d,
        high: item['high'],
        low: item['low'],
        fx: item['direction'] == 'up' ? item['high'] : item['low'],
        elements: [],
      ),
      direction: item['direction'] == 'up' ? Direction.up : Direction.down,
      fxs: [],
      bars: [],
    );
    bis.add(bi);
  }

  print('Dart 笔数量: ${bis.length}');

  // 用 Dart 的中枢识别
  final zsList = getValidZsSeq(bis);
  print('Dart 有效中枢数量: ${zsList.length}');

  print('\nDart 中枢详情:');
  for (var i = 0; i < zsList.length; i++) {
    final zs = zsList[i];
    print('中枢 ${i + 1}: 笔数=${zs.biCount}, zg=${zs.zg.toStringAsFixed(2)}, zd=${zs.zd.toStringAsFixed(2)}');
    print('  时间: ${zs.sdt} -> ${zs.edt}');
  }

  // 读取 Python 中枢数据进行对比
  final zsFile = File('../python_zs.json');
  if (await zsFile.exists()) {
    final zsJson = jsonDecode(await zsFile.readAsString()) as List;
    print('\n=== 对比结果 ===');
    print('Python 中枢数量: ${zsJson.length}');
    print('Dart 中枢数量: ${zsList.length}');

    if (zsJson.length == zsList.length) {
      var allMatch = true;
      for (var i = 0; i < zsJson.length; i++) {
        final pyZs = zsJson[i];
        final dartZs = zsList[i];

        final zgMatch = (pyZs['zg'] as num).toDouble() == dartZs.zg;
        final zdMatch = (pyZs['zd'] as num).toDouble() == dartZs.zd;
        final countMatch = pyZs['bi_count'] == dartZs.biCount;

        if (!zgMatch || !zdMatch || !countMatch) {
          print('中枢 ${i + 1} 不匹配:');
          print('  Python: zg=${pyZs['zg']}, zd=${pyZs['zd']}, bi_count=${pyZs['bi_count']}');
          print('  Dart: zg=${dartZs.zg}, zd=${dartZs.zd}, bi_count=${dartZs.biCount}');
          allMatch = false;
        }
      }

      if (allMatch) {
        print('\n✅ 所有中枢数据完全匹配！Dart 中枢识别逻辑正确！');
      }
    } else {
      print('中枢数量不一致！');
    }
  }
}
