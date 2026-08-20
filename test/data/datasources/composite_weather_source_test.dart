import 'package:flutter_test/flutter_test.dart';
import 'package:rain/data/datasources/composite_weather_source.dart';
import 'package:rain/data/datasources/weather_enhancement.dart';
import 'package:rain/data/datasources/weather_source.dart';
import 'package:rain/data/mappers/qweather_mapper.dart';
import 'package:rain/data/models/db.dart';

class _FakePrimary implements WeatherSource {
  final List<String> searchLog = [];
  ForecastBehavior behavior = ForecastBehavior.success;

  @override
  Future<MainWeatherCache> fetchWeather(double lat, double lon) async {
    switch (behavior) {
      case ForecastBehavior.success:
        return MainWeatherCache(
          time: ['2026-06-05T20:00', '2026-06-05T21:00'],
          weathercode: [2, 3],
          temperature2M: [28.0, 27.0],
          apparentTemperature: [30.0, 29.0],
          relativehumidity2M: [70, 72],
          timeMinutely15: ['2026-06-05T20:00'],
          precipitationMinutely15: [0.4],
          rainMinutely15: [0.4],
        );
      case ForecastBehavior.failure:
        throw Exception('primary failure');
    }
  }

  @override
  Future<WeatherCard> fetchWeatherCard(
    double lat,
    double lon,
    String city,
    String district,
  ) async {
    return WeatherCard(
      time: ['2026-06-05T20:00'],
      weathercode: [2],
      temperature2M: [28.0],
      lat: lat,
      lon: lon,
      city: city,
      district: district,
    );
  }

  @override
  Future<Iterable<CitySearchResult>> searchCities(
    String query,
    String? languageCode,
  ) async {
    searchLog.add(query);
    return const [CitySearchResult(admin1: 'A', name: 'Primary', latitude: 1, longitude: 2)];
  }
}

enum ForecastBehavior { success, failure }

class _FakeEnhancer implements RegionalWeatherEnhancer {
  _FakeEnhancer({
    this.supportedLat,
    this.failEnhancement = false,
  });

  final double? supportedLat;
  final bool failEnhancement;
  int fetchCount = 0;

  @override
  bool supports(double lat, double lon) =>
      supportedLat == null || lat == supportedLat;

  @override
  Future<WeatherEnhancement?> fetchEnhancement(double lat, double lon) async {
    fetchCount++;
    if (failEnhancement) throw Exception('enhancer failure');
    return WeatherEnhancement(
      realtime: RealtimeWeatherSnapshot(
        temp: 30.0,
        obsTime: '2026-06-05T20:00',
        icon: '100',
        windSpeed: 6.0,
        humidity: 40,
        pressure: 1000.0,
        visibility: 10.0,
        windDirection: 90,
        dewPoint: 10.0,
        precipitation: 0.0,
        cloudCover: 20,
      ),
      alerts: [
        WeatherAlert(title: '测试预警', severity: 'Severe', status: 'active'),
      ],
    );
  }

  @override
  void merge(MainWeatherCache cache, WeatherEnhancement data) {
    final realtime = data.realtime;
    if (realtime != null) QWeatherMapper.mergeRealtime(cache, realtime);
    if (data.alerts != null) QWeatherMapper.mergeAlerts(cache, data.alerts);
  }

  @override
  void mergeCard(WeatherCard card, WeatherEnhancement data) {
    final realtime = data.realtime;
    if (realtime != null) QWeatherMapper.mergeRealtime(card, realtime);
    if (data.alerts != null) QWeatherMapper.mergeAlerts(card, data.alerts);
  }
}


void main() {
  group('CompositeWeatherSource.fetchWeather', () {
    test('merges enhancement when the enhancer supports the coordinates',
        () async {
      final primary = _FakePrimary();
      final enhancer = _FakeEnhancer(supportedLat: 31.2);
      final composite = CompositeWeatherSource(
        primary: primary,
        enhancers: [enhancer],
      );

      final cache = await composite.fetchWeather(31.2, 121.5);

      expect(enhancer.fetchCount, 1);
      // 实测温度 30 覆盖当前槽
      expect(cache.temperature2M, [30.0, 27.0]);
      expect(cache.alerts, hasLength(1));
    });

    test('skips enhancers that do not support the coordinates', () async {
      final primary = _FakePrimary();
      final enhancer = _FakeEnhancer(supportedLat: 39.9);
      final composite = CompositeWeatherSource(
        primary: primary,
        enhancers: [enhancer],
      );

      final cache = await composite.fetchWeather(55.7, 37.6);

      expect(enhancer.fetchCount, 0);
      expect(cache.temperature2M, [28.0, 27.0]);
      expect(cache.alerts, isNull);
    });

    test('enhancer failure never blocks primary data', () async {
      final primary = _FakePrimary();
      final failing = _FakeEnhancer(supportedLat: 31.2, failEnhancement: true);
      final composite = CompositeWeatherSource(
        primary: primary,
        enhancers: [failing],
      );

      final cache = await composite.fetchWeather(31.2, 121.5);

      expect(cache.temperature2M, [28.0, 27.0]);
    });

    test('propagates primary failure', () async {
      final primary = _FakePrimary()..behavior = ForecastBehavior.failure;
      final composite = CompositeWeatherSource(
        primary: primary,
        enhancers: [_FakeEnhancer()],
      );

      expect(
        () => composite.fetchWeather(1, 2),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('CompositeWeatherSource.searchCities', () {
    test('routes CJK queries to the secondary source', () async {
      final primary = _FakePrimary();
      final secondary = _FakePrimary();
      final composite = CompositeWeatherSource(
        primary: primary,
        secondarySearch: secondary,
      );

      final results = await composite.searchCities('北京', 'zh');

      expect(secondary.searchLog, ['北京']);
      expect(primary.searchLog, isEmpty);
      expect(results.first.name, 'Primary');
    });

    test('routes latin queries to the primary source', () async {
      final primary = _FakePrimary();
      final secondary = _FakePrimary();
      final composite = CompositeWeatherSource(
        primary: primary,
        secondarySearch: secondary,
      );

      await composite.searchCities('Moscow', 'en');

      expect(primary.searchLog, ['Moscow']);
      expect(secondary.searchLog, isEmpty);
    });
  });
}