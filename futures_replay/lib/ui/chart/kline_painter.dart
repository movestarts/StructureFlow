import 'package:flutter/material.dart';
import '../../models/kline_model.dart';
import '../../models/trade_model.dart' as trade_model;
import '../../services/indicator_service.dart';
import '../../ui/theme/app_theme.dart';
import 'chart_view_controller.dart';
import 'package:czsc_dart/czsc_dart.dart' as czsc;

/// 主图指标类型
enum MainIndicatorType { ma, ema, boll, czsc }

class KlinePainter extends CustomPainter {
  final List<KlineModel> allData;
  final List<trade_model.Trade> allTrades;
  final ChartViewController viewController;
  final double currentPrice;

  // 均线数据
  final List<double?> ma5;
  final List<double?> ma10;
  final List<double?> ma20;

  // BOLL数据
  final BOLLResult? bollData;

  // CZSC数据
  final CZSCResult? czscData;

  // 显示控制
  final MainIndicatorType mainIndicator;

  final Paint _wickPaint = Paint()..strokeWidth = 1.0;
  final Paint _candlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _linePaint = Paint()..strokeWidth = 1.0..style = PaintingStyle.stroke;
  final Paint _gridPaint = Paint()..color = AppColors.grid..strokeWidth = 0.5;
  final Paint _markerPaint = Paint()..style = PaintingStyle.fill;
  final Paint _priceLabelBgPaint = Paint()..style = PaintingStyle.fill;

