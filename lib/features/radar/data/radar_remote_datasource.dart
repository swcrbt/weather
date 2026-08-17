import 'package:dio/dio.dart';
import 'package:rain/features/radar/domain/radar_timeline.dart';

/// 获取并校验 RainViewer 公开雷达时间轴。
class RadarRemoteDatasource {
  RadarRemoteDatasource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  static const endpoint = 'https://api.rainviewer.com/public/weather-maps.json';
  static const _minRadarTimestamp = 946684800; // 2000-01-01 UTC
  static const _maxRadarTimestamp = 4102444799; // 2099-12-31 UTC

  final Dio _dio;

  Future<RadarTimeline> fetchTimeline() async {
    final response = await _dio.get<Object?>(endpoint);
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid radar response');
    }

    final host = body['host'];
    final radar = body['radar'];
    if (host is! String || radar is! Map) {
      throw const FormatException('Incomplete radar response');
    }

    final hostUri = Uri.tryParse(host);
    final allowedHost =
        hostUri != null &&
        hostUri.scheme == 'https' &&
        hostUri.userInfo.isEmpty &&
        (hostUri.host == 'rainviewer.com' ||
            hostUri.host.endsWith('.rainviewer.com'));
    if (!allowedHost ||
        hostUri.path.isNotEmpty ||
        hostUri.hasQuery ||
        hostUri.hasFragment) {
      throw const FormatException('Invalid radar tile host');
    }

    final rawFrames = radar['past'];
    if (rawFrames is! List) {
      throw const FormatException('Missing radar frames');
    }

    final byTime = <int, RadarFrame>{};
    for (final rawFrame in rawFrames.take(30)) {
      if (rawFrame is! Map) continue;
      final time = rawFrame['time'];
      final path = rawFrame['path'];
      if (time is! int ||
          time < _minRadarTimestamp ||
          time > _maxRadarTimestamp ||
          path is! String ||
          !RegExp(r'^/v2/radar/[0-9a-f]{6,32}$').hasMatch(path)) {
        continue;
      }
      byTime[time] = RadarFrame(time: time, path: path);
    }

    final frames = byTime.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (frames.isEmpty) {
      throw const FormatException('No valid radar frames');
    }

    return RadarTimeline(host: host, frames: List.unmodifiable(frames));
  }
}
