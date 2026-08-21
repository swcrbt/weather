import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rain/data/datasources/air_quality_remote_datasource.dart';
import 'package:rain/data/models/air_quality_api.dart';
import 'package:rain/features/aqimap/data/aqi_grid_remote_datasource.dart';
import 'package:rain/features/aqimap/data/aqi_station_remote_datasource.dart';
import 'package:rain/features/aqimap/domain/aqi_grid.dart';
import 'package:rain/features/aqimap/domain/aqi_station.dart';

/// Provides the Open-Meteo grid datasource for the AQI heatmap.
final aqiGridDatasourceProvider = Provider<AqiGridRemoteDatasource>(
  (ref) => AqiGridRemoteDatasource(),
);

/// Provides the QWeather monitoring-station datasource (kept alive so
/// 站点坐标与实测值的进程内缓存在图层开关间保留).
final aqiStationDatasourceProvider = Provider<AqiStationRemoteDatasource>(
  (ref) => AqiStationRemoteDatasource(),
);

/// 当前量化视野的 AQI 网格（热力图 + 时间轴共用）。
final aqiGridProvider = FutureProvider.autoDispose
    .family<AqiGrid, AqiGridQuery>((ref, query) {
      return ref.watch(aqiGridDatasourceProvider).fetchGrid(query);
    });

/// 当前量化视野内的和风监测站气泡。
final aqiStationsProvider = FutureProvider.autoDispose
    .family<List<AqiStation>, AqiStationQuery>((ref, query) {
      return ref
          .watch(aqiStationDatasourceProvider)
          .fetchStations(query.bounds);
    });

/// Provides the per-point Open-Meteo hourly datasource (站点详情图表).
final aqiHourlyDatasourceProvider = Provider<AirQualityRemoteDatasource>(
  (ref) => AirQualityRemoteDatasource(),
);

/// 站点坐标处的 7 天逐小时空气质量（详情底部柱状图）。
final aqiStationHourlyProvider = FutureProvider.autoDispose
    .family<AirQualityDataApi?, AqiStation>((ref, station) {
      return ref
          .watch(aqiHourlyDatasourceProvider)
          .fetchAirQuality(
            station.position.latitude,
            station.position.longitude,
          );
    });
