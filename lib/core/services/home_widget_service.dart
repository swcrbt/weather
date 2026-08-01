import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:isar_community/isar.dart';
import 'package:rain/core/utils/debug_log.dart';
import 'package:rain/core/config/widget_registry.dart';
import 'package:rain/core/services/asset_cache_service.dart';
import 'package:rain/core/services/widget_background_service.dart';
import 'package:rain/core/weather/unit_converter.dart';
import 'package:rain/core/weather/status_weather.dart';
import 'package:rain/core/weather/time_index_helper.dart';
import 'package:rain/data/models/db.dart';

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
  /// 增强版本：支持 AQI、降水预警、5天预报
  Future<Map<String, dynamic>?> _buildWidgetBundle(
    Isar isar,
    Settings settings,
  ) async {
    final cache = await isar.mainWeatherCaches.where().findFirst();
    if (cache == null ||
        cache.time == null ||
        cache.time!.isEmpty ||
        cache.timezone == null ||
        cache.weathercode == null ||
        cache.temperature2M == null) {
      return null;
    }

    final clock = LocationClock.fromMainWeather(
      cache,
      settingsClockSkewSeconds: settings.clockSkewSeconds,
    );
    final indices = TimeIndexHelper.currentIndices(
      hourly: cache.time!,
      daily: cache.timeDaily ?? const [],
      clock: clock,
    );
    final hour = indices.hour.clamp(0, cache.weathercode!.length - 1);
    final day = cache.timeDaily == null || cache.timeDaily!.isEmpty
        ? 0
        : indices.day.clamp(0, cache.timeDaily!.length - 1);

    final location = await isar.locationCaches.where().findFirst();
    final locationName = location?.displayLabel ?? '';

    final sunrise = cache.sunrise != null && day < cache.sunrise!.length
        ? cache.sunrise![day]
        : null;
    final sunset = cache.sunset != null && day < cache.sunset!.length
        ? cache.sunset![day]
        : null;

    final statusWeather = StatusWeather.forTheme(settings.weatherIconTheme);

    final currentIcon = await _assets.getLocalImagePath(
      statusWeather.getImageNotification(
        cache.weathercode![hour],
        cache.time![hour],
        sunrise ?? '06:00',
        sunset ?? '18:00',
      ),
      assetRoot: statusWeather.assetRoot,
    );

    final temp = cache.temperature2M?[hour];

    // 构建基础数据
    final bundle = <String, dynamic>{
      'current': <String, dynamic>{
        'location': locationName,
        'temperature': temp == null
            ? '--°'
            : _widgetTemperature(temp, settings),
        'icon': currentIcon,
      },
    };

    // 添加 AQI 数据（如果有）
    final aqiValue = settings.aqiStandard == 'european' 
        ? cache.europeanAqi?.firstOrNull 
        : cache.usAqi?.firstOrNull;
    if (aqiValue != null) {
      bundle['aqi'] = <String, dynamic>{
        'value': aqiValue.round(),
        'level': _resolveAqiLevel(aqiValue.round()),
      };
    }

    // 添加5天预报数据
    final forecast = <Map<String, dynamic>>[];
    for (int i = 0; i < 5 && i < (cache.timeDaily?.length ?? 0); i++) {
      final dayIndex = day + i;
      if (dayIndex >= (cache.timeDaily?.length ?? 0)) break;
      
      final dayTempMax = cache.temperature2MMax?[dayIndex];
      final dayTempMin = cache.temperature2MMin?[dayIndex];
      final dayWeatherCode = cache.weathercodeDaily?[dayIndex];
      
      if (dayWeatherCode != null) {
        final dayTime = cache.timeDaily![dayIndex].toIso8601String();
        final dayIcon = await _assets.getLocalImagePath(
          statusWeather.getImageNotification(
            dayWeatherCode,
            dayTime,
            sunrise ?? '06:00',
            sunset ?? '18:00',
          ),
          assetRoot: statusWeather.assetRoot,
        );
        
        forecast.add({
          'label': i == 0 ? '今天' : _getWeekdayLabel(dayIndex),
          'icon': dayIcon,
          'tempMax': dayTempMax?.round().toString() ?? '--',
          'tempMin': dayTempMin?.round().toString() ?? '--',
        });
      }
    }
    
    if (forecast.isNotEmpty) {
      bundle['forecast'] = forecast;
    }

    // 添加更新时间
    bundle['updateTime'] = _formatUpdateTime(DateTime.now());

    return bundle;
  }

  /// 解析 AQI 等级
  String _resolveAqiLevel(int aqi) {
    if (aqi <= 50) return '优';
    if (aqi <= 100) return '良';
    if (aqi <= 150) return '轻度污染';
    if (aqi <= 200) return '中度污染';
    if (aqi <= 300) return '重度污染';
    return '严重污染';
  }

  /// 获取星期标签
  String _getWeekdayLabel(int dayOffset) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final now = DateTime.now();
    final targetDay = now.add(Duration(days: dayOffset));
    return weekdays[targetDay.weekday - 1];
  }

  /// 格式化更新时间
  String _formatUpdateTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}更新';
  }

  /// Background entry point: refreshes stale cache and updates widgets from disk.
  static Future<bool> updateFromDisk() => runWidgetBackgroundRefresh(
    (isar) => HomeWidgetService(AssetCacheService()).updateFromIsar(isar),
  );
}
