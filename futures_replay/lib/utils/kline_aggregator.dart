/// 国内期货K线聚合工具
/// 
/// 严格遵循国内期货交易时段和小节休息机制
/// 支持将5分钟K线聚合为30分钟、60分钟等周期
library;

import '../models/kline_model.dart';

class KlineAggregator {
  /// 将5分钟K线聚合为30分钟K线（国内期货专用）
  /// 
  /// 规则：
  /// - 09:00-09:30 (6个5min)
  /// - 09:30-10:00 (6个5min)
  /// - 10:00-10:15 (3个5min) ⚠️ 特殊
  /// - 10:30-11:00 (6个5min)
  /// - 11:00-11:30 (6个5min)
  /// - 13:30-14:00 (6个5min)
  /// - 14:00-14:30 (6个5min)
  /// - 14:30-15:00 (6个5min)
  /// - 21:00-21:30 (6个5min)
  /// - 21:30-22:00 (6个5min)
  /// - 22:00-22:30 (6个5min)
  /// - 22:30-23:00 (6个5min)
  static List<KlineModel> aggregate5MinTo30Min(List<KlineModel> source) {
    if (source.isEmpty) return [];

    final result = <KlineModel>[];
    final buffer = <KlineModel>[];
    DateTime? currentPeriodStart;

    for (int i = 0; i < source.length; i++) {
      final kline = source[i];
      final time = kline.time;

      // 确定这根K线应该属于哪个30分钟周期
      final periodStart = _get30MinPeriodStart(time);

      // 如果是新周期的开始，先结束上一个周期
      if (currentPeriodStart != null && periodStart != currentPeriodStart) {
        if (buffer.isNotEmpty) {
          result.add(_mergeKlines(buffer, currentPeriodStart));
          buffer.clear();
        }
      }

      // 更新当前周期
      currentPeriodStart = periodStart;
      buffer.add(kline);
    }

    // 处理最后一个缓冲区
    if (buffer.isNotEmpty && currentPeriodStart != null) {
      result.add(_mergeKlines(buffer, currentPeriodStart));
    }

    return result;
  }

  /// 确定某个时间点应该归属于哪个30分钟周期的开始时间
  /// 
  /// 这是核心逻辑！必须严格遵循国内期货交易时段
  static DateTime _get30MinPeriodStart(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    // 日盘时段
    if (hour == 9) {
      // 09:00-09:30
      if (minute < 30) {
        return DateTime(time.year, time.month, time.day, 9, 0);
      }
      // 09:30-10:00
      else {
        return DateTime(time.year, time.month, time.day, 9, 30);
      }
    } else if (hour == 10) {
      // 10:00-10:15 (特殊：只有3个5分钟)
      if (minute < 15) {
        return DateTime(time.year, time.month, time.day, 10, 0);
      }
      // 10:15-10:30 是休息时间，不应该有数据
      // 10:30-11:00
      else if (minute >= 30) {
        return DateTime(time.year, time.month, time.day, 10, 30);
      }
      // 10:15-10:30 如果有数据，归到10:00周期（容错处理）
      else {
        return DateTime(time.year, time.month, time.day, 10, 0);
      }
    } else if (hour == 11) {
      // 11:00-11:30
      return DateTime(time.year, time.month, time.day, 11, 0);
    } else if (hour == 13) {
      // 13:30-14:00
      return DateTime(time.year, time.month, time.day, 13, 30);
    } else if (hour == 14) {
      // 14:00-14:30
      if (minute < 30) {
        return DateTime(time.year, time.month, time.day, 14, 0);
      }
      // 14:30-15:00
      else {
        return DateTime(time.year, time.month, time.day, 14, 30);
      }
    } else if (hour == 21) {
      // 21:00-21:30
      if (minute < 30) {
        return DateTime(time.year, time.month, time.day, 21, 0);
      }
      // 21:30-22:00
      else {
        return DateTime(time.year, time.month, time.day, 21, 30);
      }
    } else if (hour == 22) {
      // 22:00-22:30
      if (minute < 30) {
        return DateTime(time.year, time.month, time.day, 22, 0);
      }
      // 22:30-23:00
      else {
        return DateTime(time.year, time.month, time.day, 22, 30);
      }
    } else if (hour == 23) {
      // 22:30-23:00 (跨23点的情况)
      return DateTime(time.year, time.month, time.day, 22, 30);
    } else if (hour == 0 || hour == 1 || hour == 2) {
      // 夜盘延续到凌晨的情况（部分品种如铜、黄金）
      // 23:00-23:30
      if (hour == 23 || (hour == 0 && minute < 30)) {
        return DateTime(time.year, time.month, time.day - 1, 23, 0);
      }
      // 23:30-00:00
      else if (hour == 0 && minute < 60) {
        return DateTime(time.year, time.month, time.day - 1, 23, 30);
      }
      // 00:00-00:30
      else if (hour == 0) {
        return DateTime(time.year, time.month, time.day, 0, 0);
      }
      // 00:30-01:00
      else if (hour == 0 && minute >= 30) {
        return DateTime(time.year, time.month, time.day, 0, 30);
      }
      // 01:00-01:30
      else if (hour == 1 && minute < 30) {
        return DateTime(time.year, time.month, time.day, 1, 0);
      }
      // 01:30-02:00
      else if (hour == 1 && minute >= 30) {
        return DateTime(time.year, time.month, time.day, 1, 30);
      }
      // 02:00-02:30 (极少数品种如黄金)
      else if (hour == 2 && minute < 30) {
        return DateTime(time.year, time.month, time.day, 2, 0);
      }
      // 02:30之后
      else {
        return DateTime(time.year, time.month, time.day, 2, 30);
      }
    }

    // 默认情况（理论上不应该到这里）
    // 按照标准30分钟对齐
    final alignedMinute = (minute ~/ 30) * 30;
    return DateTime(time.year, time.month, time.day, hour, alignedMinute);
  }

