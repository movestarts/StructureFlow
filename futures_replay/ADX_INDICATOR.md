# ADX (Average Directional Index) 指标实现

## 📊 指标说明

ADX（平均趋向指数）是由 J. Welles Wilder Jr. 开发的技术指标，用于衡量趋势的强度，而不是方向。

### 三条线的含义

- **ADX**：趋势强度指标（0-100）
  - < 20：弱趋势或无趋势
  - 20-40：强趋势
  - \> 40：非常强的趋势

- **+DI (PDI)**：正向趋向指标
  - 衡量上升趋势的强度

- **-DI (MDI)**：负向趋向指标
  - 衡量下降趋势的强度

### 交易信号

1. **趋势确认**
   - ADX > 25：趋势强劲
   - ADX < 20：震荡行情

2. **方向判断**
   - +DI > -DI：上升趋势
   - -DI > +DI：下降趋势

3. **买入信号**
   - +DI 上穿 -DI，且 ADX > 20

4. **卖出信号**
   - -DI 上穿 +DI，且 ADX > 20

## 🛠️ 使用方法

### 1. 基本使用

```dart
import 'package:futures_replay/services/indicator_service.dart';
import 'package:futures_replay/models/kline_model.dart';

void example() {
  final indicatorService = IndicatorService();
  
  // 准备K线数据
  List<KlineModel> klines = [...];
  
  // 计算ADX，使用默认周期14
  ADXResult result = indicatorService.calculateADX(klines);
  
  // 获取三条线的数据
  List<double?> adxValues = result.adx;   // ADX线
  List<double?> pdiValues = result.pdi;   // +DI线
  List<double?> mdiValues = result.mdi;   // -DI线
  
  // 使用最新的值
  final latestADX = adxValues.last;
  final latestPDI = pdiValues.last;
  final latestMDI = mdiValues.last;
  
  if (latestADX != null) {
    print('ADX: ${latestADX.toStringAsFixed(2)}');
    print('+DI: ${latestPDI?.toStringAsFixed(2)}');
    print('-DI: ${latestMDI?.toStringAsFixed(2)}');
  }
}
```

### 2. 自定义周期

```dart
// 使用周期20
ADXResult result = indicatorService.calculateADX(klines, period: 20);

// 常用周期
// 短期：7-10
// 标准：14（默认）
// 长期：20-25
```

### 3. 判断趋势强度

```dart
void analyzeTrend(ADXResult result, int index) {
  final adx = result.adx[index];
  final pdi = result.pdi[index];
  final mdi = result.mdi[index];
  
  if (adx == null || pdi == null || mdi == null) {
    print('数据不足');
    return;
  }
  
  // 判断趋势强度
  String trendStrength;
  if (adx < 20) {
    trendStrength = '弱趋势/震荡';
  } else if (adx < 40) {
    trendStrength = '强趋势';
  } else {
    trendStrength = '非常强的趋势';
  }
  
  // 判断趋势方向
  String direction = pdi > mdi ? '上升' : '下降';
  
  print('ADX: ${adx.toStringAsFixed(2)} - $trendStrength');
  print('趋势方向: $direction');
  print('+DI: ${pdi.toStringAsFixed(2)}');
  print('-DI: ${mdi.toStringAsFixed(2)}');
}
```

### 4. 交易信号识别

```dart
bool checkBuySignal(ADXResult result, int index) {
  if (index < 1) return false;
  
  final adxCurrent = result.adx[index];
  final pdiCurrent = result.pdi[index];
  final mdiCurrent = result.mdi[index];
  final pdiPrev = result.pdi[index - 1];
  final mdiPrev = result.mdi[index - 1];
  
  if (adxCurrent == null || pdiCurrent == null || mdiCurrent == null ||
      pdiPrev == null || mdiPrev == null) {
    return false;
  }
  
  // 买入信号：+DI上穿-DI，且ADX>20
  bool diCrossover = pdiPrev <= mdiPrev && pdiCurrent > mdiCurrent;
  bool strongTrend = adxCurrent > 20;
  
  return diCrossover && strongTrend;
}

bool checkSellSignal(ADXResult result, int index) {
  if (index < 1) return false;
  
  final adxCurrent = result.adx[index];
  final pdiCurrent = result.pdi[index];
  final mdiCurrent = result.mdi[index];
  final pdiPrev = result.pdi[index - 1];
  final mdiPrev = result.mdi[index - 1];
  
  if (adxCurrent == null || pdiCurrent == null || mdiCurrent == null ||
      pdiPrev == null || mdiPrev == null) {
    return false;
  }
  
  // 卖出信号：-DI上穿+DI，且ADX>20
  bool diCrossover = mdiPrev <= pdiPrev && mdiCurrent > pdiCurrent;
  bool strongTrend = adxCurrent > 20;
  
  return diCrossover && strongTrend;
}
```

