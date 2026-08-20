import 'package:flutter_test/flutter_test.dart';
import 'package:rain/data/mappers/qweather_mapper.dart';
import 'package:rain/data/models/db.dart';

Map<String, dynamic> _nowJson() => {
  'code': '200',
  'now': {
    'obsTime': '2026-06-05T20:00+08:00',
    'temp': '28',
    'feelsLike': '31',
    'icon': '100',
    'wind360': '90',
    'windDir': '东风',
    'windScale': '2',
    'windSpeed': '10',
    'humidity': '60',
    'precip': '0.0',
    'pressure': '1005',
    'vis': '20',
    'cloud': '10',
    'dew': '19',
  },
};

Map<String, dynamic> _hourlyJson() => {
  'code': '200',
  'hourly': [
    {
      'fxTime': '2026-06-05T20:00+08:00',
      'temp': '28',
      'icon': '101',
      'wind360': '90',
      'windSpeed': '10',
      'humidity': '60',
      'pop': '20',
      'precip': '0.0',
      'pressure': '1005',
      'cloud': '30',
      'dew': '19',
    },
    {
      'fxTime': '2026-06-05T21:00+08:00',
      'temp': '27',
      'icon': '305',
      'wind360': '90',
      'windSpeed': '12',
      'humidity': '65',
      'pop': '60',
      'precip': '1.2',
      'pressure': '1004',
      'cloud': '70',
      'dew': '20',
    },
  ],
};

Map<String, dynamic> _dailyJson() => {
  'code': '200',
  'daily': [
    {
      'fxDate': '2026-06-05',
      'sunrise': '05:30',
      'sunset': '19:30',
      'tempMax': '33',
      'tempMin': '24',
      'iconDay': '101',
      'textDay': '多云',
      'wind360Day': '90',
      'windSpeedDay': '14',
      'humidity': '55',
      'precip': '0.0',
      'pressure': '1003',
      'vis': '25',
      'cloud': '40',
      'uvIndex': '8',
    },
  ],
};

Map<String, dynamic> _minutelyJson() => {
  'code': '200',
  'minutely': [
    {'fxTime': '2026-06-05T20:00+08:00', 'precip': '0.1', 'type': 'rain'},
    {'fxTime': '2026-06-05T20:05+08:00', 'precip': '0.2', 'type': 'rain'},
    {'fxTime': '2026-06-05T20:10+08:00', 'precip': '0.3', 'type': 'rain'},
    {'fxTime': '2026-06-05T20:15+08:00', 'precip': '0.4', 'type': 'snow'},
    {'fxTime': '2026-06-05T20:20+08:00', 'precip': '0.5', 'type': 'snow'},
    {'fxTime': '2026-06-05T20:25+08:00', 'precip': '0.6', 'type': 'snow'},
  ],
};

Map<String, dynamic> _airQualityJson() => {
  'code': '200',
  'hours': [
    {
      'forecastTime': '2026-06-05T12:00Z',
      'indexes': [
        {'code': 'cn-mee', 'aqi': 120.0},
        {'code': 'us-epa', 'aqi': 75.0},
      ],
      'pollutants': [
        {
          'code': 'pm2p5',
          'concentration': {'value': 55.0, 'unit': 'µg/m3'},
        },
        {
          'code': 'pm10',
          'concentration': {'value': 98.0, 'unit': 'µg/m3'},
        },
        {
          'code': 'o3',
          'concentration': {'value': 102.0, 'unit': 'µg/m3'},
        },
        {
          'code': 'co',
          'concentration': {'value': 0.8, 'unit': 'µg/m3'},
        },
        {
          'code': 'no2',
          'concentration': {'value': 40.0, 'unit': 'µg/m3'},
        },
        {
          'code': 'so2',
          'concentration': {'value': 12.0, 'unit': 'µg/m3'},
        },
      ],
    },
  ],
};

Map<String, dynamic> _warningJson() => {
  'code': '200',
  'warning': [
    {
      'id': '1',
      'sender': '北京市气象局',
      'pubTime': '2026-06-05T10:00+08:00',
      'title': '大风蓝色预警',
      'startTime': '2026-06-05T12:00+08:00',
      'endTime': '2026-06-06T12:00+08:00',
      'status': 'active',
      'level': '蓝色',
      'severity': 'Minor',
      'severityColor': 'Blue',
      'typeName': '大风',
      'text': '请注意防风。',
    },
    {
      'id': '2',
      'title': '已解除的预警',
      'status': 'update',
      'severity': 'Moderate',
    },
  ],
};

