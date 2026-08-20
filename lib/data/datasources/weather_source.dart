import 'package:rain/data/models/db.dart';

/// 天气数据源抽象：所有天气数据提供方的统一入口。
///
/// 业务层只依赖此接口，不感知具体实现，方便后续替换或新增数据源。
abstract class WeatherSource {
  /// Fetches a fresh main weather forecast for the given coordinates.
  Future<MainWeatherCache> fetchWeather(double lat, double lon);

  /// Fetches a forecast mapped to a city weather card with location metadata.
  Future<WeatherCard> fetchWeatherCard(
    double lat,
    double lon,
    String city,
    String district,
  );

  /// Searches geocoding data for up to five matching cities.
  Future<Iterable<CitySearchResult>> searchCities(
    String query,
    String? languageCode,
  );
}

/// A normalized city match returned from geocoding search.
class CitySearchResult {
  const CitySearchResult({
    required this.admin1,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String? admin1;
  final String? name;
  final double? latitude;
  final double? longitude;
}