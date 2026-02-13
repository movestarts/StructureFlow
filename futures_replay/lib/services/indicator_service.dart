import '../models/kline_model.dart';

/// 技术指标计算服务
class IndicatorService {

  /// 计算简单移动平均线 (SMA)
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

  /// 计算成交量均线
  List<double?> calculateVolumeMA(List<KlineModel> data, int period) {
    List<double?> result = [];

    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.add(null);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += data[j].volume;
        }
        result.add(sum / period);
      }
    }

    return result;
  }

  /// 计算布林带 (BOLL)
  BOLLResult calculateBOLL(List<KlineModel> data, {int period = 20, double multiplier = 2.0}) {
    List<double?> upper = [];
    List<double?> middle = [];
    List<double?> lower = [];

    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        upper.add(null);
        middle.add(null);
        lower.add(null);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += data[j].close;
        }
        double ma = sum / period;

        double variance = 0;
        for (int j = i - period + 1; j <= i; j++) {
          double diff = data[j].close - ma;
          variance += diff * diff;
        }
        double stddev = _sqrt(variance / period);

        upper.add(ma + multiplier * stddev);
        middle.add(ma);
        lower.add(ma - multiplier * stddev);
      }
    }

    return BOLLResult(upper: upper, middle: middle, lower: lower);
  }

  /// 计算MACD指标
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

    List<double> emaFast = _calculateEMA(data, fastPeriod);
    List<double> emaSlow = _calculateEMA(data, slowPeriod);

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

    List<double> deaValues = _calculateEMAFromValues(difValues, signalPeriod, slowPeriod - 1);

    for (int i = 0; i < data.length; i++) {
      if (i < slowPeriod + signalPeriod - 2) {
        dea.add(null);
        macdBar.add(null);
      } else {
        dea.add(deaValues[i]);
        double bar = (difValues[i] - deaValues[i]) * 2;
        macdBar.add(bar);
      }
    }

    return MACDResult(dif: dif, dea: dea, macdBar: macdBar);
  }

  /// 计算KDJ指标
  KDJResult calculateKDJ(List<KlineModel> data, {int period = 9, int k = 3, int d = 3}) {
    List<double?> kValues = [];
    List<double?> dValues = [];
    List<double?> jValues = [];

    if (data.length < period) {
      for (int i = 0; i < data.length; i++) {
        kValues.add(null);
        dValues.add(null);
        jValues.add(null);
      }
      return KDJResult(k: kValues, d: dValues, j: jValues);
    }

    double prevK = 50.0;
    double prevD = 50.0;

    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        kValues.add(null);
        dValues.add(null);
        jValues.add(null);
        continue;
      }

      double highest = -double.infinity;
      double lowest = double.infinity;
      for (int j = i - period + 1; j <= i; j++) {
        if (data[j].high > highest) highest = data[j].high;
        if (data[j].low < lowest) lowest = data[j].low;
      }

      double rsv = 0;
      if (highest != lowest) {
        rsv = (data[i].close - lowest) / (highest - lowest) * 100;
      }

      double currentK = (prevK * (k - 1) + rsv) / k;
      double currentD = (prevD * (d - 1) + currentK) / d;
      double currentJ = 3 * currentK - 2 * currentD;

      kValues.add(currentK);
      dValues.add(currentD);
      jValues.add(currentJ);

      prevK = currentK;
      prevD = currentD;
    }

    return KDJResult(k: kValues, d: dValues, j: jValues);
  }

  /// 计算RSI指标
  List<double?> calculateRSI(List<KlineModel> data, {int period = 14}) {
    List<double?> result = [];

    if (data.length < period + 1) {
      for (int i = 0; i < data.length; i++) {
        result.add(null);
      }
      return result;
    }

    result.add(null); // 第一个无变化

    double avgGain = 0;
    double avgLoss = 0;

    // 计算初始平均涨跌
    for (int i = 1; i <= period; i++) {
      double change = data[i].close - data[i - 1].close;
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss += change.abs();
      }
      if (i < period) {
        result.add(null);
      }
    }

    avgGain /= period;
    avgLoss /= period;

    double rs = avgLoss == 0 ? 100 : avgGain / avgLoss;
    result.add(100 - (100 / (1 + rs)));

    // 后续使用平滑方法
    for (int i = period + 1; i < data.length; i++) {
      double change = data[i].close - data[i - 1].close;
      double gain = change > 0 ? change : 0;
      double loss = change < 0 ? change.abs() : 0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      rs = avgLoss == 0 ? 100 : avgGain / avgLoss;
      result.add(100 - (100 / (1 + rs)));
    }

    return result;
  }

  /// 计算WR (威廉指标)
  List<double?> calculateWR(List<KlineModel> data, {int period = 14}) {
    List<double?> result = [];

    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.add(null);
        continue;
      }

      double highest = -double.infinity;
      double lowest = double.infinity;
      for (int j = i - period + 1; j <= i; j++) {
        if (data[j].high > highest) highest = data[j].high;
        if (data[j].low < lowest) lowest = data[j].low;
      }

      if (highest == lowest) {
        result.add(0);
      } else {
        // WR = (H - C) / (H - L) * -100
        double wr = (highest - data[i].close) / (highest - lowest) * -100;
        result.add(wr);
      }
    }

    return result;
  }

  // ========== 内部辅助方法 ==========

  List<double> _calculateEMA(List<KlineModel> data, int period) {
    List<double> result = [];
    double multiplier = 2.0 / (period + 1);

    double sum = 0;
    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        sum += data[i].close;
        result.add(data[i].close);
      } else if (i == period - 1) {
        sum += data[i].close;
        result.add(sum / period);
      } else {
        double ema = (data[i].close - result[i - 1]) * multiplier + result[i - 1];
        result.add(ema);
      }
    }

    return result;
  }

  List<double> _calculateEMAFromValues(List<double> values, int period, int startFrom) {
    List<double> result = List.filled(values.length, 0);
    double multiplier = 2.0 / (period + 1);

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

  /// 简易平方根（手动实现避免引入dart:math依赖问题）
  double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }
}

/// BOLL计算结果
class BOLLResult {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;

  BOLLResult({required this.upper, required this.middle, required this.lower});
}

/// MACD计算结果
class MACDResult {
  final List<double?> dif;
  final List<double?> dea;
  final List<double?> macdBar;

  MACDResult({required this.dif, required this.dea, required this.macdBar});
}

/// KDJ计算结果
class KDJResult {
  final List<double?> k;
  final List<double?> d;
  final List<double?> j;

  KDJResult({required this.k, required this.d, required this.j});
}
