import 'package:flutter/material.dart';
import '../../services/indicator_service.dart';
import 'chart_view_controller.dart';

/// MACD副图画板
class MACDPainter extends CustomPainter {
  final MACDResult macdData;
  final ChartViewController viewController;
  final int dataLength;

  final Paint _difPaint = Paint()..color = Colors.yellow..strokeWidth = 1.0..style = PaintingStyle.stroke;
  final Paint _deaPaint = Paint()..color = Colors.cyan..strokeWidth = 1.0..style = PaintingStyle.stroke;
  final Paint _barPaint = Paint()..style = PaintingStyle.fill;
  final Paint _zeroPaint = Paint()..color = Colors.white30..strokeWidth = 0.5;
  final Paint _gridPaint = Paint()..color = Colors.white10..strokeWidth = 0.5;

  MACDPainter({
    required this.macdData,
    required this.viewController,
    required this.dataLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (macdData.dif.isEmpty) return;

    final double plottingWidth = size.width - 60.0;
    
    int startIdx = viewController.visibleStartIndex.clamp(0, dataLength);
    int endIdx = viewController.visibleEndIndex.clamp(0, dataLength);
    
    if (startIdx >= endIdx) return;

    // 计算MACD范围
    double maxVal = -double.infinity;
    double minVal = double.infinity;
    
    for (int i = startIdx; i < endIdx && i < macdData.dif.length; i++) {
      if (macdData.dif[i] != null) {
        if (macdData.dif[i]! > maxVal) maxVal = macdData.dif[i]!;
        if (macdData.dif[i]! < minVal) minVal = macdData.dif[i]!;
      }
      if (macdData.dea[i] != null) {
        if (macdData.dea[i]! > maxVal) maxVal = macdData.dea[i]!;
        if (macdData.dea[i]! < minVal) minVal = macdData.dea[i]!;
      }
      if (macdData.macdBar[i] != null) {
        if (macdData.macdBar[i]! > maxVal) maxVal = macdData.macdBar[i]!;
        if (macdData.macdBar[i]! < minVal) minVal = macdData.macdBar[i]!;
      }
    }
    
    if (maxVal == -double.infinity || minVal == double.infinity) return;
    
    // 确保包含零轴
    if (maxVal < 0) maxVal = 0;
    if (minVal > 0) minVal = 0;
    
    final range = maxVal - minVal;
    final margin = (range == 0 ? 1 : range) * 0.1;
    final top = maxVal + margin;
    final bottom = minVal - margin;
    final totalRange = top - bottom;
    
    double getY(double value) {
      return size.height - ((value - bottom) / totalRange) * size.height;
    }
    
    final step = viewController.step;
    final candleWidth = viewController.candleWidth;
    
    // 绘制零轴
    double zeroY = getY(0);
    canvas.drawLine(Offset(0, zeroY), Offset(plottingWidth, zeroY), _zeroPaint);
    
    // 绘制MACD柱
    for (int i = 0; i < (endIdx - startIdx); i++) {
      int dataIdx = startIdx + i;
      if (dataIdx >= macdData.macdBar.length) break;
      
      double? bar = macdData.macdBar[dataIdx];
      if (bar == null) continue;
      
      double x = i * step + step / 2;
      double y = getY(bar);
      
      _barPaint.color = bar >= 0 ? Colors.red : Colors.green;
      
      canvas.drawRect(
        Rect.fromLTRB(x - candleWidth/3, y, x + candleWidth/3, zeroY),
        _barPaint,
      );
    }
    
    // 绘制DIF线
    _drawLine(canvas, startIdx, endIdx, step, getY, _difPaint, macdData.dif);
    
    // 绘制DEA线
    _drawLine(canvas, startIdx, endIdx, step, getY, _deaPaint, macdData.dea);
    
    // 绘制标签
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: 'MACD(12,26,9)',
      style: TextStyle(color: Colors.white54, fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(5, 5));
    
    // 绘制DIF/DEA当前值
    if (endIdx > 0 && endIdx <= macdData.dif.length) {
      final lastDif = macdData.dif[endIdx - 1];
      final lastDea = macdData.dea[endIdx - 1];
      
      String info = '';
      if (lastDif != null) info += 'DIF:${lastDif.toStringAsFixed(1)} ';
      if (lastDea != null) info += 'DEA:${lastDea.toStringAsFixed(1)}';
      
      textPainter.text = TextSpan(
        text: info,
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(120, 5));
    }
  }
  
  void _drawLine(Canvas canvas, int startIdx, int endIdx, double step, double Function(double) getY, Paint paint, List<double?> data) {
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

  @override
  bool shouldRepaint(covariant MACDPainter old) {
    return true;
  }
}
