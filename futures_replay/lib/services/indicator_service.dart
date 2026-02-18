import 'dart:math' as math;

import '../models/kline_model.dart';
import 'package:czsc_dart/czsc_dart.dart';

/// 技术指标计算服务
class IndicatorService {

  /// 计算简单移动平均线 (SMA)
  List<double?> calculateMA(List<KlineModel> data, int period) {
    List<double?> result = List.filled(data.length, null);
    if (period <= 0 || data.isEmpty) return result;

    double sum = 0;
    for (int i = 0; i < data.length; i++) {
      sum += data[i].close;
      if (i >= period) {
        sum -= data[i - period].close;
      }
      if (i >= period - 1) {
        result[i] = sum / period;
      }
    }
    return result;
  }

  /// 计算成交量均线
  List<double?> calculateVolumeMA(List<KlineModel> data, int period) {
    List<double?> result = List.filled(data.length, null);
    if (period <= 0 || data.isEmpty) return result;

    double sum = 0;
    for (int i = 0; i < data.length; i++) {
      sum += data[i].volume;
      if (i >= period) {
        sum -= data[i - period].volume;
      }
      if (i >= period - 1) {
        result[i] = sum / period;
      }
    }
    return result;
  }

  /// 计算布林带 (BOLL)
  BOLLResult calculateBOLL(List<KlineModel> data, {int period = 20, double multiplier = 2.0}) {
    List<double?> upper = List.filled(data.length, null);
    List<double?> middle = List.filled(data.length, null);
    List<double?> lower = List.filled(data.length, null);
    if (period <= 0 || data.isEmpty) {
      return BOLLResult(upper: upper, middle: middle, lower: lower);
    }

    double sum = 0;
    double sumSquares = 0;
    for (int i = 0; i < data.length; i++) {
      final close = data[i].close;
      sum += close;
      sumSquares += close * close;

      if (i >= period) {
        final old = data[i - period].close;
        sum -= old;
        sumSquares -= old * old;
      }

      if (i >= period - 1) {
        final ma = sum / period;
        final variance = ((sumSquares / period) - (ma * ma)).clamp(0, double.infinity);
        final stddev = math.sqrt(variance);
        upper[i] = ma + multiplier * stddev;
        middle[i] = ma;
        lower[i] = ma - multiplier * stddev;
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

  /// 计算ADX (Average Directional Index) 指标
  /// 
  /// 使用威尔德平滑算法（Wilder's Smoothing）
  /// [data] K线数据
  /// [period] 周期，默认14
  /// 
  /// 返回 ADXResult 包含 adx, pdi (+DI), mdi (-DI) 三个列表
  ADXResult calculateADX(List<KlineModel> data, {int period = 14}) {
    List<double?> adxList = [];
    List<double?> pdiList = [];
    List<double?> mdiList = [];

    if (data.length < period + 1) {
      // 数据不足，返回空值
      for (int i = 0; i < data.length; i++) {
        adxList.add(null);
        pdiList.add(null);
        mdiList.add(null);
      }
      return ADXResult(adx: adxList, pdi: pdiList, mdi: mdiList);
    }

    // 第一个值没有前一根K线，跳过
    adxList.add(null);
    pdiList.add(null);
    mdiList.add(null);

    // 步骤1: 计算 TR, +DM, -DM
    List<double> trList = [0]; // 第一个值为0（占位）
    List<double> pdmList = [0]; // +DM
    List<double> mdmList = [0]; // -DM

    for (int i = 1; i < data.length; i++) {
      final current = data[i];
      final previous = data[i - 1];

      // TR = max(high - low, abs(high - previous_close), abs(low - previous_close))
      final tr = [
        current.high - current.low,
        (current.high - previous.close).abs(),
        (current.low - previous.close).abs(),
      ].reduce((a, b) => a > b ? a : b);

      // +DM = high - previous_high (if positive and > -DM, else 0)
      // -DM = previous_low - low (if positive and > +DM, else 0)
      final upMove = current.high - previous.high;
      final downMove = previous.low - current.low;

      double pdm = 0;
      double mdm = 0;

      if (upMove > downMove && upMove > 0) {
        pdm = upMove;
      }
      if (downMove > upMove && downMove > 0) {
        mdm = downMove;
      }

      trList.add(tr);
      pdmList.add(pdm);
      mdmList.add(mdm);
    }

    // 步骤2: 威尔德平滑 TR, +DM, -DM
    List<double> smoothedTR = List.filled(data.length, 0);
    List<double> smoothedPDM = List.filled(data.length, 0);
    List<double> smoothedMDM = List.filled(data.length, 0);

    // 前N个值不足以计算，填充null
    for (int i = 1; i < period; i++) {
      adxList.add(null);
      pdiList.add(null);
      mdiList.add(null);
    }

    // 第一个平滑值 = 前N个值的简单平均
    double sumTR = 0;
    double sumPDM = 0;
    double sumMDM = 0;
    for (int i = 1; i <= period; i++) {
      sumTR += trList[i];
      sumPDM += pdmList[i];
      sumMDM += mdmList[i];
    }

    smoothedTR[period] = sumTR / period;
    smoothedPDM[period] = sumPDM / period;
    smoothedMDM[period] = sumMDM / period;

    // 后续值使用威尔德平滑: smoothed = (previous_smoothed * (N-1) + current) / N
    for (int i = period + 1; i < data.length; i++) {
      smoothedTR[i] = (smoothedTR[i - 1] * (period - 1) + trList[i]) / period;
      smoothedPDM[i] = (smoothedPDM[i - 1] * (period - 1) + pdmList[i]) / period;
      smoothedMDM[i] = (smoothedMDM[i - 1] * (period - 1) + mdmList[i]) / period;
    }

    // 步骤3: 计算 +DI 和 -DI
    List<double> pdiValues = List.filled(data.length, 0);
    List<double> mdiValues = List.filled(data.length, 0);
    List<double> dxValues = List.filled(data.length, 0);

    for (int i = period; i < data.length; i++) {
      if (smoothedTR[i] != 0) {
        pdiValues[i] = (smoothedPDM[i] / smoothedTR[i]) * 100;
        mdiValues[i] = (smoothedMDM[i] / smoothedTR[i]) * 100;

        pdiList.add(pdiValues[i]);
        mdiList.add(mdiValues[i]);

        // 步骤4: 计算 DX
        final diSum = pdiValues[i] + mdiValues[i];
        if (diSum != 0) {
          dxValues[i] = ((pdiValues[i] - mdiValues[i]).abs() / diSum) * 100;
        }
      } else {
        pdiList.add(0);
        mdiList.add(0);
      }
    }

    // 步骤5: 计算 ADX (DX的威尔德平滑)
    // 需要等待至少 period*2-1 根K线
    for (int i = period; i < period * 2 - 1 && i < data.length; i++) {
      adxList.add(null);
    }

    if (data.length >= period * 2) {
      // 第一个ADX = 前N个DX的简单平均
      double sumDX = 0;
      for (int i = period; i < period * 2; i++) {
        sumDX += dxValues[i];
      }
      double adx = sumDX / period;
      adxList.add(adx);

      // 后续ADX使用威尔德平滑
      for (int i = period * 2; i < data.length; i++) {
        adx = (adx * (period - 1) + dxValues[i]) / period;
        adxList.add(adx);
      }
    }

    return ADXResult(adx: adxList, pdi: pdiList, mdi: mdiList);
  }

  /// 计算CZSC分析结果
  /// 
  /// 为了性能考虑，只分析最近的maxKlines根K线
  /// 默认最多分析1000根K线，避免数据量过大导致卡顿
  CZSCResult calculateCZSC(List<KlineModel> data, String symbol, {int maxKlines = 1000}) {
    if (data.isEmpty) {
      return CZSCResult(biList: [], zsList: [], fxList: []);
    }

    try {
      // 限制数据量：只分析最近的maxKlines根K线
      final startIdx = data.length > maxKlines ? data.length - maxKlines : 0;
      final dataToAnalyze = data.sublist(startIdx);
      
      // 将KlineModel转换为RawBar
      final bars = <RawBar>[];
      for (int i = 0; i < dataToAnalyze.length; i++) {
        final k = dataToAnalyze[i];
        bars.add(RawBar(
          symbol: symbol,
          id: i,
          dt: k.time,
          freq: Freq.f5, // 默认使用5分钟周期
          open: k.open,
          close: k.close,
          high: k.high,
          low: k.low,
          vol: k.volume,
          amount: 0,
        ));
      }

      // 创建CZSC分析器
      final czsc = CZSC(bars: bars, maxBiNum: 200);

      return CZSCResult(
        biList: czsc.biList,
        zsList: czsc.zsList,
        fxList: czsc.fxList,
      );
    } catch (e) {
      // 如果分析失败，返回空结果
      print('CZSC calculation error: $e');
      return CZSCResult(biList: [], zsList: [], fxList: []);
    }
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

/// CZSC分析结果
class CZSCResult {
  final List<BI> biList;
  final List<ZS> zsList;
  final List<FX> fxList;

  CZSCResult({
    required this.biList,
    required this.zsList,
    required this.fxList,
  });
}

/// ADX计算结果
class ADXResult {
  /// ADX值（平均趋向指标）
  final List<double?> adx;
  
  /// +DI值（正向趋向指标）
  final List<double?> pdi;
  
  /// -DI值（负向趋向指标）
  final List<double?> mdi;

  ADXResult({
    required this.adx,
    required this.pdi,
    required this.mdi,
  });
}
