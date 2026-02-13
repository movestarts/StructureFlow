import 'package:flutter/material.dart';
import '../../models/kline_model.dart';
import '../../models/trade_model.dart';
import '../../services/indicator_service.dart';
import '../../ui/theme/app_theme.dart';
import 'chart_view_controller.dart';

/// 主图指标类型
enum MainIndicatorType { ma, ema, boll }

class KlinePainter extends CustomPainter {
  final List<KlineModel> allData;
  final List<Trade> allTrades;
  final ChartViewController viewController;
  final double currentPrice;

  // 均线数据
  final List<double?> ma5;
  final List<double?> ma10;
  final List<double?> ma20;

  // BOLL数据
  final BOLLResult? bollData;

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

      final color = trade.direction == Direction.long
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

    for (var trade in allTrades) {
      final entryDataIdx = allData.indexWhere((k) => k.time.isAtSameMomentAs(trade.entryTime) || k.time.isAfter(trade.entryTime));
      if (entryDataIdx >= startIdx && entryDataIdx < endIdx) {
        final visibleIdx = entryDataIdx - startIdx;
        final x = visibleIdx * step + step / 2;
        final y = getY(trade.entryPrice);
        final color = trade.direction == Direction.long ? AppColors.bullish : AppColors.bearish;

        _markerPaint.color = color;
        final path = Path();
        if (trade.direction == Direction.long) {
          path.moveTo(x, y + 12);
          path.lineTo(x - 5, y + 20);
          path.lineTo(x + 5, y + 20);
        } else {
          path.moveTo(x, y - 12);
          path.lineTo(x - 5, y - 20);
          path.lineTo(x + 5, y - 20);
        }
        path.close();
        canvas.drawPath(path, _markerPaint);
      }

      if (!trade.isOpen && trade.closeTime != null) {
        final closeDataIdx = allData.indexWhere((k) => k.time.isAtSameMomentAs(trade.closeTime!) || k.time.isAfter(trade.closeTime!));
        if (closeDataIdx >= startIdx && closeDataIdx < endIdx) {
          final visibleIdx = closeDataIdx - startIdx;
          final x = visibleIdx * step + step / 2;
          final y = getY(trade.closePrice!);

          _markerPaint.color = Colors.white70;
          canvas.drawCircle(Offset(x, y), 4, _markerPaint);
          final borderPaint = Paint()..color = trade.realizedPnL >= 0 ? AppColors.bullish : AppColors.bearish..strokeWidth = 1.5..style = PaintingStyle.stroke;
          canvas.drawCircle(Offset(x, y), 4, borderPaint);
        }
      }
    }
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
    }
  }

  @override
  bool shouldRepaint(covariant KlinePainter old) => true;
}
