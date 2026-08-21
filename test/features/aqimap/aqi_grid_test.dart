import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rain/features/aqimap/data/aqi_grid_remote_datasource.dart';
import 'package:rain/features/aqimap/domain/aqi_grid.dart';

void main() {
  group('AqiGridRemoteDatasource', () {
    Map<String, Object?> locationEntry(int index) => {
      'latitude': 22.0,
      'longitude': 114.0,
      'hourly': {
        'time': ['2026-08-20T00:00', '2026-08-20T01:00'],
        'european_aqi': [10 + index, 20 + index],
        'us_aqi': [30 + index, null],
        'pm2_5': [5.0, 6.0],
        'pm10': [9.0, 11.0],
      },
    };

    Dio mockDio(Object? data) => Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) =>
              handler.resolve(Response(requestOptions: options, data: data)),
        ),
      );

    AqiGridQuery query() => AqiGridQuery.fromBounds(
      LatLngBounds(const LatLng(20, 110), const LatLng(24, 118)),
    );

    test('parses multi-location response into a flat grid', () async {
      final entries = List.generate(
        AqiGridRemoteDatasource.rows * AqiGridRemoteDatasource.cols,
        locationEntry,
      );
      final grid = await AqiGridRemoteDatasource(
        dio: mockDio(entries),
      ).fetchGrid(query());

      expect(grid.rows, AqiGridRemoteDatasource.rows);
      expect(grid.cols, AqiGridRemoteDatasource.cols);
      expect(grid.frameCount, 2);
      expect(grid.times, [
        DateTime.parse('2026-08-20T00:00Z').millisecondsSinceEpoch ~/ 1000,
        DateTime.parse('2026-08-20T01:00Z').millisecondsSinceEpoch ~/ 1000,
      ]);
      // 左上角采样点（row 0, col 0）。
      expect(grid.sampleAqi('european', 0, const LatLng(24, 110)), 10);
      expect(grid.sampleAqi('american', 0, const LatLng(24, 110)), 30);
      // 缺测（null）与邻近点混合时仍能插值出非空结果。
      expect(grid.sampleAqi('american', 1, const LatLng(22, 114)), isNotNull);
    });

    test('rejects location count mismatch', () {
      expect(
        () => AqiGridRemoteDatasource(
          dio: mockDio([locationEntry(0)]),
        ).fetchGrid(query()),
        throwsFormatException,
      );
    });

    test('rejects unexpected response shape', () {
      expect(
        () => AqiGridRemoteDatasource(
          dio: mockDio({'unexpected': true}),
        ).fetchGrid(query()),
        throwsFormatException,
      );
    });
  });

  group('AqiGrid sampling', () {
    AqiGrid grid() {
      const rows = 2, cols = 2;
      // 四角: nw=10, ne=30, sw=50, se=70（时间帧 0）。
      return AqiGrid(
        bounds: LatLngBounds(const LatLng(20, 110), const LatLng(24, 118)),
        rows: rows,
        cols: cols,
        times: const [1787263200],
        europeanAqi: const [10, 30, 50, 70],
        usAqi: const [10, 30, 50, 70],
        pm25: const [1, 2, 3, 4],
        pm10: const [5, 6, 7, 8],
      );
    }

    test('returns exact values at corners', () {
      final g = grid();
      expect(g.sampleAqi('european', 0, const LatLng(24, 110)), 10);
      expect(g.sampleAqi('european', 0, const LatLng(24, 118)), 30);
      expect(g.sampleAqi('european', 0, const LatLng(20, 110)), 50);
      expect(g.sampleAqi('european', 0, const LatLng(20, 118)), 70);
    });

    test('bilinear interpolation at center', () {
      final g = grid();
      expect(g.sampleAqi('european', 0, const LatLng(22, 114)), 40);
    });

    test('returns null when every corner is missing', () {
      final g = AqiGrid(
        bounds: LatLngBounds(const LatLng(20, 110), const LatLng(24, 118)),
        rows: 2,
        cols: 2,
        times: const [1787263200],
        europeanAqi: const [null, null, null, null],
        usAqi: const [null, null, null, null],
        pm25: const [null, null, null, null],
        pm10: const [null, null, null, null],
      );
      expect(g.sampleAqi('european', 0, const LatLng(22, 114)), isNull);
    });

    test('frameIndexFor picks latest frame not after the target', () {
      final g = AqiGrid(
        bounds: LatLngBounds(const LatLng(20, 110), const LatLng(24, 118)),
        rows: 2,
        cols: 2,
        times: const [1000, 2000, 3000],
        europeanAqi: const [],
        usAqi: const [],
        pm25: const [],
        pm10: const [],
      );
      expect(
        g.frameIndexFor(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
        0,
      );
      expect(
        g.frameIndexFor(
          DateTime.fromMillisecondsSinceEpoch(2500000, isUtc: true),
        ),
        1,
      );
      expect(
        g.frameIndexFor(
          DateTime.fromMillisecondsSinceEpoch(9000000, isUtc: true),
        ),
        2,
      );
    });
  });
}
