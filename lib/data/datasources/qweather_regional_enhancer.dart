import 'package:rain/core/utils/debug_log.dart';
import 'package:rain/data/datasources/qweather_api_client.dart';
import 'package:rain/data/datasources/weather_enhancement.dart';
import 'package:rain/data/mappers/qweather_mapper.dart';
import 'package:rain/data/models/db.dart';

/// 中国区增强器：用和风的官方台站实测、降水雷达和预警数据补强主源。
///
/// 增强失败静默跳过——分钟降水/AQI/预警各自独立请求，任一失败不影响
/// 其余增强和主数据。
class QWeatherRegionalEnhancer implements RegionalWeatherEnhancer {
  QWeatherRegionalEnhancer({QWeatherApiClient? client})
      : _client = client ?? QWeatherApiClient();

  final QWeatherApiClient _client;

  /// 中国大陆 bounding box 粗判（下限 15°N 覆盖海南与三沙）。
  /// 周边邻国坐标和风返回无数据，按失败静默处理。
  static const double _minLat = 15;
  static const double _maxLat = 54;
  static const double _minLon = 73;
  static const double _maxLon = 135;

  @override
  bool supports(double lat, double lon) =>
      lat >= _minLat && lat <= _maxLat && lon >= _minLon && lon <= _maxLon;

  @override
  Future<WeatherEnhancement?> fetchEnhancement(
    double lat,
    double lon,
  ) async {
    final results = await Future.wait<dynamic>([
      _safeFetch(() => _client.minutely5m(lat, lon)),
      _safeFetch(() => _client.weatherNow(lat, lon)),
      _safeFetch(() => _client.airHourly(lat, lon)),
      // 预警原文为中文官方权威文本，跟随源语言而非界面语言。
      _safeFetch(() => _client.warningNow(lat, lon, languageCode: 'zh')),
    ]);

    final minutely = results[0] == null
        ? null
        : QWeatherMapper.minutelyFrom5m(results[0] as Map<String, dynamic>);
    final realtime = results[1] == null
        ? null
        : QWeatherMapper.realtimeFromNow(results[1] as Map<String, dynamic>);
    final airQuality = results[2] == null
        ? null
        : QWeatherMapper.airQualityFromHourly(results[2] as Map<String, dynamic>);
    final alerts = results[3] == null
        ? null
        : QWeatherMapper.alertsFromWarning(results[3] as Map<String, dynamic>);

    if (minutely == null &&
        realtime == null &&
        airQuality == null &&
        alerts == null) {
      return null;
    }
    return WeatherEnhancement(
      minutely: minutely,
      realtime: realtime,
      airQuality: airQuality,
      alerts: alerts,
    );
  }

  @override
  void merge(MainWeatherCache cache, WeatherEnhancement data) {
    final minutely = data.minutely;
    if (minutely != null) QWeatherMapper.mergeMinutely(cache, minutely);
    final realtime = data.realtime;
    if (realtime != null) QWeatherMapper.mergeRealtime(cache, realtime);
    final airQuality = data.airQuality;
    if (airQuality != null) QWeatherMapper.mergeAirQuality(cache, airQuality);
    if (data.alerts != null) QWeatherMapper.mergeAlerts(cache, data.alerts);
  }

  @override
  void mergeCard(WeatherCard card, WeatherEnhancement data) {
    final realtime = data.realtime;
    if (realtime != null) QWeatherMapper.mergeRealtime(card, realtime);
    final airQuality = data.airQuality;
    if (airQuality != null) QWeatherMapper.mergeAirQuality(card, airQuality);
    if (data.alerts != null) QWeatherMapper.mergeAlerts(card, data.alerts);
  }

  static Future<Map<String, dynamic>?> _safeFetch(
    Future<Map<String, dynamic>> Function() fetch,
  ) async {
    try {
      return await fetch();
    } catch (e, stackTrace) {
      debugLogError('QWeatherRegionalEnhancer._safeFetch', e, stackTrace);
      return null;
    }
  }
}