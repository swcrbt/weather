import 'package:dio/dio.dart';
import 'package:rain/core/constants/app_constants.dart';
import 'package:rain/core/utils/debug_log.dart';
import 'package:rain/core/utils/location_label.dart';

/// Reverse-geocodes coordinates via Nominatim into location labels.
///
/// 与天气数据供应商无关，由所有数据源组合共用。
class GeocodingRemoteDatasource {
  GeocodingRemoteDatasource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Reverse-geocodes coordinates via Nominatim for detailed location labels.
  Future<({String city, String district, String address})?> reverseGeocode(
    double lat,
    double lon, {
    String? languageCode,
  }) async {
    final languageParam = languageCode != null && languageCode.isNotEmpty
        ? '&accept-language=$languageCode'
        : '';
    final url =
        '${AppConstants.nominatimReverseUrl}?lat=$lat&lon=$lon&format=json&addressdetails=1$languageParam';
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': AppConstants.nominatimUserAgent},
        ),
      );
      if (response.statusCode != 200) return null;
      return parseNominatimLabels(response.data);
    } on DioException catch (e, stackTrace) {
      debugLogError('GeocodingRemoteDatasource.reverseGeocode', e, stackTrace);
      return null;
    }
  }

  /// Maps a Nominatim reverse-geocoding payload to location labels.
  static ({String city, String district, String address})? parseNominatimLabels(
    dynamic data,
  ) {
    if (data is! Map) return null;
    final address = data['address'];
    if (address is! Map) return null;

    final city = firstNonEmptyLocationLabel([
      _stringField(address, 'city'),
      _stringField(address, 'town'),
      _stringField(address, 'village'),
      _stringField(address, 'municipality'),
      _stringField(address, 'hamlet'),
      _stringField(address, 'city_district'),
      _stringField(address, 'suburb'),
      _stringField(address, 'county'),
    ]);
    final district = firstNonEmptyLocationLabel([
      _stringField(address, 'state'),
      _stringField(address, 'region'),
      _stringField(address, 'state_district'),
      _stringField(address, 'country'),
    ]);

    final displayName = data['display_name'] is String
        ? (data['display_name'] as String).trim()
        : '';
    final structuredAddress = _joinNominatimAddress(address);
    final hasStreetDetail = [
      _stringField(address, 'road'),
      _stringField(address, 'house_number'),
      _stringField(address, 'building'),
      _stringField(address, 'residential'),
      _stringField(address, 'amenity'),
    ].any(hasNonEmptyLocationText);
    final String addressText;
    if (hasStreetDetail && structuredAddress.isNotEmpty) {
      addressText = structuredAddress;
    } else if (displayName.isNotEmpty) {
      addressText = displayName;
    } else {
      addressText = structuredAddress;
    }

    if (city.isEmpty && district.isEmpty && addressText.isEmpty) return null;
    return (city: city, district: district, address: addressText);
  }

  static String _joinNominatimAddress(Map address) {
    final parts = <String>[
      _stringField(address, 'city_district') ?? '',
      _stringField(address, 'suburb') ?? '',
      _stringField(address, 'neighbourhood') ?? '',
      _stringField(address, 'county') ?? '',
      _stringField(address, 'state') ?? '',
      _stringField(address, 'city') ?? '',
      _stringField(address, 'town') ?? '',
      _stringField(address, 'building') ?? '',
      _stringField(address, 'residential') ?? '',
      _stringField(address, 'amenity') ?? '',
      _stringField(address, 'road') ?? '',
      _stringField(address, 'house_number') ?? '',
    ];
    final unique = <String>[];
    for (final part in parts) {
      final value = part.trim();
      if (value.isEmpty || unique.contains(value)) continue;
      unique.add(value);
    }
    return unique.join(' ');
  }

  static String? _stringField(Map data, String key) {
    final value = data[key];
    return value is String ? value : null;
  }
}