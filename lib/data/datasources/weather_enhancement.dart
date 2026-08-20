import 'package:rain/data/models/db.dart';

/// 分钟级降水序列（聚合到 15 分钟槽之前仍保留原始语义）。
class MinutelyPrecipitation {
  const MinutelyPrecipitation({
    required this.times,
    required this.precipitation,
    this.rain,
  });

  /// 与 15 分钟模型槽对齐的 location-local naive 时间。
  final List<String> times;
  final List<double?> precipitation;

  /// 液态降水（雪归入 precipitation 但不计入 rain）。
  final List<double?>? rain;
}

/// 当前时刻实测快照（如中国区官方台站实况）。
class RealtimeWeatherSnapshot {
  const RealtimeWeatherSnapshot({
    this.temp,
    this.feelsLike,
    this.humidity,
    this.pressure,
    this.visibility,
    this.windSpeed,
    this.windDirection,
    this.dewPoint,
    this.precipitation,
    this.icon,
    this.cloudCover,
    this.obsTime,
  });

  final double? temp;
  final double? feelsLike;
  final int? humidity;
  final double? pressure;

  /// 米（调用方需完成单位换算）。
  final double? visibility;
  final double? windSpeed;
  final int? windDirection;
  final double? dewPoint;
  final double? precipitation;

  /// 本地天气 icon 码（映射后的 WMO 码由 mapper 完成）。
  final String? icon;
  final int? cloudCover;

  /// 观测时刻（location-local naive）。
  final String? obsTime;
}

/// 逐小时空气质量序列，与主预报时间轴对齐。
class AirQualitySeries {
  const AirQualitySeries({
    required this.times,
    this.usAqi,
    this.pm25,
    this.pm10,
    this.ozone,
    this.co,
    this.no2,
    this.so2,
  });

  /// 与主预报时间轴对齐前的 location-local naive 时间。
  final List<String> times;
  final List<double?>? usAqi;
  final List<double?>? pm25;
  final List<double?>? pm10;
  final List<double?>? ozone;
  final List<double?>? co;
  final List<double?>? no2;
  final List<double?>? so2;
}

/// 区域数据源对主预报数据的增强包。
class WeatherEnhancement {
  const WeatherEnhancement({
    this.minutely,
    this.realtime,
    this.airQuality,
    this.alerts,
  });

  final MinutelyPrecipitation? minutely;
  final RealtimeWeatherSnapshot? realtime;
  final AirQualitySeries? airQuality;
  final List<WeatherAlert>? alerts;
}

/// 区域数据增强器：探测主源在该区域的能力短板并并补强数据。
///
/// 增强层的失败语义是「静默跳过」——它必须不阻塞主数据源。
abstract class RegionalWeatherEnhancer {
  /// 是否能为该坐标提供增强。
  bool supports(double lat, double lon);

  /// 并行抓取增强数据（与主请求无关，可在主请求进行期间执行）。
  Future<WeatherEnhancement?> fetchEnhancement(double lat, double lon);

  /// 将已抓取的增强数据合并进主缓存。
  void merge(MainWeatherCache cache, WeatherEnhancement data);

  /// 将已抓取的增强数据合并进城市卡片。
  void mergeCard(WeatherCard card, WeatherEnhancement data);
}