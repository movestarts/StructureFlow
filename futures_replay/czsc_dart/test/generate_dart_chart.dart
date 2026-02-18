import 'dart:io';
import 'dart:convert';
import 'package:czsc_dart/czsc_dart.dart';

void main() async {
  print('=== Dart czsc_dart 生成中枢图表 ===\n');

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

  // 用 Dart 的中枢识别
  final zsList = getValidZsSeq(bis);
  print('Dart 有效中枢数量: ${zsList.length}');

  // 读取原始 K 线数据
  final klineFile = File('../RB.csv');
  if (!await klineFile.exists()) {
    print('错误: 找不到 RB.csv');
    exit(1);
  }

  final klineLines = await klineFile.readAsLines();
  final klineData = <Map<String, dynamic>>[];
  
  for (var i = 1; i < klineLines.length; i++) {
    final parts = klineLines[i].split(',');
    if (parts.length < 6) continue;
    
    try {
      klineData.add({
        'dt': parts[0].trim(),
        'open': double.parse(parts[1].trim()),
        'high': double.parse(parts[2].trim()),
        'low': double.parse(parts[3].trim()),
        'close': double.parse(parts[4].trim()),
        'vol': double.parse(parts[5].trim()),
      });
    } catch (e) {}
  }

  print('读取到 ${klineData.length} 条 K 线数据');

  // 取最近 2000 条
  final recentKlines = klineData.length > 2000 
      ? klineData.sublist(klineData.length - 2000) 
      : klineData;

  // 生成 HTML 图表
  final html = _generateHtml(recentKlines, bis, zsList);
  
  final outputFile = File('../rb_dart_zs_chart.html');
  await outputFile.writeAsString(html);
  print('\n✅ 图表已保存到 rb_dart_zs_chart.html');
}

