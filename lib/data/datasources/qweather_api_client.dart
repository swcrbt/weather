import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:rain/core/utils/debug_log.dart';

/// 和风 API 失败（非 200 业务码）。
class QWeatherApiException implements Exception {
  const QWeatherApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'QWeatherApiException($code): $message';
}

/// 编译期注入的凭据缺失。
class QWeatherCredentialsException implements Exception {
  const QWeatherCredentialsException(this.detail);

  final String detail;

  @override
  String toString() => 'QWeatherCredentialsException: $detail';
}

/// 和风天气 API 客户端：JWT 认证 + 天气/空气质量/预警端点。
///
/// 凭据通过 `--dart-define` 在构建期注入（release 构建由 CI 强校验），
/// 私钥通过 Flutter assets 加载。任何凭据不完整的情况都会「快速失败」，
/// 调用层不应在缺失凭据的环境中静默降级。
class QWeatherApiClient {
  QWeatherApiClient({
    Dio? dio,
    Dio? geoDio,
    Future<String> Function()? privateKeyLoader,
    String? credentialId,
    String? projectId,
    String? apiHost,
  }) : _credentialId =
           credentialId ??
           const String.fromEnvironment('QWEATHER_CREDENTIAL_ID'),
       _projectId =
           projectId ??
           const String.fromEnvironment('QWEATHER_PROJECT_ID'),
       _apiHost =
           apiHost ?? const String.fromEnvironment('QWEATHER_API_HOST'),
       _privateKeyLoader =
           privateKeyLoader ??
           (() =>
               rootBundle.loadString('assets/keys/private_key.pem')) {
    final dioInstance = dio ?? Dio();
    dioInstance.options.baseUrl = 'https://$_apiHost/';
    _dio = dioInstance;
    _geoDio =
        geoDio ??
        (Dio()..options.baseUrl = 'https://$_apiHost/geoapi/');
    _installAuthInterceptor();
  }

  final String _credentialId;
  final String _projectId;
  final String _apiHost;
  final Future<String> Function() _privateKeyLoader;
  late final Dio _dio;
  late final Dio _geoDio;

  Future<String>? _privateKeyFuture;
  String? _jwtToken;
  int _jwtExpiryEpoch = 0;

