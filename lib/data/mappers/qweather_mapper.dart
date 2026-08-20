import 'package:rain/core/weather/time_index_helper.dart';
import 'package:rain/data/datasources/weather_enhancement.dart';
import 'package:rain/data/models/db.dart';

/// 将和风 API 响应映射为项目内部缓存模型。
///
/// 覆盖两条路径：
/// - 完整数据源：now/24h/7d/minutely/airquality → [MainWeatherCache] / [WeatherCard]；
/// - 区域增强：实况/分钟降水/AQI/预警 → 就地合并进主源数据。
class QWeatherMapper {
  QWeatherMapper._();

  // ---------------------------------------------------------------
  // 数值与时间工具
  // ---------------------------------------------------------------

  static double? _doubleOf(Object? value) =>
      value == null ? null : double.tryParse('$value');

  static int? _intOf(Object? value) =>
      value == null ? null : int.tryParse('$value');

  /// 从带 offset 的 ISO8601 字符串（`...+08:00`）提取 offset 秒数。
  static int offsetSecondsOf(String iso) {
    final match = RegExp(r'([+-])(\d{2}):(\d{2})$').firstMatch(iso);
    if (match == null) return 0;
    final sign = match.group(1) == '-' ? -1 : 1;
    return sign *
        (int.parse(match.group(2)!) * 3600 + int.parse(match.group(3)!) * 60);
  }

  /// 转成 location-local naive 时间字符串 `YYYY-MM-DDTHH:mm`。
  ///
  /// Dart 的 DateTime.parse 对带 offset 和 `Z` 的字符串都返回 UTC 对象。
  /// iso 自带 offset（如 `+08:00`）时以 iso 为准；`Z` 结尾（如和风 AQI 的
  /// forecastTime）时用 [utcOffsetSeconds]（地点 offset）转回本地墙钟。
  static String toNaiveLocal(String iso, {int utcOffsetSeconds = 0}) {
    final parsed = DateTime.parse(iso);
    final offset = offsetSecondsOf(iso);
    final effectiveOffset = offset != 0 ? offset : utcOffsetSeconds;
    final local = parsed.add(Duration(seconds: effectiveOffset));
    return _format(_roundToMinute(local));
  }

  static DateTime _roundToMinute(DateTime value) =>
      DateTime(value.year, value.month, value.day, value.hour, value.minute);

  static String _format(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min';
  }

  // ---------------------------------------------------------------
  // 天气 icon 码 → WMO weathercode
  // ---------------------------------------------------------------

  static const Map<String, int> _iconToWmo = {
    // 白天晴到阴
    '100': 0, // 晴
    '101': 1, // 多云
    '102': 2, // 少云
    '103': 2, // 晴间多云
    '104': 3, // 阴
    // 夜间对应码
    '150': 0,
    '151': 1,
    '152': 2,
    '153': 2,
    '154': 3,
    // 雨
    '130': 81, // 太阳雨
    '300': 80, // 阵雨
    '301': 81, // 强阵雨
    '302': 95, // 雷阵雨
    '303': 96, // 强雷阵雨
    '304': 96, // 雷阵雨伴有冰雹
    '305': 61, // 小雨
    '306': 63, // 中雨
    '307': 65, // 大雨
    '308': 65, // 极端降雨
    '309': 51, // 毛毛雨/细雨
    '310': 65, // 暴雨
    '311': 65, // 大暴雨
    '312': 65, // 特大暴雨
    '313': 66, // 冻雨
    '314': 63, // 小到中雨
    '315': 63, // 中到大雨
    '316': 65, // 大到暴雨
    '317': 65, // 暴雨到大暴雨
    '318': 65, // 大暴雨到特大暴雨
    '350': 80, // 阵雨
    '351': 81, // 强阵雨
    '399': 63, // 雨
    // 雪
    '400': 71, // 小雪
    '401': 73, // 中雪
    '402': 75, // 大雪
    '403': 75, // 暴雪
    '404': 68, // 雨夹雪
    '405': 85, // 阵雪
    '406': 73, // 小到中雪
    '407': 75, // 中到大雪
    '408': 75, // 大到暴雪
    '409': 75, // 极端天气（雪）
    '456': 68, // 雨夹雪
    '457': 85, // 阵雪
    '499': 73, // 雪
    // 雾/霾
    '500': 45, // 雾
    '501': 48, // 雾凇
    '502': 45, // 浓雾
    '509': 45, // 霾
    '510': 45, // 中度霾
    '511': 45, // 重度霾
    '512': 45, // 严重霾
    '513': 45, // 大雾
    '514': 45, // 特强浓雾
    '515': 45, // 浓雾
    // 其他极端与未知
    '900': 0, // 热
    '901': 0, // 冷
    '999': 3,
  };

