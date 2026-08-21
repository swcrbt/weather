import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 视野内规则网格上的逐小时 AQI 采样（Open-Meteo CAMS 多坐标批量查询结果）。
///
/// 数据按「时间 × 行 × 列」扁平存储，缺测点为 null。时间统一为 UTC 整点。
class AqiGrid {
  const AqiGrid({
    required this.bounds,
    required this.rows,
    required this.cols,
    required this.times,
    required this.europeanAqi,
    required this.usAqi,
    required this.pm25,
    required this.pm10,
  });

  final LatLngBounds bounds;
  final int rows;
  final int cols;

  /// 逐小时 UTC 时间戳（秒）。
  final List<int> times;

  /// 各变量按 timeIndex * rows * cols + row * cols + col 扁平存储。
  final List<double?> europeanAqi;
  final List<double?> usAqi;
  final List<double?> pm25;
  final List<double?> pm10;

  int get frameCount => times.length;

  int get _cellCount => rows * cols;

  double? _valueAt(List<double?> values, int timeIndex, int row, int col) {
    if (timeIndex < 0 || timeIndex >= frameCount) return null;
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return values[timeIndex * _cellCount + row * cols + col];
  }

  /// 距离 [time] 最近（不晚于其）的帧索引；无有效帧时返回最后一帧。
  int frameIndexFor(DateTime time) {
    if (times.isEmpty) return 0;
    final target = time.toUtc().millisecondsSinceEpoch ~/ 1000;
    var index = 0;
    for (var i = 0; i < times.length; i++) {
      if (times[i] <= target) index = i;
    }
    return index;
  }

  /// 对 [point] 在 [timeIndex] 帧做双线性插值；样本不足时退化为最近点。
  double? sampleAqi(String standard, int timeIndex, LatLng point) {
    final values = standard == 'american' ? usAqi : europeanAqi;
    return _sample(values, timeIndex, point);
  }

  /// 双线性插值污染物浓度（供扩展，当前热力图只用 AQI）。
  double? samplePm25(int timeIndex, LatLng point) =>
      _sample(pm25, timeIndex, point);

  double? samplePm10(int timeIndex, LatLng point) =>
      _sample(pm10, timeIndex, point);

  double? _sample(List<double?> values, int timeIndex, LatLng point) {
    final latSpan = bounds.north - bounds.south;
    final lonSpan = bounds.east - bounds.west;
    if (latSpan <= 0 || lonSpan <= 0 || rows < 2 || cols < 2) {
      return _nearest(values, timeIndex, point);
    }

    final fy = ((bounds.north - point.latitude) / latSpan * (rows - 1)).clamp(
      0.0,
      rows - 1.0,
    );
    final fx = ((point.longitude - bounds.west) / lonSpan * (cols - 1)).clamp(
      0.0,
      cols - 1.0,
    );
    final r0 = fy.floor();
    final c0 = fx.floor();
    final r1 = min(r0 + 1, rows - 1);
    final c1 = min(c0 + 1, cols - 1);
    final ty = fy - r0;
    final tx = fx - c0;

    final q00 = _valueAt(values, timeIndex, r0, c0);
    final q01 = _valueAt(values, timeIndex, r0, c1);
    final q10 = _valueAt(values, timeIndex, r1, c0);
    final q11 = _valueAt(values, timeIndex, r1, c1);

    // 缺测角点用已有值填充；全部缺测时返回 null（热力图留空）。
    final samples = [q00, q01, q10, q11];
    final fallback =
        samples.whereType<double>().fold<double>(0, (sum, v) => sum + v) /
        max(samples.whereType<double>().length, 1);
    if (samples.every((v) => v == null)) return null;
    final v00 = q00 ?? fallback;
    final v01 = q01 ?? fallback;
    final v10 = q10 ?? fallback;
    final v11 = q11 ?? fallback;

    final top = v00 + (v01 - v00) * tx;
    final bottom = v10 + (v11 - v10) * tx;
    return top + (bottom - top) * ty;
  }

  double? _nearest(List<double?> values, int timeIndex, LatLng point) {
    final latStep = rows > 1 ? (bounds.north - bounds.south) / (rows - 1) : 0;
    final lonStep = cols > 1 ? (bounds.east - bounds.west) / (cols - 1) : 0;
    final row = latStep > 0
        ? ((bounds.north - point.latitude) / latStep).round().clamp(0, rows - 1)
        : 0;
    final col = lonStep > 0
        ? ((point.longitude - bounds.west) / lonStep).round().clamp(0, cols - 1)
        : 0;
    return _valueAt(values, timeIndex, row, col);
  }

  /// 网格点 [row]/[col] 的地理坐标。
  LatLng pointAt(int row, int col) {
    final lat = rows > 1
        ? bounds.north - (bounds.north - bounds.south) * row / (rows - 1)
        : (bounds.north + bounds.south) / 2;
    final lon = cols > 1
        ? bounds.west + (bounds.east - bounds.west) * col / (cols - 1)
        : (bounds.west + bounds.east) / 2;
    return LatLng(lat, lon);
  }
}

/// 视野量化后的网格查询键（family 参数，值相等即可命中缓存）。
class AqiGridQuery {
  const AqiGridQuery({
    required this.north,
    required this.south,
    required this.west,
    required this.east,
  });

  /// 以 0.25° 为粒度量化，缓慢平移时复用缓存。
  factory AqiGridQuery.fromBounds(LatLngBounds bounds) {
    double q(double v) => (v / 0.25).round() * 0.25;
    return AqiGridQuery(
      north: q(bounds.north),
      south: q(bounds.south),
      west: q(bounds.west),
      east: q(bounds.east),
    );
  }

  final double north;
  final double south;
  final double west;
  final double east;

  LatLngBounds get bounds =>
      LatLngBounds(LatLng(south, west), LatLng(north, east));

  @override
  bool operator ==(Object other) =>
      other is AqiGridQuery &&
      other.north == north &&
      other.south == south &&
      other.west == west &&
      other.east == east;

  @override
  int get hashCode => Object.hash(north, south, west, east);
}
