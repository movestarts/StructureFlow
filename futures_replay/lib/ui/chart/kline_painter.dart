import 'package:flutter/material.dart';
import '../../models/kline_model.dart';
import '../../models/trade_model.dart';
import 'chart_view_controller.dart';

class KlinePainter extends CustomPainter {
  final List<KlineModel> allData;
  final List<Trade> allTrades;
  final ChartViewController viewController;
  final double currentPrice;

  final Paint _wickPaint = Paint()..strokeWidth = 1.0;
  final Paint _candlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _volumePaint = Paint()..style = PaintingStyle.fill;
  final Paint _linePaint = Paint()..strokeWidth = 1.5..style = PaintingStyle.stroke;
  final Paint _gridPaint = Paint()..color = Colors.white10..strokeWidth = 0.5;
  final Paint _markerPaint = Paint()..style = PaintingStyle.fill;

  final Color upColor = const Color(0xFFEF5350);
  final Color downColor = const Color(0xFF26A69A);
  
  KlinePainter({
    required this.allData,
    required this.allTrades,
    required this.viewController,
    required this.currentPrice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (allData.isEmpty) return;

    final double plottingWidth = size.width - 60.0;
    
    // 获取可见范围
    int startIdx = viewController.visibleStartIndex.clamp(0, allData.length);
    int endIdx = viewController.visibleEndIndex.clamp(0, allData.length);
    
    if (startIdx >= endIdx || startIdx >= allData.length) return;
    
    final visibleData = allData.sublist(startIdx, endIdx);
    if (visibleData.isEmpty) return;

    // 计算价格范围
    double maxHigh = -double.infinity;
    double minLow = double.infinity;
    double maxVol = -double.infinity;

    for (var k in visibleData) {
      if (k.high > maxHigh) maxHigh = k.high;
      if (k.low < minLow) minLow = k.low;
      if (k.volume > maxVol) maxVol = k.volume;
    }
    
    final double priceRange = maxHigh - minLow;
    final double margin = (priceRange == 0 ? 1 : priceRange) * 0.1;
    final double topPrice = maxHigh + margin;
    final double bottomPrice = minLow - margin;
    final double range = topPrice - bottomPrice;

    final double chartHeight = size.height * 0.75;
    final double volTop = size.height * 0.80;
    final double volHeight = size.height - volTop;

    double getY(double price) {
      return chartHeight - ((price - bottomPrice) / range) * chartHeight;
    }
    
    double getVolY(double vol) {
      return size.height - (vol / (maxVol == 0 ? 1 : maxVol)) * volHeight;
    }

    // 获取X坐标（基于时间）
    double? getXForTime(DateTime time) {
      final idx = allData.indexWhere((k) => k.time.isAtSameMomentAs(time) || k.time.isAfter(time));
      if (idx == -1 || idx < startIdx || idx >= endIdx) return null;
      
      final visibleIdx = idx - startIdx;
      return visibleIdx * viewController.step + viewController.step / 2;
    }

    final candleWidth = viewController.candleWidth;
    final step = viewController.step;

    // 绘制K线
    for (int i = 0; i < visibleData.length; i++) {
      final k = visibleData[i];
      final double x = i * step + step / 2;
      
      final isUp = k.close >= k.open;
      final color = isUp ? upColor : downColor;
      
      _wickPaint.color = color;
      _candlePaint.color = color;
      
      canvas.drawLine(Offset(x, getY(k.high)), Offset(x, getY(k.low)), _wickPaint);
      
      double openY = getY(k.open);
      double closeY = getY(k.close);
      if ((openY - closeY).abs() < 1) {
        closeY = openY + (isUp ? -1 : 1);
      }
      
      final rect = Rect.fromLTRB(x - candleWidth/2, openY, x + candleWidth/2, closeY);
      canvas.drawRect(rect, _candlePaint);
      
      final volRect = Rect.fromLTRB(x - candleWidth/2, getVolY(k.volume), x + candleWidth/2, size.height);
      _volumePaint.color = color.withOpacity(0.5);
      canvas.drawRect(volRect, _volumePaint);
    }
    
    // 绘制价格轴
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final axisX = plottingWidth + 5.0;
    
    for (int i = 0; i <= 5; i++) {
      double p = bottomPrice + (range / 5) * i;
      double y = getY(p);
      textPainter.text = TextSpan(
        text: p.toStringAsFixed(1),
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(axisX, y - textPainter.height / 2));
      canvas.drawLine(Offset(0, y), Offset(plottingWidth, y), _gridPaint);
    }

    // 绘制交易标记
    for (var trade in allTrades) {
      final entryX = getXForTime(trade.entryTime);
      if (entryX != null) {
        final entryY = getY(trade.entryPrice);
        final entryColor = trade.direction == Direction.long ? Colors.red : Colors.green;
        
        _markerPaint.color = entryColor;
        final path = Path();
        if (trade.direction == Direction.long) {
          path.moveTo(entryX, entryY + 15);
          path.lineTo(entryX - 6, entryY + 25);
          path.lineTo(entryX + 6, entryY + 25);
        } else {
          path.moveTo(entryX, entryY - 15);
          path.lineTo(entryX - 6, entryY - 25);
          path.lineTo(entryX + 6, entryY - 25);
        }
        path.close();
        canvas.drawPath(path, _markerPaint);
        
        textPainter.text = TextSpan(
          text: trade.direction == Direction.long ? '买' : '卖',
          style: TextStyle(color: entryColor, fontWeight: FontWeight.bold, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(entryX - textPainter.width/2, entryY + (trade.direction == Direction.long ? 26 : -36)));
      }
      
      if (!trade.isOpen && trade.closeTime != null) {
        final exitX = getXForTime(trade.closeTime!);
        if (exitX != null) {
          final exitY = getY(trade.closePrice!);
          final exitColor = trade.direction == Direction.long ? Colors.green : Colors.red;
          
          _markerPaint.color = exitColor;
          final path = Path();
          if (trade.direction == Direction.long) {
            path.moveTo(exitX, exitY - 15);
            path.lineTo(exitX - 6, exitY - 25);
            path.lineTo(exitX + 6, exitY - 25);
          } else {
            path.moveTo(exitX, exitY + 15);
            path.lineTo(exitX - 6, exitY + 25);
            path.lineTo(exitX + 6, exitY + 25);
          }
          path.close();
          canvas.drawPath(path, _markerPaint);
          
          textPainter.text = TextSpan(
            text: '平',
            style: TextStyle(color: exitColor, fontWeight: FontWeight.bold, fontSize: 10),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(exitX - textPainter.width/2, exitY + (trade.direction == Direction.long ? -36 : 26)));
        }
      }
      
      if (trade.isOpen) {
        final y = getY(trade.entryPrice);
        if (y >= 0 && y <= chartHeight) {
          final color = trade.direction == Direction.long ? Colors.redAccent : Colors.greenAccent;
          _linePaint.color = color;
          
          for (double dx = 0; dx < plottingWidth; dx += 10) {
            canvas.drawLine(Offset(dx, y), Offset(dx + 5, y), _linePaint);
          }
          
          double pnl = trade.calculatePnL(currentPrice);
          String label = "${trade.direction.label} @ ${trade.entryPrice.toStringAsFixed(1)}  ${pnl >= 0 ? '盈' : '亏'}: ${pnl.toStringAsFixed(0)}";
          
          textPainter.text = TextSpan(
            text: label,
            style: TextStyle(
              color: pnl >= 0 ? Colors.red : Colors.green, 
              fontWeight: FontWeight.bold, 
              fontSize: 11,
              backgroundColor: Colors.black87
            ),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(10, y - 20));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant KlinePainter old) {
    return true;
  }
}