  /// 和风 icon 码 → WMO weathercode；无法映射时返回 null。
  static int? iconToWmo(String? icon) => _iconToWmo[icon];

  // ---------------------------------------------------------------
  // 完整数据源映射
  // ---------------------------------------------------------------

  /// Builds a main weather cache from QWeather now/24h/7d/minutely/AQ responses.
  static MainWeatherCache toMainWeatherCache({
    required Map<String, dynamic> now,
    required Map<String, dynamic> hourly24,
    required Map<String, dynamic> daily7,
    Map<String, dynamic>? minutely5m,
    Map<String, dynamic>? airHourly,
  }) {
    final hours = _asList(hourly24['hourly']);
    final days = _asList(daily7['daily']);

    var offset = 0;
    if (hours.isNotEmpty) {
      final firstFxTime = '${_asMap(hours.first)['fxTime'] ?? ''}';
      if (firstFxTime.isNotEmpty) offset = offsetSecondsOf(firstFxTime);
    }

    final times = <String>[];
    final weathercode = <int>[];
    final temperature2M = <double>[];
    final relativehumidity2M = <int?>[];
    final precipitation = <double?>[];
    final surfacePressure = <double?>[];
    final windspeed10M = <double?>[];
    final winddirection10M = <int?>[];
    final cloudcover = <int?>[];
    final dewpoint2M = <double?>[];
    final precipitationProbability = <int?>[];

    for (final raw in hours) {
      final h = _asMap(raw);
      final fxTime = '${h['fxTime'] ?? ''}';
      if (fxTime.isEmpty) continue;
      final icon = iconToWmo('${h['icon']}');
      // 无法映射的码值整条丢弃，避免 weathercode 与其他字段错位。
      if (icon == null) continue;
      times.add(toNaiveLocal(fxTime, utcOffsetSeconds: offset));
      weathercode.add(icon);
      temperature2M.add(_doubleOf(h['temp']) ?? 0);
      relativehumidity2M.add(_intOf(h['humidity']));
      precipitation.add(_doubleOf(h['precip']));
      surfacePressure.add(_doubleOf(h['pressure']));
      windspeed10M.add(_doubleOf(h['windSpeed']));
      winddirection10M.add(_intOf(h['wind360']));
      cloudcover.add(_intOf(h['cloud']));
      dewpoint2M.add(_doubleOf(h['dew']));
      precipitationProbability.add(_intOf(h['pop']));
    }

    final timeDaily = <DateTime>[];
    final weathercodeDaily = <int?>[];
    final temperature2MMax = <double?>[];
    final temperature2MMin = <double?>[];
    final sunrise = <String>[];
    final sunset = <String>[];
    final precipitationSum = <double?>[];
    final windspeed10MMax = <double?>[];
    final uvIndexMax = <double?>[];
    final winddirection10MDominant = <int?>[];

    for (final raw in days) {
      final d = _asMap(raw);
      final fxDate = '${d['fxDate'] ?? ''}';
      if (fxDate.isEmpty) continue;
      timeDaily.add(TimeIndexHelper.parseCalendarDate(fxDate));
      weathercodeDaily.add(iconToWmo('${d['iconDay']}'));
      temperature2MMax.add(_doubleOf(d['tempMax']));
      temperature2MMin.add(_doubleOf(d['tempMin']));
      sunrise.add('${d['sunrise'] ?? '00:00'}');
      sunset.add('${d['sunset'] ?? '00:00'}');
      precipitationSum.add(_doubleOf(d['precip']));
      windspeed10MMax.add(_doubleOf(d['windSpeedDay']));
      uvIndexMax.add(_doubleOf(d['uvIndex']));
      winddirection10MDominant.add(_intOf(d['wind360Day']));
    }

    final cache = MainWeatherCache(
      time: times.isEmpty ? null : times,
      weathercode: weathercode.isEmpty ? null : weathercode,
      temperature2M: temperature2M.isEmpty ? null : temperature2M,
      relativehumidity2M: relativehumidity2M.isEmpty ? null : relativehumidity2M,
      precipitation: precipitation.isEmpty ? null : precipitation,
      surfacePressure: surfacePressure.isEmpty ? null : surfacePressure,
      windspeed10M: windspeed10M.isEmpty ? null : windspeed10M,
      winddirection10M: winddirection10M.isEmpty ? null : winddirection10M,
      cloudcover: cloudcover.isEmpty ? null : cloudcover,
      dewpoint2M: dewpoint2M.isEmpty ? null : dewpoint2M,
      precipitationProbability: precipitationProbability.isEmpty
          ? null
          : precipitationProbability,
      timeDaily: timeDaily.isEmpty ? null : timeDaily,
      weathercodeDaily: weathercodeDaily.isEmpty ? null : weathercodeDaily,
      temperature2MMax: temperature2MMax.isEmpty ? null : temperature2MMax,
      temperature2MMin: temperature2MMin.isEmpty ? null : temperature2MMin,
      sunrise: sunrise.isEmpty ? null : sunrise,
      sunset: sunset.isEmpty ? null : sunset,
      precipitationSum: precipitationSum.isEmpty ? null : precipitationSum,
      windspeed10MMax: windspeed10MMax.isEmpty ? null : windspeed10MMax,
      uvIndexMax: uvIndexMax.isEmpty ? null : uvIndexMax,
      winddirection10MDominant: winddirection10MDominant.isEmpty
          ? null
          : winddirection10MDominant,
      utcOffsetSeconds: offset,
      clockSkewSeconds: 0,
      timestamp: DateTime.now(),
    );

    final minutely = minutely5m == null ? null : minutelyFrom5m(minutely5m);
    if (minutely != null) {
      mergeMinutely(cache, minutely);
    }
    final air = airHourly == null
        ? null
        : airQualityFromHourly(airHourly);
    if (air != null) {
      mergeAirQuality(cache, air);
    }
    return cache;
  }

