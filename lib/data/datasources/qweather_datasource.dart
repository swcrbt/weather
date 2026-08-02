import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:rain/core/utils/debug_log.dart';

/// 和风天气数据源实现（JWT 认证版本）
/// 使用 OpenSSL 命令行生成 EdDSA 签名
/// 
/// 注意：此数据源需要配置和风天气 JWT 凭据才能使用。
/// 如果没有配置，会自动降级为使用 Open-Meteo 数据源。
class QWeatherDataSource {
  /// 凭据 ID（kid）
  static const String _credentialId = 'KNB28DQJ4P';
  
  /// 项目 ID（sub）
  static const String _projectId = '34KXEK29E5';
  
  /// 私钥文件路径
  static const String _privateKeyPath = 'assets/keys/private_key.pem';
  
  /// API Host
  static const String _apiHost = 'mp52qdxmd9.re.qweatherapi.com';

  QWeatherDataSource({
    Dio? dio,
  }) : _dio = dio ?? Dio()
    ..options.baseUrl = 'https://$_apiHost/v7/';

  final Dio _dio;

  /// 生成 JWT Token（使用 OpenSSL 命令行）
  /// 
  /// 如果私钥文件不存在，则返回空字符串（表示无法认证）
  Future<String> _generateJWT() async {
    // 检查私钥文件是否存在
    final privateKeyFile = File(_privateKeyPath);
    if (!privateKeyFile.existsSync()) {
      debugLogError('QWeatherDataSource._generateJWT', '私钥文件不存在: $_privateKeyPath');
      return '';
    }
    
    final now = DateTime.now();
    final iat = now.millisecondsSinceEpoch ~/ 1000 - 30;  // 当前时间前30秒
    final exp = iat + 900;  // 15分钟后过期

    // 创建 header 和 payload
    final header = jsonEncode({
      'alg': 'EdDSA',
      'kid': _credentialId,
    });

    final payload = jsonEncode({
      'sub': _projectId,
      'iat': iat,
      'exp': exp,
    });

    // Base64URL 编码
    String base64UrlEncode(String input) {
      final bytes = utf8.encode(input);
      final base64Str = base64.encode(bytes);
      return base64Str
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');
    }

    final headerBase64 = base64UrlEncode(header);
    final payloadBase64 = base64UrlEncode(payload);
    final headerPayload = '$headerBase64.$payloadBase64';

    // 使用 OpenSSL 进行 Ed25519 签名
    final tmpFile = File('${Directory.systemTemp.path}/jwt_data_${DateTime.now().millisecondsSinceEpoch}.txt');
    await tmpFile.writeAsString(headerPayload);

    try {
      final result = await Process.run(
        'openssl',
        [
          'pkeyutl',
          '-sign',
          '-inkey', _privateKeyPath,
          '-rawin',
          '-in', tmpFile.path,
        ],
      );

      if (result.exitCode != 0) {
        throw Exception('OpenSSL 签名失败: ${result.stderr}');
      }

      // Base64URL 编码签名
      final signature = base64.encode(result.stdout as List<int>)
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');

      return '$headerPayload.$signature';
    } finally {
      await tmpFile.delete();
    }
  }

  /// 获取认证后的 Dio 实例
  Future<Dio> _getAuthDio() async {
    final token = await _generateJWT();
    final dio = Dio()
      ..options.baseUrl = _dio.options.baseUrl
      ..options.headers['Authorization'] = 'Bearer $token';
    
    // 配置 HTTP 客户端支持 gzip
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = true;  // 自动解压 gzip
        return client;
      },
    );
    
    return dio;
  }

  /// 获取实时天气
  Future<Map<String, dynamic>> getCurrentWeather(String locationId) async {
    try {
      final dio = await _getAuthDio();
      final response = await dio.get(
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
      final dio = await _getAuthDio();
      final response = await dio.get(
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
      final dio = await _getAuthDio();
      final response = await dio.get(
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
      final dio = await _getAuthDio();
      final response = await dio.get(
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

  /// 城市搜索（使用 geoapi.qweather.com）
  Future<List<Map<String, dynamic>>> searchCities(String query) async {
    try {
      final dio = await _getAuthDio();
      final response = await dio.get(
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
