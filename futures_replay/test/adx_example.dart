/// ADX指标使用示例
/// 
/// 演示如何使用ADX指标进行趋势分析和交易信号识别

import '../lib/services/indicator_service.dart';
import '../lib/models/kline_model.dart';

void main() {
  // 示例1：基本使用
  print('=== 示例1: 基本使用 ===');
  basicUsageExample();
  
  print('\n=== 示例2: 趋势强度分析 ===');
  trendAnalysisExample();
  
  print('\n=== 示例3: 交易信号识别 ===');
  tradingSignalExample();
}

/// 示例1: 基本使用
void basicUsageExample() {
  final indicatorService = IndicatorService();
  
  // 创建模拟K线数据
  final klines = generateMockKlines(50);
  
  // 计算ADX（默认周期14）
  final result = indicatorService.calculateADX(klines);
  
  // 打印最新的值
  final lastIndex = klines.length - 1;
  final adx = result.adx[lastIndex];
  final pdi = result.pdi[lastIndex];
  final mdi = result.mdi[lastIndex];
  
  if (adx != null) {
    print('ADX: ${adx.toStringAsFixed(2)}');
    print('+DI: ${pdi?.toStringAsFixed(2)}');
    print('-DI: ${mdi?.toStringAsFixed(2)}');
  } else {
    print('数据不足，需要至少28根K线');
  }
}

/// 示例2: 趋势强度分析
void trendAnalysisExample() {
  final indicatorService = IndicatorService();
  final klines = generateMockKlines(50);
  final result = indicatorService.calculateADX(klines);
  
  final index = klines.length - 1;
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
  
  print('当前ADX: ${adx.toStringAsFixed(2)} - $trendStrength');
  print('趋势方向: $direction');
  print('+DI: ${pdi.toStringAsFixed(2)}');
  print('-DI: ${mdi.toStringAsFixed(2)}');
  
  // 给出建议
  if (adx > 25) {
    if (pdi > mdi) {
      print('建议: 强势上涨，可以持多或加仓');
    } else {
      print('建议: 强势下跌，可以持空或观望');
    }
  } else {
    print('建议: 震荡行情，适合区间操作或观望');
  }
}

/// 示例3: 交易信号识别
void tradingSignalExample() {
  final indicatorService = IndicatorService();
  final klines = generateMockKlines(50);
  final result = indicatorService.calculateADX(klines);
  
  // 检查最近的交易信号
  for (int i = 28; i < klines.length; i++) {
    if (checkBuySignal(result, i)) {
      print('K线 $i: 买入信号 🟢');
      print('  ADX: ${result.adx[i]?.toStringAsFixed(2)}');
      print('  +DI: ${result.pdi[i]?.toStringAsFixed(2)}');
      print('  -DI: ${result.mdi[i]?.toStringAsFixed(2)}');
    }
    
    if (checkSellSignal(result, i)) {
      print('K线 $i: 卖出信号 🔴');
      print('  ADX: ${result.adx[i]?.toStringAsFixed(2)}');
      print('  +DI: ${result.pdi[i]?.toStringAsFixed(2)}');
      print('  -DI: ${result.mdi[i]?.toStringAsFixed(2)}');
    }
  }
}

/// 检查买入信号
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

/// 检查卖出信号
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

/// 生成模拟K线数据（用于测试）
List<KlineModel> generateMockKlines(int count) {
  final List<KlineModel> klines = [];
  double price = 3000.0;
  final baseTime = DateTime(2024, 1, 1, 9, 0);
  
  for (int i = 0; i < count; i++) {
    // 模拟价格波动
    final change = (i % 10 - 5) * 5.0; // 简单的波动模式
    price += change;
    
    final open = price;
    final high = price + 10;
    final low = price - 10;
    final close = price + (i % 3 == 0 ? 5 : -5);
    
    klines.add(KlineModel(
      time: baseTime.add(Duration(minutes: i * 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 1000 + i * 10,
    ));
    
    price = close;
  }
  
  return klines;
}