## 📐 计算逻辑

### 标准威尔德平滑算法

ADX使用威尔德平滑（Wilder's Smoothing），这是一种特殊的移动平均：

```
第一个平滑值 = 前N个值的简单平均
后续平滑值 = (前一个平滑值 × (N-1) + 当前值) / N
```

### 详细计算步骤

#### 1. 计算TR (True Range)

```
TR = max(
  high - low,
  abs(high - previous_close),
  abs(low - previous_close)
)
```

#### 2. 计算+DM和-DM

```
upMove = high - previous_high
downMove = previous_low - low

if (upMove > downMove && upMove > 0):
    +DM = upMove
else:
    +DM = 0

if (downMove > upMove && downMove > 0):
    -DM = downMove
else:
    -DM = 0
```

#### 3. 威尔德平滑TR、+DM、-DM

```
smoothedTR[N] = average(TR[1] to TR[N])
smoothedTR[i] = (smoothedTR[i-1] × (N-1) + TR[i]) / N

同样处理 +DM 和 -DM
```

#### 4. 计算+DI和-DI

```
+DI = (smoothed_+DM / smoothed_TR) × 100
-DI = (smoothed_-DM / smoothed_TR) × 100
```

#### 5. 计算DX

```
DX = abs(+DI - -DI) / (+DI + -DI) × 100
```

#### 6. 计算ADX

```
ADX[2N-1] = average(DX[N] to DX[2N-1])
ADX[i] = (ADX[i-1] × (N-1) + DX[i]) / N
```

## 🎨 在副图中绘制

### 集成到SubChartPainter

```dart
// sub_chart_painter.dart 中添加ADX绘制函数

CustomPainter createADXPainter({
  required ADXResult adxData,
  required ChartViewController viewController,
  required int dataLength,
}) {
  return _ADXPainter(
    adxData: adxData,
    viewController: viewController,
    dataLength: dataLength,
  );
}

class _ADXPainter extends CustomPainter {
  final ADXResult adxData;
  final ChartViewController viewController;
  final int dataLength;

  _ADXPainter({
    required this.adxData,
    required this.viewController,
    required this.dataLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (adxData.adx.isEmpty) return;

    final startIdx = viewController.visibleStartIndex.clamp(0, dataLength);
    final endIdx = viewController.visibleEndIndex.clamp(0, dataLength);
    
    // 找出可见范围内的最大最小值
    double maxValue = 0;
    for (int i = startIdx; i < endIdx && i < adxData.adx.length; i++) {
      if (adxData.adx[i] != null && adxData.adx[i]! > maxValue) {
        maxValue = adxData.adx[i]!;
      }
      if (adxData.pdi[i] != null && adxData.pdi[i]! > maxValue) {
        maxValue = adxData.pdi[i]!;
      }
      if (adxData.mdi[i] != null && adxData.mdi[i]! > maxValue) {
        maxValue = adxData.mdi[i]!;
      }
    }
    
    // 设置上限为100或稍高于最大值
    maxValue = maxValue > 100 ? maxValue * 1.1 : 100;

    // 绘制三条线
    _drawLine(canvas, size, adxData.adx, startIdx, endIdx, 
              Colors.blue, maxValue); // ADX - 蓝色
    _drawLine(canvas, size, adxData.pdi, startIdx, endIdx, 
              Colors.green, maxValue); // +DI - 绿色
    _drawLine(canvas, size, adxData.mdi, startIdx, endIdx, 
              Colors.red, maxValue); // -DI - 红色

    // 绘制参考线 (20, 40)
    _drawReferenceLine(canvas, size, 20, maxValue, Colors.grey.withOpacity(0.3));
    _drawReferenceLine(canvas, size, 40, maxValue, Colors.grey.withOpacity(0.3));
  }

  void _drawLine(Canvas canvas, Size size, List<double?> values,
      int startIdx, int endIdx, Color color, double maxValue) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;
    final step = viewController.step;

    for (int i = 0; i < endIdx - startIdx; i++) {
      final dataIdx = startIdx + i;
      if (dataIdx >= values.length) break;

      final value = values[dataIdx];
      if (value == null) continue;

      final x = i * step + step / 2;
      final y = size.height - (value / maxValue * size.height);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (started) {
      canvas.drawPath(path, paint);
    }
  }

  void _drawReferenceLine(Canvas canvas, Size size, double value, 
      double maxValue, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final y = size.height - (value / maxValue * size.height);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

## 📊 返回值格式

```dart
class ADXResult {
  /// ADX值列表（0-100+）
  final List<double?> adx;
  