  /// Builds a city weather card from QWeather now/24h/7d/AQ responses.
  static WeatherCard toWeatherCard(
    double lat,
    double lon,
    String city,
    String district, {
    required Map<String, dynamic> now,
    required Map<String, dynamic> hourly24,
    required Map<String, dynamic> daily7,
    Map<String, dynamic>? airHourly,
  }) {
    final cache = toMainWeatherCache(
      now: now,
      hourly24: hourly24,
      daily7: daily7,
      airHourly: airHourly,
    );
    return WeatherCard.fromMainWeatherCache(
      cache,
      lat: lat,
      lon: lon,
      city: city,
      district: district,
    );
  }

  // ---------------------------------------------------------------
  // 增强数据解析
  // ---------------------------------------------------------------

  /// 聚合和风 5 分钟降水为 15 分钟槽（每 3 段求和）。
  static MinutelyPrecipitation? minutelyFrom5m(Map<String, dynamic> response) {
    final rows = _asList(response['minutely']);
    if (rows.isEmpty) return null;

    final times = <String>[];
    final precipitation = <double?>[];
    final rain = <double?>[];

    for (var i = 0; i < rows.length; i += 3) {
      final chunk = rows
          .sublist(i, i + 3 > rows.length ? rows.length : i + 3)
          .map(_asMap)
          .toList();
      if (chunk.isEmpty) continue;
      final fxTime = '${chunk.first['fxTime'] ?? ''}';
      if (fxTime.isEmpty) continue;
      times.add(toNaiveLocal(fxTime, utcOffsetSeconds: offsetSecondsOf(fxTime)));
      var total = 0.0;
      var liquid = 0.0;
      for (final row in chunk) {
        final value = _doubleOf(row['precip']) ?? 0;
        total += value;
        if (row['type'] == 'rain') liquid += value;
      }
      precipitation.add(total);
      rain.add(liquid);
    }

    if (times.isEmpty) return null;
    return MinutelyPrecipitation(
      times: times,
      precipitation: precipitation,
      rain: rain,
    );
  }

