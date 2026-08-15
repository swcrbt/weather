import 'dart:convert';

import '../../helpers/fake_home_widget.dart';
import '../../helpers/fake_path_provider.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/isar_test_helper.dart';
import '../../helpers/test_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rain/core/bootstrap/app_initializer.dart';
import 'package:rain/core/services/asset_cache_service.dart';
import 'package:rain/core/services/home_widget_service.dart';
import 'package:rain/core/weather/time_index_helper.dart';
import 'package:rain/i18n/tr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    installFakePathProvider();
    installFakeHomeWidget();
  });

  group('HomeWidgetService', () {
    late TestBootstrapContext ctx;
    late HomeWidgetService service;

    setUp(() async {
      ctx = await createTestBootstrap();
      service = HomeWidgetService(AssetCacheService());
    });

    test('empty cache clears stale widget payload', () async {
      savedWidgetData['widget_bundle'] = '{"current":{"temperature":"99°"}}';

      final result = await service.updateFromIsar(ctx.isarContext.isar);

      expect(result, isTrue);
      expect(savedWidgetData['widget_bundle'], isNull);
    });

    test('updateFromIsar handles seeded weather cache', () async {
      await seedMainWeatherCache(
        ctx.isarContext.isar,
        weather: sampleMainWeatherCache(),
        location: sampleLocationCache(),
      );

      final result = await service.updateFromIsar(ctx.isarContext.isar);

      expect(result, isTrue);
    });

    test('updateFromIsar writes complete detail widget payload', () async {
      final firstForecastDay = DateTime.now().add(const Duration(days: 2));
      final firstHourlySlot = DateTime.now().add(const Duration(days: 2));
      String hourlyIso(int hourOffset) {
        final value = firstHourlySlot.add(Duration(hours: hourOffset));
        return '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}T'
            '${value.hour.toString().padLeft(2, '0')}:00';
      }

      final weather = weeklyMainWeatherCache()
        ..time = List.generate(7, hourlyIso)
        ..timeDaily = List.generate(
          7,
          (index) => firstForecastDay.add(Duration(days: index)),
        )
        ..europeanAqi = List<double?>.generate(7, (index) => 10 + index * 12)
        ..usAqi = List<double?>.generate(7, (index) => 30 + index * 20)
        ..precipitationProbability = [0, 70, 0, 0, 0, 0, 0];
      await seedMainWeatherCache(
        ctx.isarContext.isar,
        weather: weather,
        location: sampleLocationCache(),
      );

      final result = await service.updateFromIsar(ctx.isarContext.isar);

      expect(result, isTrue);
      final bundle =
          jsonDecode(savedWidgetData['widget_bundle']! as String)
              as Map<String, dynamic>;
      final current = bundle['current'] as Map<String, dynamic>;
      final aqi = bundle['aqi'] as Map<String, dynamic>;
      final forecast = bundle['forecast'] as List<dynamic>;

      expect(current['location'], 'Moscow');
      expect(current['temperature'], isNotEmpty);
      expect(current['condition'], isNotEmpty);
      final expectedHour = TimeIndexHelper.getTime(
        weather.time!,
        LocationClock.fromMainWeather(
          weather,
          settingsClockSkewSeconds: ctx.bootstrap.settings.clockSkewSeconds,
        ),
      );
      expect(aqi['value'], weather.europeanAqi![expectedHour]!.round());
      expect(bundle['date'], isNotEmpty);
      expect(bundle['calendarDate'], matches(RegExp(r'^\d{1,2}/\d{1,2}$')));
      expect(bundle['dateEpochMillis'], isA<int>());
      expect(bundle['timeZoneId'], weather.timezone);
      expect(bundle['updateTime'], isNot('—'));
      expect(bundle['precipitationAlert'], contains('70%'));
      expect(aqi['value'], isA<int>());
      expect(aqi['level'], isNotEmpty);
      expect(aqi['severity'], inInclusiveRange(0, 5));
      expect(forecast, hasLength(5));
      expect(
        (forecast.first as Map<String, dynamic>)['label'],
        isNot('today'.tr),
      );
      expect(
        forecast.cast<Map<String, dynamic>>(),
        everyElement(
          allOf(
            containsPair('label', isNotEmpty),
            containsPair('date', matches(RegExp(r'^\d{1,2}/\d{1,2}$'))),
            containsPair('tempMin', isNotEmpty),
            containsPair('tempMax', isNotEmpty),
            containsPair('icon', isNotEmpty),
          ),
        ),
      );
    });

    test('updateFromIsar uses the selected AQI standard thresholds', () async {
      final weather = sampleFutureMainWeatherCache()
        ..europeanAqi = [75, 10]
        ..usAqi = [75, 10];
      await seedMainWeatherCache(
        ctx.isarContext.isar,
        weather: weather,
        location: sampleLocationCache(),
      );

      final settings = ctx.bootstrap.settings..aqiStandard = 'european';
      await service.updateFromIsar(ctx.isarContext.isar, settings: settings);
      var bundle =
          jsonDecode(savedWidgetData['widget_bundle']! as String)
              as Map<String, dynamic>;
      expect((bundle['aqi'] as Map<String, dynamic>)['severity'], 3);

      settings.aqiStandard = 'american';
      await service.updateFromIsar(ctx.isarContext.isar, settings: settings);
      bundle =
          jsonDecode(savedWidgetData['widget_bundle']! as String)
              as Map<String, dynamic>;
      expect((bundle['aqi'] as Map<String, dynamic>)['severity'], 1);
    });

    test('widget refresh interaction ignores unrelated URIs', () async {
      homeWidgetCallLog.clear();

      await widgetInteractivityCallback(Uri.parse('weather://open'));

      expect(homeWidgetCallLog, isEmpty);
    });

    test('updateFromIsar writes per-theme widget color prefs', () async {
      final settings = ctx.bootstrap.settings
        ..widgetBackgroundColorLight = '#111111'
        ..widgetBackgroundColorDark = '#222222'
        ..widgetTextColorLight = '#333333'
        ..widgetTextColorDark = '#444444';
      await seedSettings(ctx.isarContext.isar, settings);

      await service.updateFromIsar(ctx.isarContext.isar);

      expect(savedWidgetData['background_color_light'], '#111111');
      expect(savedWidgetData['background_color_dark'], '#222222');
      expect(savedWidgetData['text_color_light'], '#333333');
      expect(savedWidgetData['text_color_dark'], '#444444');
    });

    test(
      'updateFromIsar writes widget theme prefs for native palette resolution',
      () async {
        final settings = ctx.bootstrap.settings..theme = 'dark';
        await seedSettings(ctx.isarContext.isar, settings);

        await service.updateFromIsar(ctx.isarContext.isar);

        expect(savedWidgetData['widget_theme_mode'], 'dark');
      },
    );

    test(
      'updateFromIsar writes widget data before requesting widget refresh',
      () async {
        await seedMainWeatherCache(
          ctx.isarContext.isar,
          weather: sampleMainWeatherCache(),
          location: sampleLocationCache(),
        );

        homeWidgetCallLog.clear();
        await service.updateFromIsar(ctx.isarContext.isar);

        final firstUpdateIndex = homeWidgetCallLog.indexOf('updateWidget');
        expect(firstUpdateIndex, greaterThan(0));
        expect(
          homeWidgetCallLog.sublist(firstUpdateIndex),
          everyElement('updateWidget'),
        );
        expect(
          homeWidgetCallLog.sublist(0, firstUpdateIndex),
          everyElement(isNot('updateWidget')),
        );
      },
    );
  });
}