  KlinePainter({
    required this.allData,
    required this.allTrades,
    required this.viewController,
    required this.currentPrice,
    this.ma5 = const [],
    this.ma10 = const [],
    this.ma20 = const [],
    this.bollData,
    this.czscData,
    this.mainIndicator = MainIndicatorType.boll,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (allData.isEmpty) return;

    final double priceAxisWidth = 60.0;
    final double plottingWidth = size.width - priceAxisWidth;

    int startIdx = viewController.visibleStartIndex.clamp(0, allData.length);
    int endIdx = viewController.visibleEndIndex.clamp(0, allData.length);

    if (startIdx >= endIdx || startIdx >= allData.length) return;

    final visibleData = allData.sublist(startIdx, endIdx);
    if (visibleData.isEmpty) return;

    // 计算价格范围
    double maxHigh = -double.infinity;
    double minLow = double.infinity;

    for (var k in visibleData) {
      if (k.high > maxHigh) maxHigh = k.high;
      if (k.low < minLow) minLow = k.low;
    }

    // 考虑BOLL/MA范围
    _expandRange(startIdx, endIdx, ma5, (v) { if (v > maxHigh) maxHigh = v; if (v < minLow) minLow = v; });
    _expandRange(startIdx, endIdx, ma10, (v) { if (v > maxHigh) maxHigh = v; if (v < minLow) minLow = v; });
    _expandRange(startIdx, endIdx, ma20, (v) { if (v > maxHigh) maxHigh = v; if (v < minLow) minLow = v; });
    if (bollData != null) {
      _expandRange(startIdx, endIdx, bollData!.upper, (v) { if (v > maxHigh) maxHigh = v; if (v < minLow) minLow = v; });
      _expandRange(startIdx, endIdx, bollData!.lower, (v) { if (v > maxHigh) maxHigh = v; if (v < minLow) minLow = v; });
    }

    final double priceRange = maxHigh - minLow;
    final double margin = (priceRange == 0 ? 1 : priceRange) * 0.08;
    final double topPrice = maxHigh + margin;
    final double bottomPrice = minLow - margin;
    final double range = topPrice - bottomPrice;

    final double chartHeight = size.height;

    double getY(double price) {
      return chartHeight - ((price - bottomPrice) / range) * chartHeight;
    }

    final candleWidth = viewController.candleWidth;
    final step = viewController.step;

    // ===== 绘制网格 =====
    _drawGrid(canvas, size, plottingWidth, topPrice, bottomPrice, range, getY);

    // ===== 绘制BOLL =====
    if (mainIndicator == MainIndicatorType.boll && bollData != null) {
      _drawMALine(canvas, startIdx, endIdx, step, getY, bollData!.upper,
          Paint()..color = AppColors.bollUp..strokeWidth = 1.0..style = PaintingStyle.stroke);
      _drawMALine(canvas, startIdx, endIdx, step, getY, bollData!.middle,
          Paint()..color = AppColors.bollMid..strokeWidth = 1.0..style = PaintingStyle.stroke);
      _drawMALine(canvas, startIdx, endIdx, step, getY, bollData!.lower,
          Paint()..color = AppColors.bollDn..strokeWidth = 1.0..style = PaintingStyle.stroke);
    }

    // ===== 绘制MA =====
    if (mainIndicator == MainIndicatorType.ma || mainIndicator == MainIndicatorType.ema) {
      if (ma5.isNotEmpty) {
        _drawMALine(canvas, startIdx, endIdx, step, getY, ma5,
            Paint()..color = AppColors.ma5..strokeWidth = 1.0..style = PaintingStyle.stroke);
      }
      if (ma10.isNotEmpty) {
        _drawMALine(canvas, startIdx, endIdx, step, getY, ma10,
            Paint()..color = AppColors.ma10..strokeWidth = 1.0..style = PaintingStyle.stroke);
      }
      if (ma20.isNotEmpty) {
        _drawMALine(canvas, startIdx, endIdx, step, getY, ma20,
            Paint()..color = AppColors.ma20..strokeWidth = 1.0..style = PaintingStyle.stroke);
      }
    }

    // ===== 绘制CZSC中枢 =====
    if (mainIndicator == MainIndicatorType.czsc && czscData != null && _isCzscDataValid()) {
      _drawZsList(canvas, startIdx, endIdx, step, getY, chartHeight);
    }

    // ===== 绘制CZSC笔 =====
    if (mainIndicator == MainIndicatorType.czsc && czscData != null && _isCzscDataValid()) {
      _drawBiList(canvas, startIdx, endIdx, step, getY);
    }

    // ===== 绘制K线 =====
    for (int i = 0; i < visibleData.length; i++) {
      final k = visibleData[i];
      final double x = i * step + step / 2;

      final isUp = k.close >= k.open;
      final color = isUp ? AppColors.bullish : AppColors.bearish;

      _wickPaint.color = color;
      _candlePaint.color = color;

      // 影线
      canvas.drawLine(Offset(x, getY(k.high)), Offset(x, getY(k.low)), _wickPaint);

      // 实体
      double openY = getY(k.open);
      double closeY = getY(k.close);
      if ((openY - closeY).abs() < 1) {
        closeY = openY + (isUp ? -1 : 1);
      }

      final rect = Rect.fromLTRB(x - candleWidth / 2, openY.clamp(0, chartHeight), x + candleWidth / 2, closeY.clamp(0, chartHeight));
      if (isUp) {
        // 阳线：空心或实心（这里用实心）
        canvas.drawRect(rect, _candlePaint);
      } else {
        canvas.drawRect(rect, _candlePaint);
      }
    }

    // ===== 绘制持仓线 =====
    _drawPositionLines(canvas, size, plottingWidth, chartHeight, getY);

    // ===== 绘制交易标记 =====
    _drawTradeMarkers(canvas, startIdx, endIdx, step, getY, chartHeight);

    // ===== 绘制价格轴 =====
    _drawPriceAxis(canvas, size, plottingWidth, topPrice, bottomPrice, range, getY);

    // ===== 绘制最新价格标签 =====
    if (visibleData.isNotEmpty) {
      _drawCurrentPriceLabel(canvas, size, plottingWidth, getY, visibleData.last);
    }

    // ===== 绘制指标数值标签 =====
    _drawIndicatorLabels(canvas, endIdx);
  }

  void _expandRange(int startIdx, int endIdx, List<double?> data, void Function(double) callback) {
    for (int i = startIdx; i < endIdx && i < data.length; i++) {
      if (data[i] != null) callback(data[i]!);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double plotWidth, double top, double bottom, double range, double Function(double) getY) {
    for (int i = 1; i < 5; i++) {
      double p = bottom + (range / 5) * i;
      double y = getY(p);
      canvas.drawLine(Offset(0, y), Offset(plotWidth, y), _gridPaint);
    }
  }

  void _drawMALine(Canvas canvas, int startIdx, int endIdx, double step, double Function(double) getY, List<double?> data, Paint paint) {
    if (data.isEmpty) return;

    Path path = Path();
    bool started = false;

    for (int i = 0; i < (endIdx - startIdx); i++) {
      int dataIdx = startIdx + i;
      if (dataIdx >= data.length) break;

      double? value = data[dataIdx];
      if (value == null) continue;

      double x = i * step + step / 2;
      double y = getY(value);

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

  void _drawPositionLines(Canvas canvas, Size size, double plotWidth, double chartHeight, double Function(double) getY) {
    for (var trade in allTrades) {
      if (!trade.isOpen) continue;

      final y = getY(trade.entryPrice);
      if (y < 0 || y > chartHeight) continue;

      final color = trade.direction == trade_model.Direction.long
          ? AppColors.bullishBright
          : AppColors.bearishBright;

      _linePaint.color = color.withOpacity(0.6);
      _linePaint.strokeWidth = 1.0;

      // 虚线
      double dx = 0;
      while (dx < plotWidth) {
        canvas.drawLine(Offset(dx, y), Offset(dx + 4, y), _linePaint);
        dx += 8;
      }

      // 价格标签
      String label = trade.entryPrice.toStringAsFixed(1);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // 背景
      final labelRect = Rect.fromLTWH(plotWidth + 2, y - tp.height / 2 - 2, tp.width + 6, tp.height + 4);
      _priceLabelBgPaint.color = color.withOpacity(0.2);
      canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(3)), _priceLabelBgPaint);
      tp.paint(canvas, Offset(plotWidth + 5, y - tp.height / 2));
    }
  }

  void _drawTradeMarkers(Canvas canvas, int startIdx, int endIdx, double step, double Function(double) getY, double chartHeight) {
    if (endIdx > allData.length) endIdx = allData.length;

    for (var trade in allTrades) {
      // 1. Draw Entry Marker
      final entryIdx = _findBarIndexAtOrBefore(trade.entryTime);
      
      if (entryIdx >= startIdx && entryIdx < endIdx) {
        final kline = allData[entryIdx];
        final visibleIdx = entryIdx - startIdx;
        final x = visibleIdx * step + step / 2;
        
        // Long Entry = BUY, Short Entry = SELL
        final isBuy = trade.direction == trade_model.Direction.long;
        final y = isBuy ? getY(kline.low) : getY(kline.high);
        
        _drawMarkerBadge(canvas, x, y, isBuy, isBuy ? "BUY" : "SELL", true);
      }

      // 2. Draw Exit Marker
      if (!trade.isOpen && trade.closeTime != null) {
        final closeIdx = _findBarIndexAtOrBefore(trade.closeTime!);
        
        if (closeIdx >= startIdx && closeIdx < endIdx) {
           final kline = allData[closeIdx];
           final visibleIdx = closeIdx - startIdx;
           final x = visibleIdx * step + step / 2;
           
           // Long Exit = SELL (to close), Short Exit = BUY (to close)
           final isLongTrade = trade.direction == trade_model.Direction.long;
           final isBuyAction = !isLongTrade; // Exit Long -> Sell (false), Exit Short -> Buy (true)
           
           final y = isBuyAction ? getY(kline.low) : getY(kline.high);
           
           _drawMarkerBadge(canvas, x, y, isBuyAction, "CLOSE", false);
        }
      }
    }
  }

  int _findBarIndexAtOrBefore(DateTime target) {
    if (allData.isEmpty) return -1;
    if (allData.first.time.isAfter(target)) return -1;

    int left = 0;
    int right = allData.length - 1;
    int answer = -1;

    while (left <= right) {
      final mid = (left + right) >> 1;
      final t = allData[mid].time;
      if (t.isAtSameMomentAs(target) || t.isBefore(target)) {
        answer = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }
    return answer;
  }

  void _drawMarkerBadge(Canvas canvas, double x, double y, bool isBuy, String text, bool isEntry) {
    final color = isBuy ? AppColors.bullish : AppColors.bearish;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padding = 4.0;
    final w = tp.width + padding * 2;
    final h = tp.height + padding * 2;
    
    // Offset from candle
    final defaultOffset = 15.0; 
    
    // If Buy, draw below (y + offset). If Sell, draw above (y - offset - h).
    final double badgeTop = isBuy ? (y + defaultOffset) : (y - defaultOffset - h);
    final double badgeLeft = x - w / 2;
    
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeLeft, badgeTop, w, h), 
      const Radius.circular(4)
    );

    final bgPaint = Paint()..color = color..style = PaintingStyle.fill;
    
    // Draw connecting line/pointer
    final linePath = Path();
    if (isBuy) {
       // Pointing Up to candle low
       linePath.moveTo(x, y + 2); // Start near candle
       linePath.lineTo(x, badgeTop); // End at badge top
    } else {
       // Pointing Down to candle high
       linePath.moveTo(x, y - 2); // Start near candle
       linePath.lineTo(x, badgeTop + h); // End at badge bottom
    }
    canvas.drawPath(linePath, Paint()..color = color..strokeWidth = 1.0..style = PaintingStyle.stroke);

    // Draw Badge
    canvas.drawRRect(rrect, bgPaint);
    tp.paint(canvas, Offset(badgeLeft + padding, badgeTop + padding));
    
    // Draw Entry/Exit circle at the actual price point? 
    // Maybe just a small dot on the candle key price
    // But text badge is the main thing user requested.
  }

  void _drawPriceAxis(Canvas canvas, Size size, double plotWidth, double top, double bottom, double range, double Function(double) getY) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final axisX = plotWidth + 4;

    for (int i = 0; i <= 5; i++) {
      double p = bottom + (range / 5) * i;
      double y = getY(p);
      tp.text = TextSpan(
        text: p.toStringAsFixed(2),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas, Offset(axisX, y - tp.height / 2));
    }
  }

