import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// 和风天气 API 测试（纯 Dart 版本）
void main() async {
  print('🌤️ 和风天气 API 测试');
  print('=' * 50);

  // 配置
  const String credentialId = 'KNB28DQJ4P';
  const String projectId = '34KXEK29E5';
  const String privateKeyPath = 'assets/keys/private_key.pem';
  const String apiHost = 'mp52qdxmd9.re.qweatherapi.com';
  final String baseUrl = 'https://$apiHost/v7/';

  try {
    // 生成 JWT Token（使用 OpenSSL 命令行）
    final token = await _generateJWT(credentialId, projectId, privateKeyPath);
    print('\n✅ JWT Token 生成成功');
    print('Token: ${token.substring(0, 50)}...');

    // 创建 Dio 实例
    final dio = Dio()
      ..options.baseUrl = baseUrl
      ..options.headers['Authorization'] = 'Bearer $token';

    // 测试 1：获取实时天气（北京）
    print('\n🌡️ 测试实时天气...');
    try {
      final response = await dio.get(
        'weather/now',
        queryParameters: {'location': '101010100'},
      );
      
      final data = response.data as Map<String, dynamic>;
      if (data['code'] == '200') {
        final now = data['now'] as Map<String, dynamic>;
        print('✅ 实时天气获取成功！');
        print('  温度：${now['temp']}°C');
        print('  天气：${now['text']}');
        print('  湿度：${now['humidity']}%');
        print('  风向：${now['windDir']}');
        print('  风速：${now['windSpeed']} km/h');
      } else {
        print('❌ API 返回错误：${data['code']}');
      }
    } catch (e) {
      print('❌ 获取实时天气失败：$e');
    }

    // 测试 2：获取7天预报
    print('\n📅 测试7天预报...');
    try {
      final response = await dio.get(
        'weather/7d',
        queryParameters: {'location': '101010100'},
      );
      
      final data = response.data as Map<String, dynamic>;
      if (data['code'] == '200') {
        final daily = data['daily'] as List<dynamic>;
        print('✅ 7天预报获取成功！');
        for (var day in daily.take(3)) {
          print('  ${day['fxDate']}: ${day['tempMin']}°C - ${day['tempMax']}°C ${day['textDay']}');
        }
      } else {
        print('❌ API 返回错误：${data['code']}');
      }
    } catch (e) {
      print('❌ 获取7天预报失败：$e');
    }

    // 测试 3：获取空气质量
    print('\n🌫️ 测试空气质量...');
    try {
      final response = await dio.get(
        'air/now',
        queryParameters: {'location': '101010100'},
      );
      
      final data = response.data as Map<String, dynamic>;
      if (data['code'] == '200') {
        final now = data['now'] as Map<String, dynamic>;
        print('✅ 空气质量获取成功！');
        print('  AQI：${now['aqi']}');
        print('  等级：${now['category']}');
        print('  PM2.5：${now['pm2p5']}');
      } else {
        print('❌ API 返回错误：${data['code']}');
      }
    } catch (e) {
      print('❌ 获取空气质量失败：$e');
    }

    print('\n' + '=' * 50);
    print('✅ 所有测试完成！');

  } catch (e, stackTrace) {
    print('\n❌ 测试失败：');
    print(e);
    print('\n堆栈跟踪：');
    print(stackTrace);
  }
}

/// 生成 JWT Token（使用 OpenSSL 命令行）
Future<String> _generateJWT(
  String credentialId,
  String projectId,
  String privateKeyPath,
) async {
  final now = DateTime.now();
  final iat = now.millisecondsSinceEpoch ~/ 1000 - 30;
  final exp = iat + 900;

  // 创建 header 和 payload
  final header = jsonEncode({
    'alg': 'EdDSA',
    'kid': credentialId,
  });

  final payload = jsonEncode({
    'sub': projectId,
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
  final tmpFile = File(
    '${Directory.systemTemp.path}/jwt_data_${DateTime.now().millisecondsSinceEpoch}.txt',
  );
  await tmpFile.writeAsString(headerPayload);

  try {
    final result = await Process.run(
      'openssl',
      [
        'pkeyutl',
        '-sign',
        '-inkey', privateKeyPath,
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