  /// Parses the current observation from QWeather `weather/now`.
  static RealtimeWeatherSnapshot? realtimeFromNow(Map<String, dynamic> response) {
    final data = _asMap(response['now']);
    if (data.isEmpty) return null;
    final obsTime = '${data['obsTime'] ?? ''}';
    return RealtimeWeatherSnapshot(
      temp: _doubleOf(data['temp']),
      feelsLike: _doubleOf(data['feelsLike']),
      humidity: _intOf(data['humidity']),
      pressure: _doubleOf(data['pressure']),
      // 和风能见度单位为 km，open-meteo 模型为 m。
      visibility: _doubleOf(data['vis']),
      windSpeed: _doubleOf(data['windSpeed']),
      windDirection: _intOf(data['wind360']),
      dewPoint: _doubleOf(data['dew']),
      precipitation: _doubleOf(data['precip']),
      icon: '${data['icon'] ?? ''}',
      cloudCover: _intOf(data['cloud']),
      obsTime: obsTime.isEmpty
          ? null
          : toNaiveLocal(
              obsTime,
              utcOffsetSeconds: offsetSecondsOf(obsTime),
            ),
    );
  }

  /// Parses QWeather hourly air quality into an aligned series.
  ///
  /// 时间字段保留原始 UTC 字符串；合并时由 [mergeAirQuality] 按目标地点
  /// 的 utcOffsetSeconds 转换对齐。
  static AirQualitySeries? airQualityFromHourly(Map<String, dynamic> response) {
    final hours = _asList(response['hours']);
    if (hours.isEmpty) return null;

    final times = <String>[];
    final usAqi = <double?>[];
    final pm25 = <double?>[];
    final pm10 = <double?>[];
    final ozone = <double?>[];
    final co = <double?>[];
    final no2 = <double?>[];
    final so2 = <double?>[];

    for (final raw in hours) {
      final h = _asMap(raw);
      final forecastTime = '${h['forecastTime'] ?? ''}';
      if (forecastTime.isEmpty) continue;
      times.add(forecastTime);

      double? usValue;
      final indexes = _asList(h['indexes']);
      for (final rawIndex in indexes) {
        final index = _asMap(rawIndex);
        if (index['code'] == 'us-epa') {
          usValue = _doubleOf(index['aqi']);
          break;
        }
      }
      usAqi.add(usValue);

      double? pollutantValue(String code) {
        for (final rawPollutant in _asList(h['pollutants'])) {
          final pollutant = _asMap(rawPollutant);
          if (pollutant['code'] != code) continue;
          final concentration = _asMap(pollutant['concentration']);
          return _doubleOf(concentration['value']);
        }
        return null;
      }

      pm25.add(pollutantValue('pm2p5'));
      pm10.add(pollutantValue('pm10'));
      ozone.add(pollutantValue('o3'));
      co.add(pollutantValue('co'));
      no2.add(pollutantValue('no2'));
      so2.add(pollutantValue('so2'));
    }

    if (times.isEmpty) return null;
    return AirQualitySeries(
      times: times,
      usAqi: usAqi,
      pm25: pm25,
      pm10: pm10,
      ozone: ozone,
      co: co,
      no2: no2,
      so2: so2,
    );
  }

