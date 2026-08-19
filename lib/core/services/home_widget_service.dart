import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:isar_community/isar.dart';
import 'package:rain/core/config/widget_registry.dart';
import 'package:rain/core/constants/app_constants.dart';
import 'package:rain/core/i18n/locale_format_helper.dart';
import 'package:rain/core/services/asset_cache_service.dart';
import 'package:rain/core/services/widget_background_service.dart';
import 'package:rain/core/utils/debug_log.dart';
import 'package:rain/core/weather/aqi_helper.dart';
import 'package:rain/core/weather/precipitation_alert_calculator.dart';
import 'package:rain/core/weather/status_weather.dart';
import 'package:rain/core/weather/time_index_helper.dart';
import 'package:rain/core/weather/weather_cache_validator.dart';
import 'package:rain/core/weather/unit_converter.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/i18n/tr.dart';

/// Pushes current weather and styling into native home screen widgets.
class HomeWidgetService {
  HomeWidgetService(this._assets);

  final AssetCacheService _assets;

  /// Formats [temp] for widget display using user unit preferences.
  String _widgetTemperature(double temp, Settings settings) {
    final converted = UnitConverter.convertTemperature(temp, settings);
    if (converted == null) return '--°';
    return '$converted${UnitConverter.temperatureSuffix(settings)}';
  }

  String _widgetLocationLabel(LocationCache? location) {
    final address = location?.address?.trim();
    if (address != null && address.isNotEmpty) return address;

    final labels = <String>[];
    for (final value in [location?.district, location?.city]) {
      final label = value?.trim();
      if (label == null || label.isEmpty || labels.contains(label)) continue;
      labels.add(label);
    }
    return labels.join(' ');
  }

  /// Reads Isar and writes widget data for all registered widget providers.
  Future<bool> updateFromIsar(Isar isar, {Settings? settings}) async {
    try {
      final resolved =
          settings ?? await isar.settings.where().findFirst() ?? Settings();
      final bundle = await _buildWidgetBundle(isar, resolved);

      final dataResults = await Future.wait<bool?>([
        if (bundle != null)
          HomeWidget.saveWidgetData('widget_bundle', jsonEncode(bundle))
        else
          HomeWidget.saveWidgetData<String>('widget_bundle', null),
        HomeWidget.saveWidgetData('timeformat', resolved.timeformat),
        HomeWidget.saveWidgetData('widget_theme_mode', resolved.theme),
        ..._colorSaveTasks(resolved),
      ]);
      if (dataResults.contains(false)) return false;

      final updateResults = await Future.wait<bool?>(
        rainWidgetRegistry.map(
          (widget) => HomeWidget.updateWidget(
            androidName: widget.androidName,
            qualifiedAndroidName: widget.qualifiedAndroidName,
          ),
        ),
      );
      return !updateResults.contains(false);
    } catch (e, st) {
      debugLogError('HomeWidgetService.updateFromIsar', e, st);
      return false;
    }
  }

  List<Future<bool?>> _colorSaveTasks(Settings settings) => [
    _saveColorPref(
      'background_color_light',
      settings.widgetBackgroundColorLight,
    ),
    _saveColorPref('background_color_dark', settings.widgetBackgroundColorDark),
    _saveColorPref('text_color_light', settings.widgetTextColorLight),
    _saveColorPref('text_color_dark', settings.widgetTextColorDark),
  ];

  Future<bool?> _saveColorPref(String key, String? color) {
    if (color != null && color.isNotEmpty) {
      return HomeWidget.saveWidgetData(key, color);
    }
    return HomeWidget.saveWidgetData<String>(key, null);
  }

