import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the current and previous-day temperature curves of the hourly chart.
///
/// The current curve is a smoothed solid line with a gradient fill, a hollow
/// dot per hour and a temperature label above each dot; the previous-day
/// curve (temperature 24 h earlier per slot) is dashed. The selected slot
/// gets a filled dot with a surface-colored ring.
class HourlyTemperaturePainter extends CustomPainter {
  const HourlyTemperaturePainter({
    required this.temperatures,
    required this.previousDay,
    required this.labels,
    required this.slotWidth,
    required this.selectedIndex,
    required this.lineColor,
    required this.previousColor,
    required this.fillColor,
    required this.ringColor,
    required this.labelColor,
  });

  /// Current temperature per visible hour slot (nulls break the curve).
  final List<double?> temperatures;

  /// Temperature 24 h earlier per visible hour slot.
  final List<double?> previousDay;

  /// Formatted temperature label per visible hour slot (null hides it).
  final List<String?> labels;

  final double slotWidth;
  final int selectedIndex;
  final Color lineColor;
  final Color previousColor;
  final Color fillColor;
  final Color ringColor;
  final Color labelColor;

  static const double _topPadding = 26;
  static const double _bottomPadding = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _bounds();
    if (bounds == null) return;
    final min = bounds.$1;
    final max = bounds.$2;
    final span = max - min == 0 ? 1.0 : max - min;

    double xAt(int i) => i * slotWidth + slotWidth / 2;
    double yAt(double v) =>
        _topPadding +
        (size.height - _topPadding - _bottomPadding) * (1 - (v - min) / span);

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

    _drawDots(canvas, xAt, yAt);
    _drawLabels(canvas, xAt, yAt);
  }

  /// A dot per hour: hollow on the line, filled with a ring when selected.
  void _drawDots(
    Canvas canvas,
    double Function(int) xAt,
    double Function(double) yAt,
  ) {
    for (var i = 0; i < temperatures.length; i++) {
      final value = temperatures[i];
      if (value == null) continue;
      final center = Offset(xAt(i), yAt(value));
      if (i == selectedIndex) {
        canvas.drawCircle(center, 6, Paint()..color = ringColor);
        canvas.drawCircle(center, 3.5, Paint()..color = lineColor);
      } else {
        canvas.drawCircle(center, 4, Paint()..color = ringColor);
        canvas.drawCircle(
          center,
          4,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  /// Temperature text centered above each dot.
  void _drawLabels(
    Canvas canvas,
    double Function(int) xAt,
    double Function(double) yAt,
  ) {
    for (var i = 0; i < temperatures.length; i++) {
      final value = temperatures[i];
      final label = i < labels.length ? labels[i] : null;
      if (value == null || label == null) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = xAt(i);
      final y = yAt(value);
      painter.paint(
        canvas,
        Offset(x - painter.width / 2, y - 10 - painter.height),
      );
    }
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
      oldDelegate.fillColor != fillColor ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.labelColor != labelColor ||
      !identical(oldDelegate.temperatures, temperatures) ||
      !identical(oldDelegate.previousDay, previousDay) ||
      !identical(oldDelegate.labels, labels);
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
