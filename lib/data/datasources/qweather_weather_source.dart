import 'package:rain/core/utils/debug_log.dart';
import 'package:rain/data/datasources/qweather_api_client.dart';
import 'package:rain/data/datasources/weather_source.dart';
import 'package:rain/data/mappers/qweather_mapper.dart';
import 'package:rain/data/models/db.dart';

/// 和风天气完整数据源实现。
///
/// 数据维度受和风免费订阅限制：7 天逐日 + 24 小时逐小时 + 分钟降水
/// （仅中国大陆）+ 逐小时 AQI（监测站）+ 天气预警 + 城市搜索。
/// Open-Meteo 独有字段（蒸散/短波辐射/逐小时 UV 等）保持 null。
///
/// 凭据缺失时「快速失败」——release 构建由 CI 强校验保证凭据齐备。
class QWeatherWeatherSource implements WeatherSource {
  QWeatherWeatherSource({QWeatherApiClient? client})
      : _client = client ?? QWeatherApiClient();

  final QWeatherApiClient _client;

  @override
  Future<MainWeatherCache> fetchWeather(double lat, double lon) async {
    try {
      final results = await Future.wait<dynamic>([
        _client.weatherNow(lat, lon),
        _client.weather24h(lat, lon),
        _client.weather7d(lat, lon),
        _optional(() => _client.minutely5m(lat, lon)),
        _optional(() => _client.airHourly(lat, lon)),
      ]);
      return QWeatherMapper.toMainWeatherCache(
        now: results[0] as Map<String, dynamic>,
        hourly24: results[1] as Map<String, dynamic>,
        daily7: results[2] as Map<String, dynamic>,
        minutely5m: results[3] as Map<String, dynamic>?,
        airHourly: results[4] as Map<String, dynamic>?,
      );
    } catch (e, stackTrace) {
      debugLogError('QWeatherWeatherSource.fetchWeather', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<WeatherCard> fetchWeatherCard(
    double lat,
    double lon,
    String city,
    String district,
  ) async {
    final results = await Future.wait<dynamic>([
      _client.weatherNow(lat, lon),
      _client.weather24h(lat, lon),
      _client.weather7d(lat, lon),
      _optional(() => _client.airHourly(lat, lon)),
    ]);
    return QWeatherMapper.toWeatherCard(
      lat,
      lon,
      city,
      district,
      now: results[0] as Map<String, dynamic>,
      hourly24: results[1] as Map<String, dynamic>,
      daily7: results[2] as Map<String, dynamic>,
      airHourly: results[3] as Map<String, dynamic>?,
    );
  }

  @override
  Future<Iterable<CitySearchResult>> searchCities(
    String query,
    String? languageCode,
  ) async {
    final locations = await _client.searchCities(query, languageCode: languageCode);
    return locations.map(
      (e) => CitySearchResult(
        admin1: e['adm1'] as String?,
        name: e['name'] as String?,
        latitude: double.tryParse('${e['lat']}'),
        longitude: double.tryParse('${e['lon']}'),
      ),
    );
  }

  /// 可选数据失败不阻塞（和风多端点结构的固有语义）。
  static Future<Map<String, dynamic>?> _optional(
    Future<Map<String, dynamic>> Function() fetch,
  ) async {
    try {
      return await fetch();
    } catch (e, stackTrace) {
      debugLogError('QWeatherWeatherSource._optional', e, stackTrace);
      return null;
    }
  }
}