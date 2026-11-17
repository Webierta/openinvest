import 'package:material_ui/material_ui.dart';

class HistoryChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;

  HistoryChartPainter(
    this.values, {
    this.lineColor = const Color(0xFF64C8F5),
    this.fillColor = const Color(0x554FC3F7),
    this.strokeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    final sampled = <double>[];
    final step = (values.length - 1) / 49;

    for (var i = 0; i < 50; i++) {
      sampled.add(values[(i * step).round()]);
    }

    final minValue = sampled.reduce((a, b) => a < b ? a : b);
    final maxValue = sampled.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;

    final points = <Offset>[];

    for (var i = 0; i < sampled.length; i++) {
      final x = size.width * i / (sampled.length - 1);
      final normalized = range == 0 ? 0.5 : (sampled[i] - minValue) / range;
      final y = size.height - 5 - normalized * (size.height - 10);

      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: .topCenter,
          end: .bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant HistoryChartPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.values.length != values.length) {
      return true;
    }

    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }

    return false;
  }
}