  /// +DI值列表（0-100）
  final List<double?> pdi;
  
  /// -DI值列表（0-100）
  final List<double?> mdi;
}
```

### 数据长度

- 前 `period` 个值为 `null`（+DI和-DI）
- 前 `period * 2 - 1` 个值为 `null`（ADX）
- 例如：period=14时
  - 前14个 +DI/-DI 为 null
  - 前27个 ADX 为 null

## ⚙️ 参数说明

### period (周期)

| 周期 | 适用场景 | 特点 |
|-----|---------|------|
| 7-10 | 短期交易 | 反应快，噪音多 |
| 14 | 标准（默认） | 平衡性好 |
| 20-25 | 长期交易 | 平滑，滞后 |

### 威尔德平滑特点

- 比简单移动平均更平滑
- 给予历史数据更多权重
- 计算公式：`smoothed = (previous × (N-1) + current) / N`

## 🎯 实战应用

### 1. 趋势跟随策略

```dart
void trendFollowingStrategy(ADXResult result, int index) {
  final adx = result.adx[index];
  final pdi = result.pdi[index];
  final mdi = result.mdi[index];
  
  if (adx == null || pdi == null || mdi == null) return;
  
  if (adx > 25) {
    if (pdi > mdi) {
      print('强势上涨 - 持多或加仓');
    } else {
      print('强势下跌 - 持空或加空');
    }
  } else {
    print('震荡行情 - 观望或区间操作');
  }
}
```

### 2. 背离识别

```dart
bool checkBearishDivergence(List<KlineModel> klines, ADXResult result, int index) {
  if (index < 20) return false;
  
  // 价格创新高
  bool priceNewHigh = klines[index].high > klines[index - 10].high;
  
  // ADX或+DI走低
  final adxCurrent = result.adx[index];
  final adxPrev = result.adx[index - 10];
  bool adxWeakening = adxCurrent != null && adxPrev != null && 
                      adxCurrent < adxPrev;
  
  return priceNewHigh && adxWeakening;
}
```

### 3. 突破确认

```dart
bool confirmBreakout(ADXResult result, int index, double breakoutPrice, double currentPrice) {
  final adx = result.adx[index];
  final pdi = result.pdi[index];
  final mdi = result.mdi[index];
  
  if (adx == null || pdi == null || mdi == null) return false;
  
  bool priceBreakout = currentPrice > breakoutPrice;
  bool strongTrend = adx > 25;
  bool bullishDI = pdi > mdi;
  bool diExpanding = (pdi - mdi) > 5; // DI差值扩大
  
  return priceBreakout && strongTrend && bullishDI && diExpanding;
}
```

## 📈 性能考虑

### 计算复杂度

- 时间复杂度：O(n)
- 空间复杂度：O(n)
- 每根K线只需计算一次

### 优化建议

```dart
// 增量更新（如果支持）
ADXResult _cachedADX = ...;

void updateADX(KlineModel newBar) {
  // 只计算最新的值，而不是重新计算所有
  // 需要保存中间状态（smoothed values）
}
```

## ⚠️ 注意事项

1. **数据要求**
   - 最少需要 `period × 2` 根K线才能得到第一个ADX值
   - 周期14需要至少28根K线

2. **滞后性**
   - ADX是滞后指标，确认趋势而非预测
   - 不适合震荡市场

3. **结合使用**
   - 建议与其他指标配合（如均线、MACD）
   - 用于过滤信号，提高准确率

4. **参数调整**
   - 不同市场和周期需要调整参数
   - 建议通过回测优化

---

**实现时间**：2026-02-17  
**作者**：AI Assistant  
**版本**：1.0.0
