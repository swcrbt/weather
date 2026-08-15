import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the current and previous-day temperature curves of the hourly chart.
///
/// The current curve is a smoothed solid line with a gradient fill; the
/// previous-day curve (temperature 24 h earlier per slot) is dashed. The
/// selected slot gets a vertical indicator line and a dot on the curve.
class HourlyTemperaturePainter extends CustomPainter {
  const HourlyTemperaturePainter({
    required this.temperatures,
    required this.previousDay,
    required this.slotWidth,
    required this.selectedIndex,
    required this.lineColor,
    required this.previousColor,
    required this.fillColor,
    required this.ringColor,
    required this.gridColor,
  });

  /// Current temperature per visible hour slot (nulls break the curve).
  final List<double?> temperatures;

  /// Temperature 24 h earlier per visible hour slot.
  final List<double?> previousDay;
  final double slotWidth;
  final int selectedIndex;
  final Color lineColor;
  final Color previousColor;
  final Color fillColor;
  final Color ringColor;
  final Color gridColor;

  static const double _verticalPadding = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _bounds();
    if (bounds == null) return;
    final min = bounds.$1;
    final max = bounds.$2;
    final span = max - min == 0 ? 1.0 : max - min;

    double xAt(int i) => i * slotWidth + slotWidth / 2;
    double yAt(double v) =>
        _verticalPadding +
        (size.height - _verticalPadding * 2) * (1 - (v - min) / span);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= temperatures.length; i++) {
      final x = i * slotWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Previous-day dashed curve underneath the current one.
    final dashPaint = Paint()
      ..color = previousColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final run in _runs(previousDay)) {
      _drawDashed(canvas, _curvePath(run, xAt, yAt), dashPaint);
    }

    // Current curve with gradient fill towards the chart bottom.
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final run in _runs(temperatures)) {
      canvas.drawPath(_fillPath(run, size, xAt, yAt), fillPaint);
      canvas.drawPath(_curvePath(run, xAt, yAt), linePaint);
    }

    _drawSelection(canvas, size, xAt, yAt);
  }

  /// Vertical indicator line plus a dot on the current curve.
  void _drawSelection(
    Canvas canvas,
    Size size,
    double Function(int) xAt,
    double Function(double) yAt,
  ) {
    if (selectedIndex < 0 || selectedIndex >= temperatures.length) return;
    final x = xAt(selectedIndex);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = lineColor.withValues(alpha: 0.45)
        ..strokeWidth = 1.5,
    );
    final value = temperatures[selectedIndex];
    if (value == null) return;
    canvas.drawCircle(Offset(x, yAt(value)), 6, Paint()..color = ringColor);
    canvas.drawCircle(Offset(x, yAt(value)), 3.5, Paint()..color = lineColor);
  }

  /// Min/max across both series, or null when no values exist.
  (double, double)? _bounds() {
    double? min;
    double? max;
    for (final list in [temperatures, previousDay]) {
      for (final value in list) {
        if (value == null) continue;
        min = min == null ? value : math.min(min, value);
        max = max == null ? value : math.max(max, value);
      }
    }
    if (min == null || max == null) return null;
    return (min, max);
  }

  /// Consecutive non-null runs as (index, value) lists.
  List<List<(int, double)>> _runs(List<double?> values) {
    final runs = <List<(int, double)>>[];
    var current = <(int, double)>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        if (current.length >= 2) runs.add(current);
        current = <(int, double)>[];
      } else {
        current.add((i, value));
      }
    }
    if (current.length >= 2) runs.add(current);
    return runs;
  }

  /// Smoothed curve through [run] using midpoint quadratic segments.
  Path _curvePath(
    List<(int, double)> run,
    double Function(int) xAt,
    double Function(double) yAt,
  ) {
    final path = Path();
    path.moveTo(xAt(run.first.$1), yAt(run.first.$2));
    _appendCurve(path, run, xAt, yAt);
    return path;
  }

  /// Closed area between the curve and the chart bottom for the fill.
  Path _fillPath(
    List<(int, double)> run,
    Size size,
    double Function(int) xAt,
    double Function(double) yAt,
  ) {
    final path = Path();
    path.moveTo(xAt(run.first.$1), size.height);
    path.lineTo(xAt(run.first.$1), yAt(run.first.$2));
    _appendCurve(path, run, xAt, yAt);
    path.lineTo(xAt(run.last.$1), size.height);
    path.close();
    return path;
  }

  /// Appends midpoint quadratic segments after the current path point.
  void _appendCurve(
    Path path,
    List<(int, double)> run,
    double Function(int) xAt,
    double Function(double) yAt,
  ) {
    for (var i = 1; i < run.length; i++) {
      final px = xAt(run[i - 1].$1);
      final py = yAt(run[i - 1].$2);
      final cx = xAt(run[i].$1);
      final cy = yAt(run[i].$2);
      path.quadraticBezierTo(px, py, (px + cx) / 2, (py + cy) / 2);
    }
    path.lineTo(xAt(run.last.$1), yAt(run.last.$2));
  }

  /// Strokes [path] as 4 px dashes separated by 4 px gaps.
  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 4, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HourlyTemperaturePainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.slotWidth != slotWidth ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.previousColor != previousColor ||
      oldDelegate.gridColor != gridColor ||
      !identical(oldDelegate.temperatures, temperatures) ||
      !identical(oldDelegate.previousDay, previousDay);
}

/// Small solid or dashed line sample for the chart legend.
class LineSamplePainter extends CustomPainter {
  const LineSamplePainter({required this.color, this.dashed = false});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 4, size.width), y),
        paint,
      );
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant LineSamplePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
