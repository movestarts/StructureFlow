import 'package:flutter/material.dart';
import '../../services/indicator_service.dart';
import '../../ui/theme/app_theme.dart';
import 'chart_view_controller.dart';

/// 通用副图画板（支持KDJ, RSI, WR等）
class SubChartPainter extends CustomPainter {
  final String label;
  final List<LineData> lines;
  final ChartViewController viewController;
  final int dataLength;
  final double? fixedMin;
  final double? fixedMax;
  final bool showZeroLine;

  final Paint _zeroPaint = Paint()..color = Colors.white24..strokeWidth = 0.5;
  final Paint _gridPaint = Paint()..color = AppColors.grid..strokeWidth = 0.5;

  SubChartPainter({
    required this.label,
    required this.lines,
    required this.viewController,
    required this.dataLength,
    this.fixedMin,
    this.fixedMax,
    this.showZeroLine = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

    final double plotWidth = size.width - 60.0;
    int startIdx = viewController.visibleStartIndex.clamp(0, dataLength);
    int endIdx = viewController.visibleEndIndex.clamp(0, dataLength);
    if (startIdx >= endIdx) return;

    // 计算范围
    double maxVal = fixedMax ?? -double.infinity;
    double minVal = fixedMin ?? double.infinity;

    if (fixedMax == null || fixedMin == null) {
      for (var line in lines) {
        for (int i = startIdx; i < endIdx && i < line.data.length; i++) {
          if (line.data[i] != null) {
            if (line.data[i]! > maxVal) maxVal = line.data[i]!;
            if (line.data[i]! < minVal) minVal = line.data[i]!;
          }
        }
      }
    }

    if (maxVal == -double.infinity || minVal == double.infinity) return;

    final range = maxVal - minVal;
    final margin = (range == 0 ? 1 : range) * 0.1;
    final top = maxVal + margin;
    final bottom = minVal - margin;
    final totalRange = top - bottom;

    double getY(double value) {
      return size.height - ((value - bottom) / totalRange) * size.height;
    }

    final step = viewController.step;

    // 参考线
    if (showZeroLine) {
      double zeroY = getY(0);
      canvas.drawLine(Offset(0, zeroY), Offset(plotWidth, zeroY), _zeroPaint);
    }

    // 网格线
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(plotWidth, size.height * 0.25), _gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(plotWidth, size.height * 0.75), _gridPaint);

    // 绘制所有线
    for (var line in lines) {
      _drawLine(canvas, startIdx, endIdx, step, getY, line.data,
          Paint()..color = line.color..strokeWidth = 1.0..style = PaintingStyle.stroke);
    }

    // 标签
    final tp = TextPainter(textDirection: TextDirection.ltr);
    List<TextSpan> spans = [
      TextSpan(text: '$label ', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ];

    for (var line in lines) {
      if (endIdx > 0 && endIdx <= line.data.length && line.data[endIdx - 1] != null) {
        spans.add(TextSpan(
          text: '${line.label}:${line.data[endIdx - 1]!.toStringAsFixed(2)} ',
          style: TextStyle(color: line.color, fontSize: 10),
        ));
      }
    }

    tp.text = TextSpan(children: spans);
    tp.layout();
    tp.paint(canvas, const Offset(5, 2));

    // 价格轴标签
    final axisTp = TextPainter(textDirection: TextDirection.ltr);
    for (double ratio in [0.0, 0.5, 1.0]) {
      double val = bottom + totalRange * ratio;
      double y = getY(val);
      axisTp.text = TextSpan(
        text: val.toStringAsFixed(1),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
      );
      axisTp.layout();
      axisTp.paint(canvas, Offset(plotWidth + 4, y - axisTp.height / 2));
    }
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
  bool shouldRepaint(covariant SubChartPainter old) {
    return old.label != label ||
        old.lines != lines ||
        old.dataLength != dataLength ||
        old.fixedMin != fixedMin ||
        old.fixedMax != fixedMax ||
        old.showZeroLine != showZeroLine ||
        old.viewController.visibleStartIndex != viewController.visibleStartIndex ||
        old.viewController.visibleEndIndex != viewController.visibleEndIndex ||
        old.viewController.step != viewController.step;
  }
}

/// 线数据
class LineData {
  final String label;
  final List<double?> data;
  final Color color;

  LineData(this.label, this.data, this.color);
}

/// 工厂方法

SubChartPainter createKDJPainter({
  required KDJResult kdjData,
  required ChartViewController viewController,
  required int dataLength,
}) {
  return SubChartPainter(
    label: 'KDJ(9,3,3)',
    lines: [
      LineData('K', kdjData.k, AppColors.ma5),
      LineData('D', kdjData.d, AppColors.dea),
      LineData('J', kdjData.j, AppColors.ma10),
    ],
    viewController: viewController,
    dataLength: dataLength,
    fixedMin: 0,
    fixedMax: 100,
  );
}

SubChartPainter createRSIPainter({
  required List<double?> rsiData,
  required ChartViewController viewController,
  required int dataLength,
}) {
  return SubChartPainter(
    label: 'RSI(14)',
    lines: [
      LineData('RSI', rsiData, AppColors.ma10),
    ],
    viewController: viewController,
    dataLength: dataLength,
    fixedMin: 0,
    fixedMax: 100,
  );
}

SubChartPainter createWRPainter({
  required List<double?> wrData,
  required ChartViewController viewController,
  required int dataLength,
}) {
  return SubChartPainter(
    label: 'WR(14)',
    lines: [
      LineData('WR', wrData, AppColors.ma5),
    ],
    viewController: viewController,
    dataLength: dataLength,
    fixedMin: -100,
    fixedMax: 0,
  );
}
