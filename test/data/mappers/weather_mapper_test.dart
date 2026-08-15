import 'package:flutter_test/flutter_test.dart';
import 'package:rain/data/mappers/weather_mapper.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/data/models/weather_api.dart';

WeatherDataApi _sampleApi() => WeatherDataApi(
  hourly: const Hourly(
    time: ['2026-06-05T12:00'],
    weatherCode: [0],
    temperature2M: [20.0],
    relativeHumidity2M: [50],
  ),
  daily: Daily(
    time: [DateTime(2026, 6, 5)],
    weatherCode: [0],
    temperature2MMax: [25.0],
    temperature2MMin: [15.0],
    sunrise: ['06:00'],
    sunset: ['18:00'],
  ),
  timezone: 'Europe/Moscow',
  utcOffsetSeconds: 10800,
);

WeatherDataApi _sampleApiWithPastDay() => WeatherDataApi(
  hourly: const Hourly(
    time: [
      '2026-06-04T22:00',
      '2026-06-04T23:00',
      '2026-06-05T00:00',
      '2026-06-05T01:00',
    ],
    weatherCode: [1, 2, 3, 0],
    temperature2M: [18.0, 17.0, 16.0, 19.0],
  ),
  daily: Daily(
    time: [DateTime(2026, 6, 4), DateTime(2026, 6, 5)],
    weatherCode: [1, 0],
    temperature2MMax: [22.0, 25.0],
    temperature2MMin: [14.0, 15.0],
    sunrise: ['06:00', '06:00'],
    sunset: ['18:00', '18:00'],
  ),
  timezone: 'Europe/Moscow',
  utcOffsetSeconds: 10800,
);

void main() {
  group('WeatherMapper.toMainWeatherCache', () {
    test('maps hourly and daily fields', () {
      final cache = WeatherMapper.toMainWeatherCache(_sampleApi());

      expect(cache.time, ['2026-06-05T12:00']);
      expect(cache.temperature2M, [20.0]);
      expect(cache.weathercode, [0]);
      expect(cache.timeDaily, [DateTime(2026, 6, 5)]);
      expect(cache.timezone, 'Europe/Moscow');
      expect(cache.timestamp, isNotNull);
    });

    test('splits past-day hours into temperature2MPast', () {
      final cache = WeatherMapper.toMainWeatherCache(
        _sampleApiWithPastDay(),
        pastDays: 1,
      );

      expect(cache.time, ['2026-06-05T00:00', '2026-06-05T01:00']);
      expect(cache.temperature2M, [16.0, 19.0]);
      expect(cache.weathercode, [3, 0]);
      expect(cache.timePast, ['2026-06-04T22:00', '2026-06-04T23:00']);
      expect(cache.temperature2MPast, [18.0, 17.0]);
      expect(cache.timeDaily, [DateTime(2026, 6, 5)]);
    });

    test('keeps temperature2MPast null without past-day hours', () {
      final cache = WeatherMapper.toMainWeatherCache(_sampleApi());

      expect(cache.temperature2MPast, isNull);
    });
  });

  group('WeatherMapper.toWeatherCard', () {
    test('includes location metadata', () {
      final card = WeatherMapper.toWeatherCard(
        _sampleApi(),
        55.75,
        37.62,
        'Moscow',
        'Moscow Oblast',
      );

      expect(card.lat, 55.75);
      expect(card.lon, 37.62);
      expect(card.city, 'Moscow');
      expect(card.district, 'Moscow Oblast');
      expect(card.timezone, 'Europe/Moscow');
      expect(card.temperature2M, [20.0]);
    });
  });

  group('WeatherMapper.copyWeatherCardFields', () {
    test('copies forecast fields and refreshes timestamp', () {
      final oldCard = WeatherCard(city: 'Old')..temperature2M = [1.0];
      final updated = WeatherMapper.toWeatherCard(
        _sampleApi(),
        1,
        2,
        'New',
        'District',
      );

      WeatherMapper.copyWeatherCardFields(oldCard, updated);

      expect(oldCard.city, 'Old');
      expect(oldCard.temperature2M, [20.0]);
      expect(oldCard.timezone, 'Europe/Moscow');
      expect(oldCard.timestamp, isNotNull);
    });
  });
}
