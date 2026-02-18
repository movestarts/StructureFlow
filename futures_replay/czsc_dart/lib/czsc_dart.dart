/// 缠中说禅技术分析工具 - Dart版本
/// 
/// 支持K线分型、笔、中枢识别
/// 
/// 用法示例:
/// ```dart
/// import 'package:czsc_dart/czsc_dart.dart';
/// 
/// // 创建K线数据
/// final bars = [
///   RawBar(symbol: 'AAPL', id: 0, dt: DateTime(2024, 1, 1), freq: Freq.d,
///          open: 100, close: 102, high: 105, low: 98, vol: 1000),
///   // ... 更多K线
/// ];
/// 
/// // 创建分析器
/// final czsc = CZSC(bars: bars);
/// 
/// // 获取分析结果
/// print('笔数量: ${czsc.biList.length}');
/// print('中枢数量: ${czsc.zsList.length}');
/// ```
library;

export 'src/enum.dart';
export 'src/objects.dart';
export 'src/analyze.dart';
export 'src/czsc.dart';
