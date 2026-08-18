import '../../helpers/fixtures.dart';
import '../../helpers/isar_test_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rain/data/datasources/weather_local_datasource.dart';
import 'package:rain/data/repositories/weather_repository.dart';

void main() {
  late TestIsarContext ctx;
  late WeatherRepository repository;

  setUp(() async {
    ctx = await openTestIsar();
    final remote = createFakeWeatherRemoteDatasource();
    final local = WeatherLocalDatasource(ctx.isar);
    repository = WeatherRepository(remote, local);
  });

  tearDown(() async {});

  group('WeatherRepository', () {
    test('fetchWeather returns mapped cache from remote', () async {
      final weather = await repository.fetchWeather(55.75, 37.62);
      expect(weather.timezone, 'Europe/Moscow');
      expect(weather.temperature2M, isNotEmpty);
      expect(weather.europeanAqi, isNotEmpty);
    });

    test('writeCache and readCache round-trip', () async {
      final weather = sampleMainWeatherCache();
      final location = sampleLocationCache();

      await repository.writeCache(weather, location);
      final cached = await repository.readCache();

      expect(cached.weather, isNotNull);
      expect(cached.weather?.timePast, isNull);
      expect(cached.location?.city, 'Moscow');
      expect(cached.location?.address, 'Tverskaya Street 1, Moscow');
    });

    test('persists 15-minute precipitation forecasts for widgets', () async {
      final weather = sampleMainWeatherCache()
        ..timeMinutely15 = ['2026-06-05T12:00', '2026-06-05T12:15']
        ..precipitationMinutely15 = [0.0, 0.6]
        ..rainMinutely15 = [0.0, 0.6]
        ..showersMinutely15 = [0.0, 0.0]
        ..precipitationProbabilityMinutely15 = [10, 80];

      await repository.writeCache(weather, sampleLocationCache());
      final cached = await repository.readCache();

      expect(cached.weather?.timeMinutely15, weather.timeMinutely15);
      expect(
        cached.weather?.precipitationMinutely15,
        weather.precipitationMinutely15,
      );
      expect(cached.weather?.rainMinutely15, weather.rainMinutely15);
      expect(cached.weather?.showersMinutely15, weather.showersMinutely15);
      expect(
        cached.weather?.precipitationProbabilityMinutely15,
        weather.precipitationProbabilityMinutely15,
      );
    });

    test('persists previous-day temperatures for the hourly chart', () async {
      final weather = sampleMainWeatherCache()
        ..timePast = ['2026-06-04T23:00']
        ..temperature2MPast = [18.0];

      await repository.writeCache(weather, sampleLocationCache());
      final cached = await repository.readCache();

      expect(cached.weather?.timePast, ['2026-06-04T23:00']);
      expect(cached.weather?.temperature2MPast, [18.0]);
    });

    test('isCacheExpired reflects local datasource state', () async {
      await repository.writeCache(
        sampleMainWeatherCache()..timestamp = DateTime(2026, 6, 4),
        sampleLocationCache(),
      );

      expect(await repository.isCacheExpired(DateTime(2026, 6, 5)), isTrue);
    });

    test('clearMainAndLocation removes both caches', () async {
      await repository.writeCache(
        sampleMainWeatherCache(),
        sampleLocationCache(),
      );

      await repository.clearMainAndLocation();
      final cached = await repository.readCache();

      expect(cached.weather, isNull);
      expect(cached.location, isNull);
    });

    test('clearMainOnly keeps location', () async {
      await repository.writeCache(
        sampleMainWeatherCache(),
        sampleLocationCache(),
      );

      await repository.clearMainOnly();
      final cached = await repository.readCache();

      expect(cached.weather, isNull);
      expect(cached.location, isNotNull);
    });
  });
}
