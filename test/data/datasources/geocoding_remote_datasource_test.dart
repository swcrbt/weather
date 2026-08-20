import '../../helpers/fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rain/data/datasources/geocoding_remote_datasource.dart';

void main() {
  group('GeocodingRemoteDatasource', () {
    test('reverseGeocode maps Nominatim address fields', () async {
      final dio = createFakeWeatherDio();
      final datasource = GeocodingRemoteDatasource(dio: dio);

      final results = await datasource.reverseGeocode(
        55.75,
        37.62,
        languageCode: 'en',
      );

      expect(results, isNotNull);
      expect(results!.city, 'Moscow');
      expect(results.district, 'Central Federal District');
      expect(results.address, 'Tverskaya Street 1, Moscow, Russia');
    });

    test('parseNominatimLabels returns null for empty address', () {
      expect(
        GeocodingRemoteDatasource.parseNominatimLabels({'address': {}}),
        isNull,
      );
    });

    test('parseNominatimLabels builds a detailed address from fields', () {
      final result = GeocodingRemoteDatasource.parseNominatimLabels({
        'address': {
          'city_district': '番禺区',
          'state': '广东省',
          'city': '广州市',
          'building': '亚运城·天成',
          'road': '亚运大道',
          'house_number': '1199号',
        },
      });

      expect(result?.address, '番禺区 广东省 广州市 亚运城·天成 亚运大道 1199号');
    });

    test('parseNominatimLabels ignores malformed field types', () {
      expect(
        GeocodingRemoteDatasource.parseNominatimLabels({
          'display_name': 42,
          'address': {
            'city': 7,
            'state': <String>['unexpected'],
          },
        }),
        isNull,
      );
    });
  });
}