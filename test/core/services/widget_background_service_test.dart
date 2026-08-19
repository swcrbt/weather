import '../../helpers/fake_path_provider.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/isar_test_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rain/core/constants/app_constants.dart';
import 'package:rain/core/services/widget_background_service.dart';
import 'package:rain/data/datasources/weather_local_datasource.dart';

void installFakeFlutterTimezone() {
  const channel = MethodChannel('flutter_timezone');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getLocalTimezone') {
          return 'Europe/Moscow';
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    installFakePathProvider();
    installFakeFlutterTimezone();
  });

  late TestIsarContext ctx;

  setUp(() async {
    ctx = await openTestIsar();
  });

  group('refreshMainWeatherIfStale', () {
    test('returns early when location is missing', () async {
      await refreshMainWeatherIfStale(ctx.isar);

      expect(await WeatherLocalDatasource(ctx.isar).getMainWeather(), isNull);
    });

    test('returns early when cache is still fresh', () async {
      final local = WeatherLocalDatasource(ctx.isar);
      await local.saveMainWeather(
        sampleMainWeatherCache()..timestamp = DateTime.now(),
        sampleLocationCache(),
      );

      var internetChecked = false;
      await refreshMainWeatherIfStale(
        ctx.isar,
        internetAccess: () async {
          internetChecked = true;
          return false;
        },
      );

      expect((await local.getMainWeather())!.timestamp, isNotNull);
      expect(internetChecked, isFalse);
    });

    test('fresh legacy cache without minute data attempts refresh', () async {
      final local = WeatherLocalDatasource(ctx.isar);
      await local.saveMainWeather(
        sampleMainWeatherCache()
          ..timestamp = DateTime.now()
          ..timeMinutely15 = null
          ..precipitationMinutely15 = null,
        sampleLocationCache(),
      );

      var internetChecked = false;
      await refreshMainWeatherIfStale(
        ctx.isar,
        internetAccess: () async {
          internetChecked = true;
          return false;
        },
      );

      expect(internetChecked, isTrue);
    });

    test('force refresh bypasses a fresh widget cache', () async {
      final local = WeatherLocalDatasource(ctx.isar);
      await local.saveMainWeather(
        sampleMainWeatherCache()..timestamp = DateTime.now(),
        sampleLocationCache(),
      );

      var internetChecked = false;
      await refreshMainWeatherIfStale(
        ctx.isar,
        forceRefresh: true,
        internetAccess: () async {
          internetChecked = true;
          return false;
        },
      );

      expect(internetChecked, isTrue);
    });

    test(
      'missing weather cache with saved location attempts refresh',
      () async {
        final local = WeatherLocalDatasource(ctx.isar);
        await local.saveMainWeather(
          sampleMainWeatherCache(),
          sampleLocationCache(),
        );
        await local.deleteMainWeather();

        var internetChecked = false;
        await refreshMainWeatherIfStale(
          ctx.isar,
          internetAccess: () async {
            internetChecked = true;
            return false;
          },
        );

        expect(internetChecked, isTrue);
      },
    );

    test('does not throw when cache is stale but offline', () async {
      final local = WeatherLocalDatasource(ctx.isar);
      await local.saveMainWeather(
        sampleMainWeatherCache()
          ..timestamp = DateTime.now().subtract(
            AppConstants.workManagerMinInterval + const Duration(minutes: 1),
          ),
        sampleLocationCache(),
      );

      var internetChecked = false;
      await refreshMainWeatherIfStale(
        ctx.isar,
        internetAccess: () async {
          internetChecked = true;
          return false;
        },
      );

      expect(internetChecked, isTrue);
    });

    test('propagates connectivity check failures', () async {
      final local = WeatherLocalDatasource(ctx.isar);
      await local.saveMainWeather(
        sampleMainWeatherCache()
          ..timestamp = DateTime.now().subtract(
            AppConstants.workManagerMinInterval + const Duration(minutes: 1),
          ),
        sampleLocationCache(),
      );

      await expectLater(
        refreshMainWeatherIfStale(
          ctx.isar,
          internetAccess: () async => throw StateError('probe failed'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('runWidgetBackgroundRefresh', () {
    test('invokes update callback without throwing', () async {
      await closeSharedTestIsar();

      var callbackInvoked = false;
      final result = await runWidgetBackgroundRefresh((isar) async {
        callbackInvoked = true;
        expect(isar.isOpen, isTrue);
        return true;
      });

      expect(callbackInvoked, isTrue);
      expect(result, isTrue);
    });

    test('reuses an already open Isar instance without closing it', () async {
      var callbackInvoked = false;
      final result = await runWidgetBackgroundRefresh((isar) async {
        callbackInvoked = true;
        expect(identical(isar, ctx.isar), isTrue);
        return true;
      });

      expect(callbackInvoked, isTrue);
      expect(result, isTrue);
      expect(ctx.isar.isOpen, isTrue);
    });

    test('reports failure when widget update returns false', () async {
      await closeSharedTestIsar();

      final result = await runWidgetBackgroundRefresh(
        (_) async => false,
        refreshStaleWeather: (_) async {},
      );

      expect(result, isFalse);
    });

    test(
      'updates widgets but reports failure when weather refresh throws',
      () async {
        await closeSharedTestIsar();

        var callbackInvoked = false;
        final result = await runWidgetBackgroundRefresh((isar) async {
          callbackInvoked = true;
          return true;
        }, refreshStaleWeather: (_) async => throw StateError('offline'));

        expect(callbackInvoked, isTrue);
        expect(result, isFalse);
      },
    );
  });
}
