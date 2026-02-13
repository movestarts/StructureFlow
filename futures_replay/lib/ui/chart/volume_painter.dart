import 'package:flutter/material.dart';
import '../../models/kline_model.dart';
import '../../ui/theme/app_theme.dart';
import 'chart_view_controller.dart';

/// 成交量副图画板
class VolumePainter extends CustomPainter {
  final List<KlineModel> allData;
  final List<double?> volMa5;
  final List<double?> volMa10;
  final ChartViewController viewController;

  final Paint _barPaint = Paint()..style = PaintingStyle.fill;
  final Paint _gridPaint = Paint()..color = AppColors.grid..strokeWidth = 0.5;

  VolumePainter({
    required this.allData,
    required this.viewController,
    this.volMa5 = const [],
    this.volMa10 = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (allData.isEmpty) return;

    final double plotWidth = size.width - 60.0;
    int startIdx = viewController.visibleStartIndex.clamp(0, allData.length);
    int endIdx = viewController.visibleEndIndex.clamp(0, allData.length);
    if (startIdx >= endIdx) return;

    // 计算成交量范围
    double maxVol = 0;
    for (int i = startIdx; i < endIdx; i++) {
      if (allData[i].volume > maxVol) maxVol = allData[i].volume;
    }
    
    // 考虑MA范围
    for (int i = startIdx; i < endIdx && i < volMa5.length; i++) {
      if (volMa5[i] != null && volMa5[i]! > maxVol) maxVol = volMa5[i]!;
    }
    for (int i = startIdx; i < endIdx && i < volMa10.length; i++) {
      if (volMa10[i] != null && volMa10[i]! > maxVol) maxVol = volMa10[i]!;
    }
    
    if (maxVol == 0) maxVol = 1;

    double getY(double vol) {
      return size.height - (vol / maxVol) * size.height * 0.9;
    }

    final step = viewController.step;
    final candleWidth = viewController.candleWidth;

    // 绘制网格
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(plotWidth, size.height * 0.5), _gridPaint);

    // 绘制成交量柱
    for (int i = 0; i < (endIdx - startIdx); i++) {
      int dataIdx = startIdx + i;
      final k = allData[dataIdx];
      final x = i * step + step / 2;
      final isUp = k.close >= k.open;
      final color = isUp ? AppColors.bullish : AppColors.bearish;

      _barPaint.color = color.withOpacity(0.7);
      canvas.drawRect(
        Rect.fromLTRB(x - candleWidth / 2, getY(k.volume), x + candleWidth / 2, size.height),
        _barPaint,
      );
    }

    // 绘制VOL MA线
    _drawLine(canvas, startIdx, endIdx, step, getY, volMa5,
        Paint()..color = AppColors.volMa5..strokeWidth = 1.0..style = PaintingStyle.stroke);
    _drawLine(canvas, startIdx, endIdx, step, getY, volMa10,
        Paint()..color = AppColors.volMa10..strokeWidth = 1.0..style = PaintingStyle.stroke);

    // 绘制标签
    final tp = TextPainter(textDirection: TextDirection.ltr);

    // 当前成交量
    String volLabel = '';
    if (endIdx > 0 && endIdx <= allData.length) {
      final vol = allData[endIdx - 1].volume;
      volLabel = _formatVolume(vol);
    }

    tp.text = TextSpan(children: [
      TextSpan(text: 'VOL:$volLabel ', style: const TextStyle(color: AppColors.textPrimary, fontSize: 10)),
      if (volMa5.isNotEmpty && endIdx > 0 && endIdx <= volMa5.length && volMa5[endIdx - 1] != null)
        TextSpan(text: 'MA5:${_formatVolume(volMa5[endIdx - 1]!)} ', style: const TextStyle(color: AppColors.volMa5, fontSize: 10)),
      if (volMa10.isNotEmpty && endIdx > 0 && endIdx <= volMa10.length && volMa10[endIdx - 1] != null)
        TextSpan(text: 'MA10:${_formatVolume(volMa10[endIdx - 1]!)}', style: const TextStyle(color: AppColors.volMa10, fontSize: 10)),
    ]);
    tp.layout();
    tp.paint(canvas, const Offset(5, 2));
  }

  void _drawLine(Canvas canvas, int startIdx, int endIdx, double step, double Function(double) getY, List<double?> data, Paint paint) {
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
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    if (started) canvas.drawPath(path, paint);
  }

  String _formatVolume(double vol) {
    if (vol >= 10000) return '${(vol / 10000).toStringAsFixed(2)}万';
    if (vol >= 1000) return '${(vol / 1000).toStringAsFixed(2)}K';
    return vol.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant VolumePainter old) => true;
}
