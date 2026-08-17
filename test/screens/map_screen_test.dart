import '../helpers/fake_notifiers.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/widget_test_harness.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rain/core/di/providers.dart';
import 'package:rain/features/map/presentation/map_screen.dart';
import 'package:rain/features/radar/application/radar_provider.dart';
import 'package:rain/features/radar/domain/radar_timeline.dart';
import 'package:rain/features/radar/precipitation_radar_map.dart';

void main() {
  late TestBootstrapContext ctx;
  const radarTimeline = RadarTimeline(
    host: 'https://tilecache.rainviewer.com',
    frames: [
      RadarFrame(time: 100, path: '/v2/radar/14d13bc04afb'),
      RadarFrame(time: 200, path: '/v2/radar/2740b8810066'),
    ],
  );

  Widget mapPage() => SizedBox(
    height: 500,
    width: 500,
    child: MapPage(cacheStore: MemCacheStore(), renderTileLayers: false),
  );

  setUp(() async {
    ctx = await createTestBootstrap();
  });

  testWidgets('MapPage keeps the standard map mode by default', (tester) async {
    await pumpRainWidget(
      tester,
      mapPage(),
      bootstrap: ctx.bootstrap,
      overrides: [
        mainWeatherNotifierProvider.overrideWith(LoadedMainWeatherNotifier.new),
        citiesNotifierProvider.overrideWith(IdleCitiesNotifier.new),
        weatherRemoteDatasourceProvider.overrideWithValue(
          createFakeWeatherRemoteDatasource(),
        ),
        radarTimelineProvider.overrideWith(
          (ref) => throw StateError('radar should load only after opt-in'),
        ),
      ],
    );
    await tester.pump();

    expect(find.byType(MapPage), findsOneWidget);
    expect(find.byType(RadarLayerButton), findsOneWidget);
    expect(find.byType(RadarTimelinePanel), findsNothing);
  });

  testWidgets('radar layer toggle loads and closes the timeline', (
    tester,
  ) async {
    await pumpRainWidget(
      tester,
      mapPage(),
      bootstrap: ctx.bootstrap,
      overrides: [
        mainWeatherNotifierProvider.overrideWith(LoadedMainWeatherNotifier.new),
        citiesNotifierProvider.overrideWith(
          () => CitiesWithCardsNotifier([completeWeatherCard()]),
        ),
        weatherRemoteDatasourceProvider.overrideWithValue(
          createFakeWeatherRemoteDatasource(),
        ),
        radarTimelineProvider.overrideWith((ref) async => radarTimeline),
      ],
    );
    await tester.pump();

    await tester.tap(find.byType(RadarLayerButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(RadarTimelinePanel), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.byType(RadarLayerButton));
    await tester.pump();
    expect(find.byType(RadarTimelinePanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('radar failure keeps the map usable and offers retry', (
    tester,
  ) async {
    await pumpRainWidget(
      tester,
      mapPage(),
      bootstrap: ctx.bootstrap,
      overrides: [
        mainWeatherNotifierProvider.overrideWith(LoadedMainWeatherNotifier.new),
        citiesNotifierProvider.overrideWith(IdleCitiesNotifier.new),
        weatherRemoteDatasourceProvider.overrideWithValue(
          createFakeWeatherRemoteDatasource(),
        ),
        radarTimelineProvider.overrideWith(
          (ref) => Future<RadarTimeline>.error(Exception('offline')),
        ),
      ],
    );
    await tester.pump();

    await tester.tap(find.byType(RadarLayerButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MapPage), findsOneWidget);
    expect(find.byType(RadarTimelinePanel), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('radar refresh failure keeps the last successful frames', (
    tester,
  ) async {
    var requests = 0;
    await pumpRainWidget(
      tester,
      mapPage(),
      bootstrap: ctx.bootstrap,
      overrides: [
        mainWeatherNotifierProvider.overrideWith(LoadedMainWeatherNotifier.new),
        citiesNotifierProvider.overrideWith(IdleCitiesNotifier.new),
        weatherRemoteDatasourceProvider.overrideWithValue(
          createFakeWeatherRemoteDatasource(),
        ),
        radarTimelineProvider.overrideWith((ref) {
          requests++;
          return requests == 1
              ? Future.value(radarTimeline)
              : Future<RadarTimeline>.error(Exception('offline'));
        }),
      ],
    );
    await tester.pump();

    await tester.tap(find.byType(RadarLayerButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('radar playback stops when the app is paused', (tester) async {
    await pumpRainWidget(
      tester,
      mapPage(),
      bootstrap: ctx.bootstrap,
      overrides: [
        mainWeatherNotifierProvider.overrideWith(LoadedMainWeatherNotifier.new),
        citiesNotifierProvider.overrideWith(
          () => CitiesWithCardsNotifier([completeWeatherCard()]),
        ),
        weatherRemoteDatasourceProvider.overrideWithValue(
          createFakeWeatherRemoteDatasource(),
        ),
        radarTimelineProvider.overrideWith((ref) async => radarTimeline),
      ],
    );
    await tester.pump();

    await tester.tap(find.byType(RadarLayerButton));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
