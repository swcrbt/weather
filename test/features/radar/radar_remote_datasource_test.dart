import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rain/features/radar/data/radar_remote_datasource.dart';

void main() {
  group('RadarRemoteDatasource', () {
    test('parses, validates, sorts, and deduplicates radar frames', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'host': 'https://tilecache.rainviewer.com',
                  'radar': {
                    'past': [
                      {'time': 1786979400, 'path': '/v2/radar/2740b8810066'},
                      {'time': 1786978800, 'path': '/v2/radar/14d13bc04afb'},
                      {'time': 1786979400, 'path': '/v2/radar/2740b8810066'},
                      {'time': 'bad', 'path': '/v2/radar/bad'},
                    ],
                  },
                },
              ),
            ),
          ),
        );

      final timeline = await RadarRemoteDatasource(dio: dio).fetchTimeline();

      expect(timeline.frames.map((frame) => frame.time), [
        1786978800,
        1786979400,
      ]);
      expect(
        timeline.tileUrl(timeline.frames.first),
        'https://tilecache.rainviewer.com/v2/radar/14d13bc04afb/'
        '256/{z}/{x}/{y}/2/1_1.png',
      );
    });

    test('rejects an untrusted tile host', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'host': 'https://example.com',
                  'radar': {
                    'past': [
                      {'time': 1786978800, 'path': '/v2/radar/14d13bc04afb'},
                    ],
                  },
                },
              ),
            ),
          ),
        );

      expect(
        () => RadarRemoteDatasource(dio: dio).fetchTimeline(),
        throwsFormatException,
      );
    });

    test('rejects a response without valid frames', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'host': 'https://tilecache.rainviewer.com',
                  'radar': {
                    'past': [
                      {'time': 1786978800, 'path': '../../private'},
                      {
                        'time': 999999999999999,
                        'path': '/v2/radar/14d13bc04afb',
                      },
                    ],
                  },
                },
              ),
            ),
          ),
        );

      expect(
        () => RadarRemoteDatasource(dio: dio).fetchTimeline(),
        throwsFormatException,
      );
    });
  });
}