  /// Builds the JSON payload for the current hour from main weather cache.
  Future<Map<String, dynamic>?> _buildWidgetBundle(
    Isar isar,
    Settings settings,
  ) async {
    final cache = await isar.mainWeatherCaches.where().findFirst();
    final hourlyTimes = cache?.time;
    final weatherCodes = cache?.weathercode;
    final temperatures = cache?.temperature2M;
    if (cache == null ||
        hourlyTimes == null ||
        hourlyTimes.isEmpty ||
        weatherCodes == null ||
        weatherCodes.isEmpty ||
        temperatures == null ||
        temperatures.isEmpty) {
      return null;
    }

    final clock = LocationClock.fromMainWeather(
      cache,
      settingsClockSkewSeconds: settings.clockSkewSeconds,
    );
    final dailyTimes = cache.timeDaily ?? const <DateTime>[];
    final indices = TimeIndexHelper.currentIndices(
      hourly: hourlyTimes,
      daily: dailyTimes,
      clock: clock,
    );
    final hour = indices.hour.clamp(
      0,
      [
            hourlyTimes.length,
            weatherCodes.length,
            temperatures.length,
          ].reduce((a, b) => a < b ? a : b) -
          1,
    );
    final day = dailyTimes.isEmpty
        ? 0
        : indices.day.clamp(0, dailyTimes.length - 1);
    final wallNow = TimeIndexHelper.wallClockNow(clock);
    final languageCode = LocaleSettings.currentLocale.languageCode;

    final location = await isar.locationCaches.where().findFirst();
    final statusWeather = StatusWeather.forTheme(settings.weatherIconTheme);
    final currentIcon = await _assets.getLocalImagePath(
      statusWeather.getImageNotification(
        weatherCodes[hour],
        hourlyTimes[hour],
        _dailyValue(cache.sunrise, day) ?? '06:00',
        _dailyValue(cache.sunset, day) ?? '18:00',
      ),
      assetRoot: statusWeather.assetRoot,
    );

    final bundle = <String, dynamic>{
      'current': <String, dynamic>{
        'location': _widgetLocationLabel(location),
        'temperature': _widgetTemperature(temperatures[hour], settings),
        'condition': statusWeather.getText(weatherCodes[hour]),
        'icon': currentIcon,
      },
      'date': _formatWidgetDate(wallNow, languageCode),
      'calendarDate': _calendarDate(wallNow),
      'timeZoneId': cache.timezone,
      'dateEpochMillis': DateTime.utc(
        wallNow.year,
        wallNow.month,
        wallNow.day,
        12,
      ).millisecondsSinceEpoch,
      'updateTime': _formatUpdateTime(
        timestamp: cache.timestamp,
        clock: clock,
        settings: settings,
        languageCode: languageCode,
      ),
    };

    final aqi = _aqiAt(cache, hour, settings.aqiStandard);
    if (aqi != null) {
      bundle['aqi'] = <String, dynamic>{
        'value': aqi.round(),
        'level': AqiHelper.severityLabel(settings.aqiStandard, aqi),
        'severity': AqiHelper.severityIndex(settings.aqiStandard, aqi),
      };
    }

    final precipitationAlert = _precipitationAlert(
      cache: cache,
      wallNow: wallNow,
    );
    if (precipitationAlert != null) {
      bundle['precipitationAlert'] = precipitationAlert;
    }

    final forecast = await _buildForecast(
      cache: cache,
      startDay: day,
      statusWeather: statusWeather,
      settings: settings,
      languageCode: languageCode,
      wallNow: wallNow,
    );
    if (forecast.isNotEmpty) bundle['forecast'] = forecast;

    return bundle;
  }

  Future<List<Map<String, dynamic>>> _buildForecast({
    required MainWeatherCache cache,
    required int startDay,
    required StatusWeather statusWeather,
    required Settings settings,
    required String languageCode,
    required DateTime wallNow,
  }) async {
    final dates = cache.timeDaily;
    final codes = cache.weathercodeDaily;
    if (dates == null || dates.isEmpty || codes == null || codes.isEmpty) {
      return const [];
    }

    final forecast = <Map<String, dynamic>>[];
    for (var offset = 0; offset < 5; offset++) {
      final index = startDay + offset;
      if (index >= dates.length || index >= codes.length) break;
      final code = codes[index];
      if (code == null) continue;

      final icon = await _assets.getLocalImagePath(
        statusWeather.getImageNotification(
          code,
          '${_isoCalendarDate(dates[index])}T12:00',
          _dailyValue(cache.sunrise, index) ?? '06:00',
          _dailyValue(cache.sunset, index) ?? '18:00',
        ),
        assetRoot: statusWeather.assetRoot,
      );
      final min = _dailyValue(cache.temperature2MMin, index);
      final max = _dailyValue(cache.temperature2MMax, index);

      forecast.add({
        'label': _forecastLabel(
          date: dates[index],
          wallNow: wallNow,
          languageCode: languageCode,
        ),
        'date': _calendarDate(dates[index]),
        'icon': icon,
        'tempMin': min == null ? '--°' : _widgetTemperature(min, settings),
        'tempMax': max == null ? '--°' : _widgetTemperature(max, settings),
      });
    }
    return forecast;
  }