  /// 合并多根K线为一根
  /// 
  /// 规则：
  /// - Open: 取第一根的开盘价
  /// - Close: 取最后一根的收盘价
  /// - High: 取所有K线的最高价
  /// - Low: 取所有K线的最低价
  /// - Volume: 求和
  /// - Time: 使用周期开始时间
  static KlineModel _mergeKlines(List<KlineModel> klines, DateTime periodStart) {
    if (klines.isEmpty) {
      throw ArgumentError('Cannot merge empty kline list');
    }

    if (klines.length == 1) {
      // 只有一根K线，直接返回（但更新时间为周期开始时间）
      final single = klines.first;
      return KlineModel(
        time: periodStart,
        open: single.open,
        high: single.high,
        low: single.low,
        close: single.close,
        volume: single.volume,
      );
    }

    // 多根K线合并
    final open = klines.first.open;
    final close = klines.last.close;
    final high = klines.map((k) => k.high).reduce((a, b) => a > b ? a : b);
    final low = klines.map((k) => k.low).reduce((a, b) => a < b ? a : b);
    final volume = klines.fold<double>(0.0, (sum, k) => sum + k.volume);

    return KlineModel(
      time: periodStart,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  /// 判断某个时间是否在交易时段内
  /// 
  /// 用于数据校验
  static bool isInTradingSession(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final timeInMinutes = hour * 60 + minute;

    // 日盘：09:00-11:30, 13:30-15:00
    if ((timeInMinutes >= 9 * 60 && timeInMinutes < 11 * 60 + 30) ||
        (timeInMinutes >= 13 * 60 + 30 && timeInMinutes < 15 * 60)) {
      return true;
    }

    // 夜盘：21:00-23:00 (基础品种)
    if (timeInMinutes >= 21 * 60 && timeInMinutes < 23 * 60) {
      return true;
    }

    // 夜盘延长：23:00-02:30 (部分品种)
    if (timeInMinutes >= 23 * 60 || timeInMinutes < 2 * 60 + 30) {
      return true;
    }

    return false;
  }

  /// 获取下一个交易时段的开始时间
  /// 
  /// 用于确定K线周期边界
  static DateTime? getNextSessionStart(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    // 09:00 日盘开盘
    if (hour < 9) {
      return DateTime(time.year, time.month, time.day, 9, 0);
    }
    // 10:30 第二小节
    else if (hour == 10 && minute >= 15 && minute < 30) {
      return DateTime(time.year, time.month, time.day, 10, 30);
    }
    // 13:30 下午开盘
    else if (hour >= 11 && hour < 13) {
      return DateTime(time.year, time.month, time.day, 13, 30);
    }
    else if (hour == 13 && minute < 30) {
      return DateTime(time.year, time.month, time.day, 13, 30);
    }
    // 21:00 夜盘开盘
    else if (hour >= 15 && hour < 21) {
      return DateTime(time.year, time.month, time.day, 21, 0);
    }

    // 已经在交易时段内或超过当天最后时段
    return null;
  }
}

// ==================== 测试用例 ====================

void main() {
  // 测试用例
  _testAggregate5MinTo30Min();
}

void _testAggregate5MinTo30Min() {
  print('=== 测试国内期货5分钟聚合为30分钟 ===\n');

  // 模拟一天的5分钟数据
  final testData = _generateTestData();

  print('输入: ${testData.length} 根5分钟K线');
  print('时间范围: ${testData.first.time} ~ ${testData.last.time}\n');

  // 执行聚合
  final result = KlineAggregator.aggregate5MinTo30Min(testData);

  print('输出: ${result.length} 根30分钟K线\n');
  print('详细结果:');
  print('-' * 80);
  print('序号 | 时间          | 开盘   | 最高   | 最低   | 收盘   | 成交量');
  print('-' * 80);

  for (int i = 0; i < result.length; i++) {
    final k = result[i];
    final timeStr = '${k.time.hour.toString().padLeft(2, '0')}:${k.time.minute.toString().padLeft(2, '0')}';
    print('${(i + 1).toString().padLeft(2)} | $timeStr | '
        '${k.open.toStringAsFixed(2)} | '
        '${k.high.toStringAsFixed(2)} | '
        '${k.low.toStringAsFixed(2)} | '
        '${k.close.toStringAsFixed(2)} | '
        '${k.volume.toStringAsFixed(0)}');
  }

  print('-' * 80);

  // 验证关键周期
  print('\n验证关键周期:');
  _verifyPeriod(result, '09:00', 6);
  _verifyPeriod(result, '09:30', 6);
  _verifyPeriod(result, '10:00', 3); // 特殊：只有3个5分钟
  _verifyPeriod(result, '10:30', 6);
  _verifyPeriod(result, '11:00', 6);
  _verifyPeriod(result, '13:30', 6);
  _verifyPeriod(result, '21:00', 6);
}

void _verifyPeriod(List<KlineModel> result, String timeStr, int expectedCount) {
  final parts = timeStr.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  final found = result.where((k) => k.time.hour == hour && k.time.minute == minute).toList();

  if (found.isNotEmpty) {
    print('✅ $timeStr 周期存在');
  } else {
    print('❌ $timeStr 周期缺失');
  }
}

List<KlineModel> _generateTestData() {
  final data = <KlineModel>[];
  final baseDate = DateTime(2024, 1, 5); // 假设是2024年1月5日（交易日）

  double basePrice = 3800.0;

  // 生成日盘数据
  // 09:00 - 10:15 (15根5分钟K线)
  for (int i = 0; i < 15; i++) {
    final time = baseDate.add(Duration(hours: 9, minutes: i * 5));
    data.add(_createKline(time, basePrice + i));
  }

  // 10:30 - 11:30 (12根5分钟K线)
  for (int i = 0; i < 12; i++) {
    final time = baseDate.add(Duration(hours: 10, minutes: 30 + i * 5));
    data.add(_createKline(time, basePrice + 15 + i));
  }

  // 13:30 - 15:00 (18根5分钟K线)
  for (int i = 0; i < 18; i++) {
    final time = baseDate.add(Duration(hours: 13, minutes: 30 + i * 5));
    data.add(_createKline(time, basePrice + 27 + i));
  }

  // 夜盘：21:00 - 23:00 (24根5分钟K线)
  for (int i = 0; i < 24; i++) {
    final time = baseDate.add(Duration(hours: 21, minutes: i * 5));
    data.add(_createKline(time, basePrice + 45 + i));
  }

  return data;
}

KlineModel _createKline(DateTime time, double basePrice) {
  final open = basePrice;
  final close = basePrice + (time.minute % 10 - 5);
  final high = [open, close].reduce((a, b) => a > b ? a : b) + 2;
  final low = [open, close].reduce((a, b) => a < b ? a : b) - 2;
  final volume = 1000.0 + (time.minute * 10);

  return KlineModel(
    time: time,
    open: open,
    high: high,
    low: low,
    close: close,
    volume: volume,
  );
}