String _generateHtml(
  List<Map<String, dynamic>> klines,
  List<BI> bis,
  List<ZS> zsList,
) {
  final xData = klines.map((k) => "'${k['dt']}'").join(', ');
  final yData = klines.map((k) => '[${k['open']}, ${k['close']}, ${k['low']}, ${k['high']}]').join(', ');

  // 时间到索引的映射
  final dtToIdx = <String, int>{};
  for (var i = 0; i < klines.length; i++) {
    dtToIdx[klines[i]['dt']] = i;
  }

  // 生成中枢数据
  final zsJsCode = <String>[];
  for (var i = 0; i < zsList.length; i++) {
    final zs = zsList[i];
    
    // 找到最近的匹配时间
    int? startIdx = _findClosestIndex(dtToIdx, zs.sdt);
    int? endIdx = _findClosestIndex(dtToIdx, zs.edt);
    
    if (startIdx == null || endIdx == null) {
      print('警告: 中枢 ${i + 1} 时间匹配失败: ${zs.sdt} -> ${zs.edt}');
      continue;
    }
    
    final actualEnd = endIdx > klines.length - 1 ? klines.length - 1 : endIdx;
    
    zsJsCode.add('''
    option.series.push({
      name: '中枢${i + 1}',
      type: 'line',
      data: [
        [$startIdx, ${zs.zd}],
        [$actualEnd, ${zs.zd}],
        [$actualEnd, ${zs.zg}],
        [$startIdx, ${zs.zg}],
        [$startIdx, ${zs.zd}]
      ],
      lineStyle: { width: 2, color: '#FFD700' },
      areaStyle: { opacity: 0.3, color: '#FFD700' },
      symbol: 'none'
    });
''');
  }

  // 生成笔数据
  final biJsCode = <String>[];
  for (final bi in bis) {
    int? startIdx = _findClosestIndex(dtToIdx, bi.sdt);
    int? endIdx = _findClosestIndex(dtToIdx, bi.edt);
    
    if (startIdx == null || endIdx == null) {
      continue;
    }
    
    // 起点和终点
    if (bi.direction == Direction.up) {
      biJsCode.add("[$startIdx, ${bi.low}]");
      biJsCode.add("[$endIdx, ${bi.high}]");
    } else {
      biJsCode.add("[$startIdx, ${bi.high}]");
      biJsCode.add("[$endIdx, ${bi.low}]");
    }
  }

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>RB 螺纹钢 缠论分析 - Dart 版本</title>
  <script src="https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"></script>
  <style>
    body { margin: 0; background: #1f212d; }
    #chart { width: 1600px; height: 800px; margin: 0 auto; }
    h1 { color: #fff; text-align: center; font-family: sans-serif; }
    .info { color: #aaa; text-align: center; font-family: sans-serif; margin: 10px; }
  </style>
</head>
<body>
  <h1>RB 螺纹钢 缠论分析 - Dart 版本</h1>
  <div class="info">🟡 黄色区域 = 中枢 | 🔵 蓝色连线 = 笔 | 共 ${zsList.length} 个中枢</div>
  <div id="chart"></div>
  <script>
    const chart = echarts.init(document.getElementById('chart'));
    
    const xData = [$xData];
    const yData = [$yData];
    
    const option = {
      backgroundColor: '#1f212d',
      title: { text: 'Dart czsc_dart 中枢识别', left: 'center', top: 10, textStyle: { color: '#fff' } },
      tooltip: { trigger: 'axis', axisPointer: { type: 'cross' } },
      legend: { data: ['K线', '笔'], top: 40, textStyle: { color: '#fff' } },
      grid: { left: '10%', right: '10%', top: 80, bottom: 100 },
      xAxis: { type: 'category', data: xData, scale: true, axisLine: { lineStyle: { color: '#ccc' } } },
      yAxis: { type: 'value', scale: true, splitArea: { show: true }, axisLine: { lineStyle: { color: '#ccc' } } },
      dataZoom: [
        { type: 'slider', start: 30, end: 100, bottom: 30 },
        { type: 'inside', start: 30, end: 100 }
      ],
      series: [
        {
          name: 'K线',
          type: 'candlestick',
          data: yData,
          itemStyle: {
            color: '#F9293E',
            color0: '#00aa3b',
            borderColor: '#F9293E',
            borderColor0: '#00aa3b'
          }
        },
        {
          name: '笔',
          type: 'line',
          data: [${biJsCode.join(', ')}],
          symbol: 'circle',
          symbolSize: 6,
          lineStyle: { width: 2, color: '#00BFFF' },
          itemStyle: { color: '#00BFFF' }
        }
      ]
    };
    
    // 添加中枢
    ${zsJsCode.join('\n    ')}
    
    chart.setOption(option);
  </script>
</body>
</html>
''';
}

int? _findClosestIndex(Map<String, int> dtToIdx, DateTime target) {
  // 尝试精确匹配
  final targetStr = target.toIso8601String();
  
  // 尝试不同格式
  final formats = [
    targetStr.substring(0, 19),  // 2025-11-05T14:55:00
    targetStr.substring(0, 19).replaceAll('T', ' '),  // 2025-11-05 14:55:00
  ];
  
  for (final fmt in formats) {
    if (dtToIdx.containsKey(fmt)) {
      return dtToIdx[fmt];
    }
  }
  
  // 模糊匹配：找最接近的时间
  final targetTime = target.millisecondsSinceEpoch;
  int? closestIdx;
  int minDiff = 0x7FFFFFFFFFFFFFFF;  // Max int64
  
  for (final entry in dtToIdx.entries) {
    try {
      final entryTime = DateTime.parse(entry.key.replaceAll(' ', 'T')).millisecondsSinceEpoch;
      final diff = (entryTime - targetTime).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = entry.value;
      }
    } catch (e) {}
  }
  
  // 如果差距在 10 分钟内，返回匹配结果
  if (minDiff < 10 * 60 * 1000) {
    return closestIdx;
  }
  
  return null;
}