  String _forecastLabel({
    required DateTime date,
    required DateTime wallNow,
    required String languageCode,
  }) {
    if (TimeIndexHelper.isSameCalendarDay(date, wallNow)) return 'today'.tr;
    return LocaleFormatHelper.weekdayAbbrev(date, languageCode);
  }

  double? _aqiAt(MainWeatherCache cache, int hour, String standard) {
    final values = standard == AqiHelper.american
        ? cache.usAqi
        : cache.europeanAqi;
    if (values == null || hour >= values.length) return null;
    return values[hour];
  }

  String? _precipitationAlert({
    required MainWeatherCache cache,
    required DateTime wallNow,
  }) {
    if (!WeatherCacheValidator.hasMinutelyRainForecast(cache) ||
        !_isFreshMinutelyForecast(cache.timestamp)) {
      return null;
    }

    final alert = PrecipitationAlertCalculator.calculate(
      times: cache.timeMinutely15!,
      precipitation: cache.precipitationMinutely15!,
      rain: cache.rainMinutely15,
      showers: cache.showersMinutely15,
      now: wallNow,
    );
    return alert == null ? null : _formatPrecipitationAlert(alert);
  }

  bool _isFreshMinutelyForecast(DateTime? fetchedAt) {
    if (fetchedAt == null) return false;
    final age = DateTime.now().difference(fetchedAt);
    return age >= Duration.zero &&
        age <= AppConstants.minutelyRainForecastFreshness;
  }

  String _formatPrecipitationAlert(PrecipitationAlert alert) {
    if (alert.kind == PrecipitationAlertKind.starts) {
      return alert.minutes == 0
          ? 'rainStartsNow'.tr
          : _replaceTranslation('rainStartsIn'.tr, {
              'minutes': '${alert.minutes}',
            });
    }
    if (alert.kind == PrecipitationAlertKind.stops) {
      return alert.minutes == 0
          ? 'rainStopsNow'.tr
          : _replaceTranslation('rainStopsIn'.tr, {
              'minutes': '${alert.minutes}',
            });
    }
    return _replaceTranslation('rainChangesIn'.tr, {
      'minutes': '${alert.minutes}',
      'from': _rainIntensityLabel(alert.from!),
      'to': _rainIntensityLabel(alert.to!),
    });
  }

  String _rainIntensityLabel(RainIntensity intensity) => switch (intensity) {
    RainIntensity.light => 'rainLight'.tr,
    RainIntensity.moderate => 'rainModerate'.tr,
    RainIntensity.heavy => 'rainHeavy'.tr,
    RainIntensity.torrential => 'rainTorrential'.tr,
  };

  String _replaceTranslation(String value, Map<String, String> values) {
    var result = value;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  String _formatWidgetDate(DateTime date, String languageCode) =>
      '${_calendarDate(date)} '
      '${LocaleFormatHelper.weekdayAbbrev(date, languageCode)}';

  String _formatUpdateTime({
    required DateTime? timestamp,
    required LocationClock clock,
    required Settings settings,
    required String languageCode,
  }) {
    if (timestamp == null) return '—';
    final correctedUtc = timestamp.toUtc().add(
      Duration(seconds: clock.clockSkewSeconds),
    );
    final locationTime = clock.utcOffsetSeconds != null
        ? correctedUtc.add(Duration(seconds: clock.utcOffsetSeconds!))
        : correctedUtc.toLocal();
    final time = TimeIndexHelper.formatWallClock(
      locationTime,
      settings,
      languageCode,
    );
    return '$time · ${'lastUpdated'.tr}';
  }

  T? _dailyValue<T>(List<T>? values, int index) {
    if (values == null || index < 0 || index >= values.length) return null;
    return values[index];
  }

  String _calendarDate(DateTime date) => '${date.month}/${date.day}';

  String _isoCalendarDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Updates widgets from disk and optionally forces fresh weather first.
  static Future<bool> updateFromDisk({bool forceRefresh = false}) =>
      runWidgetBackgroundRefresh(
        (isar) => HomeWidgetService(AssetCacheService()).updateFromIsar(isar),
        refreshStaleWeather: (isar) => refreshMainWeatherIfStale(
          isar,
          forceRefresh: forceRefresh,
        ),
      );
}
