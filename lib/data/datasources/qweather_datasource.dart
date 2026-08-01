import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:rain/core/auth/jwt_auth_manager.dart';
import 'package:rain/core/utils/debug_log.dart';

/// 和风天气数据源实现（JWT 认证版本）
/// 支持：实时天气、预报、空气质量、分钟级降水
class QWeatherDataSource {
  QWeatherDataSource({
    Dio? dio,
    required this.credentialId,
    required String privateKeyPath,
  }) : _dio = dio ?? Dio()
    ..options.baseUrl = 'https://devapi.qweather.com/v7/' {
    // 加载私钥并创建 JWT 管理器
    final privateKey = File(privateKeyPath).readAsStringSync();
    _jwtAuth = JWTAuthManager(
      credentialId: credentialId,
      privateKeyPem: privateKey,
    );
  }

  final Dio _dio;
  final String credentialId;
  late final JWTAuthManager _jwtAuth;

  /// 获取认证后的 Dio 实例
  Dio get _authDio {
    final headers = _jwtAuth.getAuthHeaders();
    return Dio()
      ..options.baseUrl = _dio.options.baseUrl
      ..options.headers.addAll(headers);
  }

  /// 获取实时天气
  Future<Map<String, dynamic>> getCurrentWeather(String locationId) async {
    try {
      final response = await _authDio.get(
        'weather/now',
        queryParameters: {
          'location': locationId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, stackTrace) {
      debugLogError('QWeatherDataSource.getCurrentWeather', e, stackTrace);
      rethrow;
    }
  }

  /// 获取7天预报
  Future<Map<String, dynamic>> get7DayForecast(String locationId) async {
    try {
      final response = await _authDio.get(
        'weather/7d',
        queryParameters: {
          'location': locationId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, stackTrace) {
      debugLogError('QWeatherDataSource.get7DayForecast', e, stackTrace);
      rethrow;
    }
  }

  /// 获取分钟级降水预报
  Future<Map<String, dynamic>> getMinutePrecipitation(
    double lat,
    double lon,
  ) async {
    try {
      final response = await _authDio.get(
        'minutely/5m',
        queryParameters: {
          'location': '$lon,$lat',
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, stackTrace) {
      debugLogError('QWeatherDataSource.getMinutePrecipitation', e, stackTrace);
      rethrow;
    }
  }

  /// 获取空气质量
  Future<Map<String, dynamic>> getAirQuality(String locationId) async {
    try {
      final response = await _authDio.get(
        'air/now',
        queryParameters: {
          'location': locationId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, stackTrace) {
      debugLogError('QWeatherDataSource.getAirQuality', e, stackTrace);
      rethrow;
    }
  }

  /// 城市搜索
  Future<List<Map<String, dynamic>>> searchCities(String query) async {
    try {
      final response = await _authDio.get(
        'https://geoapi.qweather.com/v2/city/lookup',
        queryParameters: {
          'location': query,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return (data['location'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e, stackTrace) {
      debugLogError('QWeatherDataSource.searchCities', e, stackTrace);
      rethrow;
    }
  }
}