  /// Builds the Authorization header value, reusing a cached JWT until expiry.
  Future<String> _authToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_jwtToken != null && now < _jwtExpiryEpoch - 60) {
      return _jwtToken!;
    }

    if (_credentialId.isEmpty) {
      throw const QWeatherCredentialsException(
        'QWEATHER_CREDENTIAL_ID is not configured',
      );
    }
    if (_projectId.isEmpty) {
      throw const QWeatherCredentialsException(
        'QWEATHER_PROJECT_ID is not configured',
      );
    }
    if (_apiHost.isEmpty) {
      throw const QWeatherCredentialsException(
        'QWEATHER_API_HOST is not configured',
      );
    }

    _privateKeyFuture ??= _privateKeyLoader();
    final String pem;
    try {
      pem = await _privateKeyFuture!;
    } catch (e) {
      // 加载失败后允许下次调用重试，避免永久缓存 failed future。
      _privateKeyFuture = null;
      throw QWeatherCredentialsException(
        'failed to load assets/keys/private_key.pem: $e',
      );
    }
    if (pem.isEmpty) {
      throw const QWeatherCredentialsException(
        'assets/keys/private_key.pem is empty',
      );
    }

    try {
      final iat = now - 30;
      final exp = iat + 900;
      final jwt = JWT(
        {'sub': _projectId, 'iat': iat, 'exp': exp},
        header: {'alg': 'EdDSA', 'kid': _credentialId},
      );
      final key = EdDSAPrivateKey.fromPEM(pem);
      _jwtToken = jwt.sign(key, algorithm: JWTAlgorithm.EdDSA);
      _jwtExpiryEpoch = exp;
      return _jwtToken!;
    } catch (e, stackTrace) {
      debugLogError('QWeatherApiClient._authToken', e, stackTrace);
      throw QWeatherCredentialsException(
        'JWT signing failed with the configured private key: $e',
      );
    }
  }

  void _installAuthInterceptor() {
    Future<void> apply(RequestOptions options, RequestInterceptorHandler handler) async {
      try {
        options.headers['Authorization'] = 'Bearer ${await _authToken()}';
        handler.next(options);
      } catch (e, stackTrace) {
        debugLogError('QWeatherApiClient.authInterceptor', e, stackTrace);
        handler.reject(
          DioException(error: e, requestOptions: options, stackTrace: stackTrace),
        );
      }
    }

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) {
        apply(options, handler);
      }),
    );
    _geoDio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) {
        apply(options, handler);
      }),
    );
  }

  /// 校验响应业务码并返回 data 部分。
  static Map<String, dynamic> decode(
    Response<dynamic> response,
    String context,
  ) {
    final payload = response.data;
    if (payload is! Map) {
      throw QWeatherApiException(
        'bad-response',
        '$context: unexpected response shape',
      );
    }
    final code = payload['code']?.toString() ?? '';
    if (code != '200') {
      throw QWeatherApiException(code, '$context: ${payload.toString()}');
    }
    return Map<String, dynamic>.from(payload);
  }

  static const _fallbackLang = 'en';
  static const _supportedLangs = {'zh', 'zh-hant', 'en', 'ja', 'ko', 'de', 'fr', 'es', 'ru'};

  /// Maps app language codes onto QWeather lang values.
  static String langFor(String? languageCode) {
    final code = languageCode?.toLowerCase() ?? '';
    final short = code.split('-').first;
    if (short == 'zh') {
      return code.contains('tw') || code.contains('hant') ? 'zh-hant' : 'zh';
    }
    return _supportedLangs.contains(short) ? short : _fallbackLang;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    double? lat,
    double? lon,
    String? languageCode,
  }) async {
    final lang = langFor(languageCode);
    final response = await _dio.get(
      path,
      queryParameters: {
        if (lat != null && lon != null) 'location': '$lon,$lat',
        'lang': lang,
      },
    );
    return decode(response, path);
  }

  /// 实时天气（中国区为官方台站实测）。
  Future<Map<String, dynamic>> weatherNow(
    double lat,
    double lon, {
    String? languageCode,
  }) => _get('v7/weather/now', lat: lat, lon: lon, languageCode: languageCode);

  /// 24 小时逐小时预报。
  Future<Map<String, dynamic>> weather24h(
    double lat,
    double lon, {
    String? languageCode,
  }) => _get('v7/weather/24h', lat: lat, lon: lon, languageCode: languageCode);

  /// 7 天逐日预报。
  Future<Map<String, dynamic>> weather7d(
    double lat,
    double lon, {
    String? languageCode,
  }) => _get('v7/weather/7d', lat: lat, lon: lon, languageCode: languageCode);

  /// 分钟级降水（仅中国大陆覆盖）。
  Future<Map<String, dynamic>> minutely5m(
    double lat,
    double lon, {
    String? languageCode,
  }) => _get('v7/minutely/5m', lat: lat, lon: lon, languageCode: languageCode);

  /// 天气灾害预警。
  Future<Map<String, dynamic>> warningNow(
    double lat,
    double lon, {
    String? languageCode,
  }) => _get('v7/warning/now', lat: lat, lon: lon, languageCode: languageCode);

  /// 逐小时空气质量（新 AQI API，监测站实测）。
  Future<Map<String, dynamic>> airHourly(
    double lat,
    double lon, {
    String? languageCode,
  }) async {
    final lang = langFor(languageCode);
    final response = await _dio.get(
      'airquality/v1/hourly/${lat.toStringAsFixed(2)}/${lon.toStringAsFixed(2)}',
      queryParameters: {'lang': lang},
    );
    return decode(response, 'airquality/v1/hourly');
  }

  /// 城市搜索（geoapi，中日韩查询词体验优于 Open-Meteo）。
  Future<List<Map<String, dynamic>>> searchCities(
    String query, {
    String? languageCode,
  }) async {
    final lang = langFor(languageCode);
    final response = await _geoDio.get(
      'v2/city/lookup',
      queryParameters: {'location': query, 'lang': lang},
    );
    final payload = Map<String, dynamic>.from(
      decode(response, 'geoapi/v2/city/lookup'),
    );
    final locations = payload['location'];
    if (locations is! List) return const [];
    return locations
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// 校验私钥 PEM 是否可被 dart_jsonwebtoken 解析（构建期验证辅助）。
  static bool isValidPrivateKeyPem(String pem) {
    try {
      EdDSAPrivateKey.fromPEM(pem);
      return true;
    } catch (_) {
      return false;
    }
  }
}