void main() {
  group('QWeatherMapper icon 映射', () {
    test('maps common and night icons to WMO codes', () {
      expect(QWeatherMapper.iconToWmo('100'), 0);
      expect(QWeatherMapper.iconToWmo('104'), 3);
      expect(QWeatherMapper.iconToWmo('302'), 95);
      expect(QWeatherMapper.iconToWmo('305'), 61);
      expect(QWeatherMapper.iconToWmo('500'), 45);
      expect(QWeatherMapper.iconToWmo('150'), 0);
      expect(QWeatherMapper.iconToWmo('nonexistent'), isNull);
    });
  });

  group('QWeatherMapper 时间转换', () {
    test('converts offset ISO to naive local time', () {
      expect(
        QWeatherMapper.toNaiveLocal('2026-06-05T20:00+08:00'),
        '2026-06-05T20:00',
      );
    });

    test('converts UTC ISO with target offset', () {
      expect(
        QWeatherMapper.toNaiveLocal('2026-06-05T12:00Z', utcOffsetSeconds: 28800),
        '2026-06-05T20:00',
      );
    });
  });

  group('QWeatherMapper.toMainWeatherCache', () {
    test('maps hourly and daily fields with unit conversion', () {
      final cache = QWeatherMapper.toMainWeatherCache(
        now: _nowJson(),
        hourly24: _hourlyJson(),
        daily7: _dailyJson(),
        minutely5m: _minutelyJson(),
        airHourly: _airQualityJson(),
      );

      expect(cache.time, ['2026-06-05T20:00', '2026-06-05T21:00']);
      expect(cache.weathercode, [1, 61]);
      expect(cache.temperature2M, [28.0, 27.0]);
      expect(cache.precipitationProbability, [20, 60]);
      expect(cache.timeDaily, [DateTime(2026, 6, 5)]);
      expect(cache.sunrise, ['05:30']);
      expect(cache.uvIndexMax, [8.0]);
      expect(cache.utcOffsetSeconds, 28800);
    });

    test('aggregates 5-minute precipitation into 15-minute slots', () {
      final cache = QWeatherMapper.toMainWeatherCache(
        now: _nowJson(),
        hourly24: _hourlyJson(),
        daily7: _dailyJson(),
        minutely5m: _minutelyJson(),
      );

      expect(cache.timeMinutely15, ['2026-06-05T20:00', '2026-06-05T20:15']);
      expect(cache.precipitationMinutely15, [0.6, 1.5]);
      // snow 不计入液态降水
      expect(cache.rainMinutely15, [0.6, 0.0]);
    });

    test('merges air quality aligned to hourly slots', () {
      final cache = QWeatherMapper.toMainWeatherCache(
        now: _nowJson(),
        hourly24: _hourlyJson(),
        daily7: _dailyJson(),
        airHourly: _airQualityJson(),
      );

      // AQI 时间 12:00Z + 8h = 20:00 本地，与第一个小时槽对齐
      expect(cache.usAqi, [75.0, null]);
      expect(cache.pm25, [55.0, null]);
      expect(cache.co, [0.8, null]);
    });

    test('real-time snapshot replaces the matching hour slot', () {
      final cache = QWeatherMapper.toMainWeatherCache(
        now: _nowJson(),
        hourly24: _hourlyJson(),
        daily7: _dailyJson(),
      );
      final realtime = QWeatherMapper.realtimeFromNow(_nowJson())!;

      QWeatherMapper.mergeRealtime(cache, realtime);

      expect(cache.temperature2M, [28.0, 27.0]);
      expect(cache.relativehumidity2M, [60, 65]);
      expect(cache.weathercode, [0, 61]);
      // 和风能见度 km → m
      expect(cache.visibility, [20000.0, null]);
    });

    test('parses active alerts and drops inactive ones', () {
      final alerts = QWeatherMapper.alertsFromWarning(_warningJson());
      expect(alerts, isNotNull);
      expect(alerts!.length, 1);
      expect(alerts.first.title, '大风蓝色预警');
      expect(alerts.first.severity, 'Minor');
      // 预警时间以 UTC 存储（2026-06-06T12:00+08:00 = 04:00Z），
      // 过期判断与设备/地点时区无关。
      expect(alerts.first.endTime, DateTime.utc(2026, 6, 6, 4));
    });
  });

  group('QWeatherMapper 时间对齐细节', () {
    test('mergeMinutely 仅在主源缺失分钟降水时补充', () {
      final cache = MainWeatherCache(
        time: ['2026-06-05T20:00'],
        timeMinutely15: ['2026-06-05T20:00'],
        precipitationMinutely15: [0.5],
      );
      final minutely = QWeatherMapper.minutelyFrom5m(_minutelyJson())!;

      QWeatherMapper.mergeMinutely(cache, minutely);

      // 主源已有数据：保持原值
      expect(cache.precipitationMinutely15, [0.5]);
    });
  });

  group('MinutelyPrecipitation DTO', () {
    test('minutelyFrom5m returns null for empty payload', () {
      expect(QWeatherMapper.minutelyFrom5m({'minutely': []}), isNull);
    });
  });
}