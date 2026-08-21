import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rain/core/utils/debug_log.dart';
import 'package:rain/core/weather/aqi_helper.dart';
import 'package:rain/data/datasources/qweather_api_client.dart';
import 'package:rain/features/aqimap/domain/aqi_station.dart';

/// 视野内真实监测站气泡数据（和风 AQI v1）。
///
/// 流程：
/// 1. 在视野内取少量采样点调用 `airquality/v1/current`，
///    收集响应 `stations[]` 中关联监测站的 id/name；
/// 2. 用 GeoAPI 按 LocationID 反查站点坐标（按文档推断，未经真实
///    凭据实测，反查失败的站点静默丢弃）；
/// 3. 对视野内站点再调一次 `current` 取实测污染物，按 US EPA 断点
///    计算气泡展示的 AQI。
///
/// 凭据缺失、接口失败或区域无站时返回空列表，不影响热力图图层。
/// 和风按调用次数计费：坐标反查结果进程内永久缓存，站点实测缓存
/// 10 分钟，采样点随视野量化，避免拖动地图时请求放大。
class AqiStationRemoteDatasource {
  AqiStationRemoteDatasource({QWeatherApiClient? client})
    : _client = client ?? QWeatherApiClient();

  final QWeatherApiClient _client;

  /// 单次返回的站点数量上限，控制和风调用量。
  static const int maxStations = 24;

  static const Duration _stationValuesTtl = Duration(minutes: 10);

  /// 站点坐标进程内缓存：站点不会搬迁，无需过期。
  final Map<String, LatLng?> _coordCache = {};

  /// 站点实测缓存：stationId → (值, 时间)。
  final Map<String, (AqiStation, DateTime)> _valueCache = {};

  /// 拉取 [bounds] 视野内的监测站；任何失败都返回已有/空结果。
  Future<List<AqiStation>> fetchStations(
    LatLngBounds bounds, {
    String? languageCode,
  }) async {
    try {
      final discovered = await _discoverStations(bounds, languageCode);
      if (discovered.isEmpty) return const [];

      final stations = <AqiStation>[];
      for (final entry in discovered.entries.take(maxStations)) {
        final position = await _stationPosition(entry.key, languageCode);
        if (position == null || !bounds.contains(position)) continue;
        final station = await _stationValues(
          entry.key,
          entry.value,
          position,
          languageCode,
        );
        if (station != null) stations.add(station);
      }
      return stations;
    } catch (e, stackTrace) {
      debugLogError('AqiStationRemoteDatasource.fetchStations', e, stackTrace);
      return const [];
    }
  }

  /// 视野内 2×2 采样点的关联监测站并集：stationId → name。
  Future<Map<String, String>> _discoverStations(
    LatLngBounds bounds,
    String? languageCode,
  ) async {
    final latMid = (bounds.north + bounds.south) / 2;
    final lonMid = (bounds.east + bounds.west) / 2;
    final latOffset = (bounds.north - bounds.south) / 4;
    final lonOffset = (bounds.east - bounds.west) / 4;
    final samplePoints = [
      (latMid - latOffset, lonMid - lonOffset),
      (latMid - latOffset, lonMid + lonOffset),
      (latMid + latOffset, lonMid - lonOffset),
      (latMid + latOffset, lonMid + lonOffset),
    ];

    final discovered = <String, String>{};
    for (final (lat, lon) in samplePoints) {
      try {
        final payload = await _client.airCurrent(
          lat,
          lon,
          languageCode: languageCode,
        );
        final stations = payload['stations'];
        if (stations is! List) continue;
        for (final raw in stations.take(8)) {
          if (raw is! Map) continue;
          final id = raw['id']?.toString();
          final name = raw['name']?.toString();
          if (id != null && id.isNotEmpty && name != null) {
            discovered[id] = name;
          }
        }
      } catch (e, stackTrace) {
        debugLogError('AqiStationRemoteDatasource.discover', e, stackTrace);
      }
    }
    return discovered;
  }

  Future<LatLng?> _stationPosition(
    String stationId,
    String? languageCode,
  ) async {
    if (_coordCache.containsKey(stationId)) return _coordCache[stationId];
    LatLng? position;
    try {
      final location = await _client.geoLookupById(
        stationId,
        languageCode: languageCode,
      );
      final lat = double.tryParse(location?['lat']?.toString() ?? '');
      final lon = double.tryParse(location?['lon']?.toString() ?? '');
      if (lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180) {
        position = LatLng(lat, lon);
      }
    } catch (e, stackTrace) {
      debugLogError(
        'AqiStationRemoteDatasource.stationPosition($stationId)',
        e,
        stackTrace,
      );
    }
    _coordCache[stationId] = position;
    return position;
  }

  Future<AqiStation?> _stationValues(
    String stationId,
    String name,
    LatLng position,
    String? languageCode,
  ) async {
    final cached = _valueCache[stationId];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _stationValuesTtl) {
      return cached.$1;
    }

    try {
      final payload = await _client.airCurrent(
        position.latitude,
        position.longitude,
        languageCode: languageCode,
      );
      final pollutants = payload['pollutants'];
      double? pm25;
      double? pm10;
      if (pollutants is List) {
        for (final raw in pollutants) {
          if (raw is! Map) continue;
          final concentration = raw['concentration'];
          final value = concentration is Map
              ? (concentration['value'] as num?)?.toDouble()
              : null;
          switch (raw['code']?.toString()) {
            case 'pm2p5':
              pm25 = value;
            case 'pm10':
              pm10 = value;
          }
        }
      }
      final aqi = AqiHelper.usEpaAqiFromParticulates(pm25: pm25, pm10: pm10);
      if (aqi == null) return null;
      final station = AqiStation(
        id: stationId,
        name: name,
        position: position,
        aqi: aqi,
        pm25: pm25,
        pm10: pm10,
      );
      _valueCache[stationId] = (station, DateTime.now());
      return station;
    } catch (e, stackTrace) {
      debugLogError(
        'AqiStationRemoteDatasource.stationValues($stationId)',
        e,
        stackTrace,
      );
      return cached?.$1;
    }
  }
}

/// 视野量化后的站点查询键（量化粒度随缩放级别变化）。
class AqiStationQuery {
  const AqiStationQuery({required this.bounds, required this.zoomBucket});

  factory AqiStationQuery.fromBounds(LatLngBounds bounds, double zoom) {
    // 低缩放（大视野）用更粗的量化，避免微小平移触发整批站点重查。
    final granularity = zoom >= 10
        ? 0.1
        : zoom >= 7
        ? 0.5
        : 2.0;
    double q(double v) => (v / granularity).round() * granularity;
    return AqiStationQuery(
      bounds: LatLngBounds(
        LatLng(q(bounds.south), q(bounds.west)),
        LatLng(q(bounds.north), q(bounds.east)),
      ),
      zoomBucket: max(3, zoom.round()),
    );
  }

  final LatLngBounds bounds;
  final int zoomBucket;

  @override
  bool operator ==(Object other) =>
      other is AqiStationQuery &&
      other.zoomBucket == zoomBucket &&
      other.bounds.north == bounds.north &&
      other.bounds.south == bounds.south &&
      other.bounds.west == bounds.west &&
      other.bounds.east == bounds.east;

  @override
  int get hashCode => Object.hash(
    bounds.north,
    bounds.south,
    bounds.west,
    bounds.east,
    zoomBucket,
  );
}
