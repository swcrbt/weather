import 'package:latlong2/latlong.dart';

/// 和风空气质量监测站（真实台站实测）。
class AqiStation {
  const AqiStation({
    required this.id,
    required this.name,
    required this.position,
    required this.aqi,
    this.pm25,
    this.pm10,
  });

  /// 和风监测站 LocationID（如 P58911）。
  final String id;

  /// 监测站名称（跟随接口语言）。
  final String name;

  /// 监测站坐标（GeoAPI 按 LocationID 反查）。
  final LatLng position;

  /// 由实测 PM2.5/PM10 按 US EPA 断点计算的 AQI。
  final double aqi;

  /// 实测 PM2.5 浓度（µg/m³）。
  final double? pm25;

  /// 实测 PM10 浓度（µg/m³）。
  final double? pm10;
}