  /// Parses active weather alerts from QWeather `warning/now`.
  static List<WeatherAlert>? alertsFromWarning(Map<String, dynamic> response) {
    final rows = _asList(response['warning']);
    if (rows.isEmpty) return null;

    final alerts = <WeatherAlert>[];
    for (final raw in rows) {
      final w = _asMap(raw);
      if (w['status'] != null && w['status'] != 'active') continue;
      alerts.add(
        WeatherAlert(
          id: w['id'] as String?,
          title: w['title'] as String?,
          typeName: w['typeName'] as String?,
          level: w['level'] as String?,
          severity: w['severity'] as String?,
          severityColor: w['severityColor'] as String?,
          sender: w['sender'] as String?,
          text: w['text'] as String?,
          pubTime: _dateOf('${w['pubTime'] ?? ''}'),
          startTime: _dateOf('${w['startTime'] ?? ''}'),
          endTime: _dateOf('${w['endTime'] ?? ''}'),
          status: w['status'] as String?,
        ),
      );
    }
    return alerts.isEmpty ? null : alerts;
  }

  static DateTime? _dateOf(String iso) =>
      iso.isEmpty ? null : DateTime.parse(iso).toUtc();

  // ---------------------------------------------------------------
  // 增强合并（就地修改主源缓存/卡片）
  // ---------------------------------------------------------------

  static List<String>? _timesOf(Object target) => switch (target) {
    MainWeatherCache cache => cache.time,
    WeatherCard card => card.time,
    _ => null,
  };

  /// 补充语义：主源已有 15 分钟降水时不覆盖。
  static void mergeMinutely(Object target, MinutelyPrecipitation minutely) {
    if (target is! MainWeatherCache) return;
    final cache = target;
    final existing = cache.timeMinutely15;
    if (existing != null && existing.isNotEmpty) return;
    cache
      ..timeMinutely15 = minutely.times
      ..precipitationMinutely15 = minutely.precipitation
      ..rainMinutely15 = minutely.rain
      ..showersMinutely15 = null
      ..precipitationProbabilityMinutely15 = null;
  }

  /// Replaces the current-hour slot with authoritative station observations.
  static void mergeRealtime(Object target, RealtimeWeatherSnapshot snapshot) {
    final times = _timesOf(target);
    if (times == null || times.isEmpty) return;

    final dynamic cache = switch (target) {
      MainWeatherCache t => t,
      WeatherCard t => t,
      _ => null,
    };
    if (cache == null) return;

    var index = snapshot.obsTime == null
        ? -1
        : times.indexOf(snapshot.obsTime!);
    if (index < 0) {
      final clock = LocationClock.fromCache(
        timezone: cache.timezone,
        utcOffsetSeconds: cache.utcOffsetSeconds,
        clockSkewSeconds: cache.clockSkewSeconds,
      );
      index = TimeIndexHelper.getTime(times, clock);
    }
    if (index < 0 || index >= times.length) return;

    final length = times.length;
    final wmo = iconToWmo(snapshot.icon);
    if (wmo != null) {
      cache.weathercode = _listWithValueAt(cache.weathercode, length, index, wmo);
    }
    if (snapshot.temp != null) {
      cache.temperature2M = _listWithValueAt(
        cache.temperature2M,
        length,
        index,
        snapshot.temp,
      );
    }
    if (snapshot.feelsLike != null) {
      cache.apparentTemperature = _nullableListWithValueAt(
        cache.apparentTemperature,
        length,
        index,
        snapshot.feelsLike,
      );
    }
    if (snapshot.humidity != null) {
      cache.relativehumidity2M = _nullableListWithValueAt(
        cache.relativehumidity2M,
        length,
        index,
        snapshot.humidity,
      );
    }
    if (snapshot.pressure != null) {
      cache.surfacePressure = _nullableListWithValueAt(
        cache.surfacePressure,
        length,
        index,
        snapshot.pressure,
      );
    }
    if (snapshot.visibility != null) {
      // 和风能见度 km → m。
      cache.visibility = _nullableListWithValueAt(
        cache.visibility,
        length,
        index,
        snapshot.visibility! * 1000,
      );
    }
    if (snapshot.windSpeed != null) {
      cache.windspeed10M = _nullableListWithValueAt(
        cache.windspeed10M,
        length,
        index,
        snapshot.windSpeed,
      );
    }
    if (snapshot.windDirection != null) {
      cache.winddirection10M = _nullableListWithValueAt(
        cache.winddirection10M,
        length,
        index,
        snapshot.windDirection,
      );
    }
    if (snapshot.dewPoint != null) {
      cache.dewpoint2M = _nullableListWithValueAt(
        cache.dewpoint2M,
        length,
        index,
        snapshot.dewPoint,
      );
    }
    if (snapshot.precipitation != null) {
      cache.precipitation = _nullableListWithValueAt(
        cache.precipitation,
        length,
        index,
        snapshot.precipitation,
      );
    }
    if (snapshot.cloudCover != null) {
      cache.cloudcover = _nullableListWithValueAt(
        cache.cloudcover,
        length,
        index,
        snapshot.cloudCover,
      );
    }
  }

