# czsc_dart

缠中说禅技术分析工具 - Dart版本

从 Python 版本的 [czsc](https://github.com/waditu/czsc) 移植，支持K线分型、笔、中枢识别。

## 功能特性

- ✅ K线包含关系处理
- ✅ 分型识别（顶分型、底分型）
- ✅ 笔识别
- ✅ 中枢识别
- ✅ 增量更新支持

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  czsc_dart:
    path: ./czsc_dart
```

## 快速开始

```dart
import 'package:czsc_dart/czsc_dart.dart';

void main() {
  // 1. 准备K线数据
  final bars = [
    RawBar(
      symbol: 'AAPL',
      id: 0,
      dt: DateTime(2024, 1, 1),
      freq: Freq.d,
      open: 100, close: 102, high: 105, low: 98, vol: 1000,
    ),
    // ... 更多K线数据
  ];

  // 2. 创建分析器
  final czsc = CZSC(bars: bars);

  // 3. 获取分析结果
  print('笔数量: ${czsc.biList.length}');
  print('中枢数量: ${czsc.zsList.length}');

  // 4. 遍历中枢
  for (final zs in czsc.zsList) {
    print('中枢: ${zs.sdt} -> ${zs.edt}');
    print('  上沿: ${zs.zg}, 下沿: ${zs.zd}');
    print('  笔数: ${zs.biCount}');
  }
}
```

## 核心类说明

### RawBar - 原始K线

```dart
final bar = RawBar(
  symbol: 'AAPL',      // 交易标的代码
  id: 0,               // K线序号（升序）
  dt: DateTime.now(),  // 时间
  freq: Freq.d,        // 周期
  open: 100,           // 开盘价
  close: 102,          // 收盘价
  high: 105,           // 最高价
  low: 98,             // 最低价
  vol: 1000,           // 成交量
);
```

### CZSC - 缠论分析器

```dart
final czsc = CZSC(bars: bars);

// 属性
czsc.barsRaw      // 原始K线列表
czsc.biList       // 笔列表
czsc.zsList       // 有效中枢列表
czsc.fxList       // 分型列表

// 方法
czsc.update(bar)  // 增量更新
```

### ZS - 中枢

```dart
final zs = czsc.zsList.first;

zs.sdt       // 起始时间
zs.edt       // 结束时间
zs.zg        // 上沿（前3笔最小高点）
zs.zd        // 下沿（前3笔最大低点）
zs.zz        // 中轴
zs.gg        // 最高点
zs.dd        // 最低点
zs.biCount   // 笔数
zs.isValid   // 是否有效
zs.height    // 高度
```

### BI - 笔

```dart
final bi = czsc.biList.first;

bi.sdt        // 起始时间
bi.edt        // 结束时间
bi.direction  // 方向 (Direction.up / Direction.down)
bi.high       // 最高价
bi.low        // 最低价
bi.length     // K线数量
```

### FX - 分型

```dart
final fx = czsc.fxList.first;

fx.dt         // 时间
fx.mark       // 类型 (Mark.g=顶分型, Mark.d=底分型)
fx.high       // 最高价
fx.low        // 最低价
fx.fx         // 分型值
fx.powerStr   // 力度描述（强/中/弱）
```

## 配置选项

```dart
// 设置最小笔长度（默认4）
CzscConfig.minBiLen = 5;

// 设置最大保留笔数量（默认100）
CzscConfig.maxBiNum = 200;

// 开启详细日志
CzscConfig.verbose = true;
```

## 独立使用中枢识别

如果你已经有笔数据，可以单独使用中枢识别功能：

```dart
import 'package:czsc_dart/czsc_dart.dart';

// 假设你已经有笔列表
List<BI> bis = [...];

// 获取所有中枢
final allZs = getZsSeq(bis);

// 获取有效中枢（笔数>=3 且 zg >= zd）
final validZs = getValidZsSeq(bis);
```

## 与 Flutter 集成

在 Flutter 中绘制中枢：

```dart
import 'package:flutter/material.dart';
import 'package:czsc_dart/czsc_dart.dart';

class ZsPainter extends CustomPainter {
  final List<ZS> zsList;
  final double Function(DateTime) xFromDt;
  final double Function(double) yFromPrice;

  ZsPainter({
    required this.zsList,
    required this.xFromDt,
    required this.yFromPrice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final zs in zsList) {
      final left = xFromDt(zs.sdt);
      final right = xFromDt(zs.edt);
      final top = yFromPrice(zs.zg);
      final bottom = yFromPrice(zs.zd);

      final rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

## 文件结构

```
czsc_dart/
├── lib/
│   ├── czsc_dart.dart      # 库入口
│   └── src/
│       ├── enum.dart       # 枚举定义
│       ├── objects.dart    # 数据结构
│       ├── analyze.dart    # 分析算法
│       └── czsc.dart       # 主类
├── test/
│   └── czsc_test.dart      # 单元测试
├── example/
│   └── example.dart        # 使用示例
└── pubspec.yaml
```

## 与 Python 版本的差异

1. **类型安全**：Dart 是强类型语言，所有数据结构都有明确的类型定义
2. **不可变性**：部分数据结构设计为不可变，更安全
3. **简化依赖**：不依赖 pandas、numpy 等外部库

## License

Apache-2.0
