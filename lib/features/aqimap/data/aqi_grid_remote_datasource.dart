import 'package:dio/dio.dart';
import 'package:rain/features/aqimap/domain/aqi_grid.dart';

/// 从 Open-Meteo Air Quality API 批量拉取视野内的网格化逐小时 AQI。
///
/// 一次请求携带 rows × cols 个坐标（逗号分隔），返回每个坐标 5 天
/// （120 小时）的逐小时序列，供热力图与时间轴播放共用，拖动时间轴
/// 不产生额外请求。
class AqiGridRemoteDatasource {
  AqiGridRemoteDatasource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  /// 网格行列数。81 个坐标 × 120 小时 × 4 变量的响应约 300 KB。
  static const int rows = 9;
  static const int cols = 9;

  static const _endpoint =
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?hourly=european_aqi,us_aqi,pm2_5,pm10'
      '&forecast_days=5&timezone=UTC';

  /// 拉取 [query] 量化视野范围的网格数据；失败抛 [DioException]/[FormatException]。
  Future<AqiGrid> fetchGrid(AqiGridQuery query) async {
    final bounds = query.bounds;
    final lats = <String>[];
    final lons = <String>[];
    for (var r = 0; r < rows; r++) {
      final lat = bounds.north - (bounds.north - bounds.south) * r / (rows - 1);
      for (var c = 0; c < cols; c++) {
        final lon = bounds.west + (bounds.east - bounds.west) * c / (cols - 1);
        lats.add(lat.toStringAsFixed(3));
        lons.add(lon.toStringAsFixed(3));
      }
    }

    final response = await _dio.get<Object?>(
      _endpoint,
      queryParameters: {
        'latitude': lats.join(','),
        'longitude': lons.join(','),
      },
    );

    final body = response.data;
    // 多坐标时响应为数组；单元素视野（理论上不会出现）退回对象兼容。
    final locations = body is List
        ? body
        : body is Map
        ? [body]
        : throw const FormatException('Unexpected AQI grid response shape');
    if (locations.length != rows * cols) {
      throw FormatException(
        'AQI grid: expected ${rows * cols} locations, got ${locations.length}',
      );
    }

    List<int>? times;
    final european = <double?>[];
    final us = <double?>[];
    final pm25 = <double?>[];
    final pm10 = <double?>[];

    for (final raw in locations) {
      if (raw is! Map) throw const FormatException('AQI grid: bad location');
      final hourly = raw['hourly'];
      if (hourly is! Map) {
        throw const FormatException('AQI grid: missing hourly block');
      }
      final rawTimes = hourly['time'];
      if (rawTimes is! List) {
        throw const FormatException('AQI grid: missing hourly.time');
      }
      // timezone=UTC 时时间为无 offset 的 ISO 串，显式按 UTC 解析。
      final parsedTimes = rawTimes
          .map((t) => DateTime.parse('${t}Z').millisecondsSinceEpoch ~/ 1000)
          .toList();
      times ??= parsedTimes;
      if (parsedTimes.length != times.length) {
        throw const FormatException('AQI grid: inconsistent time axis');
      }

      european.addAll(_numbers(hourly['european_aqi'], times.length));
      us.addAll(_numbers(hourly['us_aqi'], times.length));
      pm25.addAll(_numbers(hourly['pm2_5'], times.length));
      pm10.addAll(_numbers(hourly['pm10'], times.length));
    }

    if (times == null || times.isEmpty) {
      throw const FormatException('AQI grid: empty time axis');
    }

    return AqiGrid(
      bounds: bounds,
      rows: rows,
      cols: cols,
      times: times,
      europeanAqi: european,
      usAqi: us,
      pm25: pm25,
      pm10: pm10,
    );
  }

  List<double?> _numbers(Object? raw, int expectedLength) {
    if (raw is! List) return List<double?>.filled(expectedLength, null);
    if (raw.length != expectedLength) {
      throw FormatException(
        'AQI grid: hourly series length ${raw.length} != $expectedLength',
      );
    }
    return raw
        .map((v) => v is num ? v.toDouble() : null)
        .toList(growable: false);
  }
}
