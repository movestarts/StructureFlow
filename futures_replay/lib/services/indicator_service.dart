import '../models/kline_model.dart';

/// 技术指标计算服务
class IndicatorService {
  
  /// 计算简单移动平均线 (SMA)
  /// 返回与输入数据等长的列表，前period-1个值为null
  List<double?> calculateMA(List<KlineModel> data, int period) {
    List<double?> result = [];
    
    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.add(null);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += data[j].close;
        }
        result.add(sum / period);
      }
    }
    
    return result;
  }
  
  /// 计算MACD指标
  /// 返回 (DIF, DEA, MACD柱) 三个序列
  MACDResult calculateMACD(List<KlineModel> data, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    List<double?> dif = [];
    List<double?> dea = [];
    List<double?> macdBar = [];
    
    if (data.isEmpty) {
      return MACDResult(dif: dif, dea: dea, macdBar: macdBar);
    }
    
    // 计算EMA
    List<double> emaFast = _calculateEMA(data, fastPeriod);
    List<double> emaSlow = _calculateEMA(data, slowPeriod);
    
    // 计算DIF = EMA(fast) - EMA(slow)
    List<double> difValues = [];
    for (int i = 0; i < data.length; i++) {
      if (i < slowPeriod - 1) {
        dif.add(null);
        difValues.add(0);
      } else {
        double d = emaFast[i] - emaSlow[i];
        dif.add(d);
        difValues.add(d);
      }
    }
    
    // 计算DEA = EMA(DIF, signalPeriod)
    List<double> deaValues = _calculateEMAFromValues(difValues, signalPeriod, slowPeriod - 1);
    
    for (int i = 0; i < data.length; i++) {
      if (i < slowPeriod + signalPeriod - 2) {
        dea.add(null);
        macdBar.add(null);
      } else {
        dea.add(deaValues[i]);
        // MACD柱 = (DIF - DEA) * 2
        double bar = (difValues[i] - deaValues[i]) * 2;
        macdBar.add(bar);
      }
    }
    
    return MACDResult(dif: dif, dea: dea, macdBar: macdBar);
  }
  
  /// 计算EMA
  List<double> _calculateEMA(List<KlineModel> data, int period) {
    List<double> result = [];
    double multiplier = 2.0 / (period + 1);
    
    // 第一个EMA值使用SMA
    double sum = 0;
    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        sum += data[i].close;
        result.add(data[i].close); // 占位
      } else if (i == period - 1) {
        sum += data[i].close;
        result.add(sum / period); // 第一个EMA = SMA
      } else {
        double ema = (data[i].close - result[i - 1]) * multiplier + result[i - 1];
        result.add(ema);
      }
    }
    
    return result;
  }
  
  /// 从数值序列计算EMA
  List<double> _calculateEMAFromValues(List<double> values, int period, int startFrom) {
    List<double> result = List.filled(values.length, 0);
    double multiplier = 2.0 / (period + 1);
    
    // 计算初始SMA
    double sum = 0;
    int count = 0;
    for (int i = startFrom; i < values.length && count < period; i++) {
      sum += values[i];
      count++;
    }
    
    int firstEmaIndex = startFrom + period - 1;
    if (firstEmaIndex < values.length) {
      result[firstEmaIndex] = sum / period;
      
      for (int i = firstEmaIndex + 1; i < values.length; i++) {
        result[i] = (values[i] - result[i - 1]) * multiplier + result[i - 1];
      }
    }
    
    return result;
  }
}

/// MACD计算结果
class MACDResult {
  final List<double?> dif;
  final List<double?> dea;
  final List<double?> macdBar;
  
  MACDResult({required this.dif, required this.dea, required this.macdBar});
}