  /// 在 [index] 处写入 [value]，长度不足视为数据源错误（非空元素列表无法填充 null）。
  static List<T> _listWithValueAt<T>(
    List<T>? source,
    int length,
    int index,
    T value,
  ) {
    final list = List<T>.of(source ?? const []);
    if (list.length < length) {
      throw ArgumentError.value(
        source,
        'source',
        'cannot pad non-nullable element list',
      );
    }
    list[index] = value;
    return list;
  }

  /// 以 null 填充成 [length]，在 [index] 处写入 [value]（可空元素列表）。
  static List<T?> _nullableListWithValueAt<T>(
    List<T?>? source,
    int length,
    int index,
    T? value,
  ) {
    final list = List<T?>.of(source ?? const [], growable: true);
    while (list.length < length) {
      list.add(null);
    }
    list[index] = value;
    return list;
  }

  /// Merges station-measured AQ values, aligned to the target hour slots.
  static void mergeAirQuality(Object target, AirQualitySeries data) {
    final weatherTimes = _timesOf(target);
    if (weatherTimes == null) return;
    final dynamic cache = switch (target) {
      MainWeatherCache t => t,
      WeatherCard t => t,
      _ => null,
    };
    if (cache == null) return;

    final offset = cache.utcOffsetSeconds ?? 0;
    final aqTimes = data.times
        .map((t) => toNaiveLocal(t, utcOffsetSeconds: offset))
        .toList();
    final indexByTime = {
      for (var i = 0; i < aqTimes.length; i++) aqTimes[i]: i,
    };

    List<T?>? align<T>(List<T?>? source) {
      if (source == null) return null;
      return List<T?>.generate(weatherTimes.length, (i) {
        final aqIndex = indexByTime[weatherTimes[i]];
        return aqIndex == null || aqIndex >= source.length
            ? null
            : source[aqIndex];
      });
    }

    void assign(dynamic model) {
      model
        ..usAqi = align(data.usAqi)
        ..pm25 = align(data.pm25)
        ..pm10 = align(data.pm10)
        ..ozone = align(data.ozone)
        ..co = align(data.co)
        ..no2 = align(data.no2)
        ..so2 = align(data.so2);
    }

    assign(cache);
  }

  static void mergeAlerts(Object target, List<WeatherAlert>? alerts) {
    if (target is MainWeatherCache) {
      target.alerts = alerts;
    } else if (target is WeatherCard) {
      target.alerts = alerts;
    }
  }

  // ---------------------------------------------------------------
  // 类型安全读取
  // ---------------------------------------------------------------

  static Map<String, dynamic> _asMap(Object? value) => switch (value) {
    Map() => Map<String, dynamic>.from(value),
    _ => const {},
  };

  static List<Object?> _asList(Object? value) => switch (value) {
    List() => List<Object?>.from(value),
    _ => const [],
  };
}