  void _drawCurrentPriceLabel(Canvas canvas, Size size, double plotWidth, double Function(double) getY, KlineModel last) {
    final price = last.close;
    final y = getY(price);
    final isUp = price >= last.open;
    final color = isUp ? AppColors.bullish : AppColors.bearish;

    // 虚线
    _linePaint.color = color.withOpacity(0.4);
    _linePaint.strokeWidth = 0.8;
    double dx = 0;
    while (dx < plotWidth) {
      canvas.drawLine(Offset(dx, y), Offset(dx + 3, y), _linePaint);
      dx += 6;
    }

    // 价格标签背景
    final tp = TextPainter(
      text: TextSpan(
        text: price.toStringAsFixed(2),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelRect = Rect.fromLTWH(plotWidth, y - tp.height / 2 - 3, tp.width + 10, tp.height + 6);
    _priceLabelBgPaint.color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(3)), _priceLabelBgPaint);
    tp.paint(canvas, Offset(plotWidth + 5, y - tp.height / 2));
  }

  void _drawIndicatorLabels(Canvas canvas, int endIdx) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    double offsetX = 5;

    if (mainIndicator == MainIndicatorType.boll && bollData != null && endIdx > 0 && endIdx <= bollData!.upper.length) {
      final u = bollData!.upper[endIdx - 1];
      final m = bollData!.middle[endIdx - 1];
      final l = bollData!.lower[endIdx - 1];
      
      tp.text = TextSpan(children: [
        TextSpan(text: 'BOLL(20): ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
        if (u != null) TextSpan(text: 'UP:${u.toStringAsFixed(2)} ', style: TextStyle(color: AppColors.bollUp, fontSize: 10)),
        if (m != null) TextSpan(text: 'MB:${m.toStringAsFixed(2)} ', style: TextStyle(color: AppColors.bollMid, fontSize: 10)),
        if (l != null) TextSpan(text: 'DN:${l.toStringAsFixed(2)}', style: TextStyle(color: AppColors.bollDn, fontSize: 10)),
      ]);
      tp.layout();
      tp.paint(canvas, Offset(offsetX, 5));
    } else if (mainIndicator == MainIndicatorType.ma) {
      List<TextSpan> spans = [];
      if (ma5.isNotEmpty && endIdx > 0 && endIdx <= ma5.length && ma5[endIdx - 1] != null)
        spans.add(TextSpan(text: 'MA5:${ma5[endIdx - 1]!.toStringAsFixed(2)} ', style: TextStyle(color: AppColors.ma5, fontSize: 10)));
      if (ma10.isNotEmpty && endIdx > 0 && endIdx <= ma10.length && ma10[endIdx - 1] != null)
        spans.add(TextSpan(text: 'MA10:${ma10[endIdx - 1]!.toStringAsFixed(2)} ', style: TextStyle(color: AppColors.ma10, fontSize: 10)));
      if (ma20.isNotEmpty && endIdx > 0 && endIdx <= ma20.length && ma20[endIdx - 1] != null)
        spans.add(TextSpan(text: 'MA20:${ma20[endIdx - 1]!.toStringAsFixed(2)}', style: TextStyle(color: AppColors.ma20, fontSize: 10)));
      
      if (spans.isNotEmpty) {
        tp.text = TextSpan(children: spans);
        tp.layout();
        tp.paint(canvas, Offset(offsetX, 5));
      }
    } else if (mainIndicator == MainIndicatorType.czsc && czscData != null) {
      if (_isCzscDataValid()) {
        final dataCount = allData.length > 1000 ? '最近1000根' : '${allData.length}根';
        tp.text = TextSpan(children: [
          TextSpan(text: 'CZSC($dataCount): ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          TextSpan(text: '笔:${czscData!.biList.length} ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
          TextSpan(text: '中枢:${czscData!.zsList.length}', style: TextStyle(color: Color(0xFF00CED1), fontSize: 10)),
        ]);
        tp.layout();
        tp.paint(canvas, Offset(offsetX, 5));
      } else {
        // 数据无效，显示提示
        tp.text = TextSpan(children: [
          TextSpan(text: 'CZSC: ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          TextSpan(text: '正在计算...', style: TextStyle(color: Colors.orange, fontSize: 10)),
        ]);
        tp.layout();
        tp.paint(canvas, Offset(offsetX, 5));
      }
    }
  }

  /// 绘制笔列表
  void _drawBiList(Canvas canvas, int startIdx, int endIdx, double step, double Function(double) getY) {
    if (czscData == null || czscData!.biList.isEmpty) return;

    final biPaint = Paint()
      ..color = Color(0xFFFFD700) // 金色
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 性能优化：只绘制可见范围附近的笔（提前结束遍历）
    int drawnCount = 0;
    const maxDrawnBi = 100; // 最多绘制100条笔，避免过度绘制

    for (final bi in czscData!.biList.reversed) {
      if (drawnCount >= maxDrawnBi) break;

      // 找到起始和结束K线的索引
      final startBarIdx = _findBarIndexByTime(bi.sdt);
      final endBarIdx = _findBarIndexByTime(bi.edt);

      if (startBarIdx == -1 || endBarIdx == -1) continue;
      
      // 检查笔是否在可见范围内（扩展一点范围以保证连续性）
      if (endBarIdx < startIdx - 10) continue; // 完全在左侧之外，跳过
      if (startBarIdx > endIdx + 10) continue; // 完全在右侧之外，跳过

      drawnCount++;

      // 计算笔的起点和终点坐标
      final visibleStartIdx = startBarIdx - startIdx;
      final visibleEndIdx = endBarIdx - startIdx;

      final x1 = visibleStartIdx.clamp(0, endIdx - startIdx - 1).toDouble() * step + step / 2;
      final x2 = visibleEndIdx.clamp(0, endIdx - startIdx - 1).toDouble() * step + step / 2;
      final y1 = getY(bi.direction == czsc.Direction.up ? bi.low : bi.high);
      final y2 = getY(bi.direction == czsc.Direction.up ? bi.high : bi.low);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), biPaint);

      // 绘制端点标记
      final pointPaint = Paint()
        ..color = bi.direction == czsc.Direction.up ? AppColors.bullish : AppColors.bearish
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x1, y1), 3, pointPaint);
      canvas.drawCircle(Offset(x2, y2), 3, pointPaint);
    }
  }

  /// 绘制中枢列表
  void _drawZsList(Canvas canvas, int startIdx, int endIdx, double step, double Function(double) getY, double chartHeight) {
    if (czscData == null || czscData!.zsList.isEmpty) return;

    final zsPaint = Paint()
      ..color = Color(0xFF00CED1).withOpacity(0.2) // 青色半透明
      ..style = PaintingStyle.fill;

    final zsBorderPaint = Paint()
      ..color = Color(0xFF00CED1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 性能优化：只绘制可见范围附近的中枢
    for (final zs in czscData!.zsList.reversed) {
      // 找到中枢起始和结束K线的索引
      final zsStartIdx = _findBarIndexByTime(zs.sdt);
      final zsEndIdx = _findBarIndexByTime(zs.edt);

      if (zsStartIdx == -1 || zsEndIdx == -1) continue;

      // 检查中枢是否在可见范围内（扩展一点范围）
      if (zsEndIdx < startIdx - 10) continue; // 完全在左侧之外
      if (zsStartIdx > endIdx + 10) continue; // 完全在右侧之外

      // 计算中枢的绘制位置
      final visibleStartIdx = (zsStartIdx - startIdx).clamp(0, endIdx - startIdx - 1);
      final visibleEndIdx = (zsEndIdx - startIdx).clamp(0, endIdx - startIdx - 1);

      final left = visibleStartIdx.toDouble() * step;
      final right = (visibleEndIdx + 1).toDouble() * step;
      final top = getY(zs.zg).clamp(0.0, chartHeight);
      final bottom = getY(zs.zd).clamp(0.0, chartHeight);

      final rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, zsPaint);
      canvas.drawRect(rect, zsBorderPaint);

      // 绘制中轴线
      final zzY = getY(zs.zz).clamp(0.0, chartHeight);
      final zzPaint = Paint()
        ..color = Color(0xFF00CED1).withOpacity(0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      double dx = left;
      while (dx < right) {
        canvas.drawLine(Offset(dx, zzY), Offset((dx + 4).clamp(dx, right), zzY), zzPaint);
        dx += 8;
      }
    }
  }

  /// 根据时间查找K线索引
  int _findBarIndexByTime(DateTime time) {
    for (int i = 0; i < allData.length; i++) {
      if (allData[i].time.isAtSameMomentAs(time)) {
        return i;
      }
      if (allData[i].time.isAfter(time)) {
        return i > 0 ? i - 1 : 0;
      }
    }
    return allData.isNotEmpty ? allData.length - 1 : -1;
  }

  /// 检查CZSC数据是否有效
  /// 防止切换周期后使用旧数据导致显示异常
  bool _isCzscDataValid() {
    if (czscData == null || allData.isEmpty) return false;
    
    // 如果CZSC数据为空，跳过
    if (czscData!.biList.isEmpty && czscData!.zsList.isEmpty) return false;
    
    // 检查CZSC数据的时间范围是否在当前K线数据范围内
    if (czscData!.biList.isNotEmpty) {
      final firstBi = czscData!.biList.first;
      final lastBi = czscData!.biList.last;
      final firstKlineTime = allData.first.time;
      final lastKlineTime = allData.last.time;
      
      // 如果笔的时间范围完全不在当前K线范围内，说明是旧数据
      if (lastBi.edt.isBefore(firstKlineTime) || firstBi.sdt.isAfter(lastKlineTime)) {
        return false;
      }
    }
    
    return true;
  }

  @override
  bool shouldRepaint(covariant KlinePainter old) {
    return old.allData != allData ||
        old.allTrades != allTrades ||
        old.currentPrice != currentPrice ||
        old.ma5 != ma5 ||
        old.ma10 != ma10 ||
        old.ma20 != ma20 ||
        old.bollData != bollData ||
        old.czscData != czscData ||
        old.mainIndicator != mainIndicator ||
        old.viewController.visibleStartIndex != viewController.visibleStartIndex ||
        old.viewController.visibleEndIndex != viewController.visibleEndIndex ||
        old.viewController.candleWidth != viewController.candleWidth ||
        old.viewController.step != viewController.step;
  }
}
