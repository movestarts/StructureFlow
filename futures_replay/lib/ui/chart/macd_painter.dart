import 'package:flutter/material.dart';
import '../../services/indicator_service.dart';
import '../../ui/theme/app_theme.dart';
import 'chart_view_controller.dart';

/// MACD副图画板
class MACDPainter extends CustomPainter {
  final MACDResult macdData;
  final ChartViewController viewController;
  final int dataLength;

  final Paint _barPaint = Paint()..style = PaintingStyle.fill;
  final Paint _zeroPaint = Paint()..color = Colors.white24..strokeWidth = 0.5;

  MACDPainter({
    required this.macdData,
    required this.viewController,
    required this.dataLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (macdData.dif.isEmpty) return;

    final double plotWidth = size.width - 60.0;

    int startIdx = viewController.visibleStartIndex.clamp(0, dataLength);
    int endIdx = viewController.visibleEndIndex.clamp(0, dataLength);
    if (startIdx >= endIdx) return;

    // 计算MACD范围
    double maxVal = -double.infinity;
    double minVal = double.infinity;

    for (int i = startIdx; i < endIdx && i < macdData.dif.length; i++) {
      _updateRange(macdData.dif[i], (v) { if (v > maxVal) maxVal = v; if (v < minVal) minVal = v; });
      _updateRange(macdData.dea[i], (v) { if (v > maxVal) maxVal = v; if (v < minVal) minVal = v; });
      _updateRange(macdData.macdBar[i], (v) { if (v > maxVal) maxVal = v; if (v < minVal) minVal = v; });
    }

    if (maxVal == -double.infinity || minVal == double.infinity) return;

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

    // 零轴
    double zeroY = getY(0);
    canvas.drawLine(Offset(0, zeroY), Offset(plotWidth, zeroY), _zeroPaint);

    // MACD柱
    for (int i = 0; i < (endIdx - startIdx); i++) {
      int dataIdx = startIdx + i;
      if (dataIdx >= macdData.macdBar.length) break;

      double? bar = macdData.macdBar[dataIdx];
      if (bar == null) continue;

      double x = i * step + step / 2;
      double y = getY(bar);

      _barPaint.color = bar >= 0 ? AppColors.bullish : AppColors.bearish;
      canvas.drawRect(
        Rect.fromLTRB(x - candleWidth / 3, y, x + candleWidth / 3, zeroY),
        _barPaint,
      );
    }

    // DIF线
    _drawLine(canvas, startIdx, endIdx, step, getY, macdData.dif,
        Paint()..color = AppColors.dif..strokeWidth = 1.0..style = PaintingStyle.stroke);

    // DEA线
    _drawLine(canvas, startIdx, endIdx, step, getY, macdData.dea,
        Paint()..color = AppColors.dea..strokeWidth = 1.0..style = PaintingStyle.stroke);

    // 标签
    final tp = TextPainter(textDirection: TextDirection.ltr);
    List<TextSpan> spans = [
      const TextSpan(text: 'MACD(12,26,9) ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ];

    if (endIdx > 0 && endIdx <= macdData.dif.length) {
      final lastDif = macdData.dif[endIdx - 1];
      final lastDea = macdData.dea[endIdx - 1];
      final lastBar = macdData.macdBar[endIdx - 1];

      if (lastDif != null) spans.add(TextSpan(text: 'DIF:${lastDif.toStringAsFixed(2)} ', style: const TextStyle(color: AppColors.dif, fontSize: 10)));
      if (lastDea != null) spans.add(TextSpan(text: 'DEA:${lastDea.toStringAsFixed(2)} ', style: const TextStyle(color: AppColors.dea, fontSize: 10)));
      if (lastBar != null) spans.add(TextSpan(text: 'MACD:${lastBar.toStringAsFixed(2)}', style: TextStyle(color: lastBar >= 0 ? AppColors.bullish : AppColors.bearish, fontSize: 10)));
    }

    tp.text = TextSpan(children: spans);
    tp.layout();
    tp.paint(canvas, const Offset(5, 2));
  }

  void _updateRange(double? value, void Function(double) callback) {
    if (value != null) callback(value);
  }

  void _drawLine(Canvas canvas, int startIdx, int endIdx, double step, double Function(double) getY, List<double?> data, Paint paint) {
    Path path = Path();
    bool started = false;

    for (int i = 0; i < (endIdx - startIdx); i++) {
      int dataIdx = startIdx + i;
      if (dataIdx >= data.length) break;
      double? value = data[dataIdx];
      if (value == null) continue;
      double x = i * step + step / 2;
      double y = getY(value);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    if (started) canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MACDPainter old) {
    return old.macdData != macdData ||
        old.dataLength != dataLength ||
        old.viewController.visibleStartIndex != viewController.visibleStartIndex ||
        old.viewController.visibleEndIndex != viewController.visibleEndIndex ||
        old.viewController.candleWidth != viewController.candleWidth ||
        old.viewController.step != viewController.step;
  }
}
