import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

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
    // 生成 JWT Token
    final token = await _generateJWT(credentialId, projectId, privateKeyPath);
    print('\n✅ JWT Token 生成成功');

    // 创建 Dio 实例
    final dio = Dio()
      ..options.baseUrl = baseUrl
      ..options.headers['Authorization'] = 'Bearer $token';
    
    // 配置 HTTP 客户端
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        return client;
      },
    );

    // 测试：获取实时天气（北京）
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
      } else {
        print('❌ API 返回错误：${data['code']}');
      }
    } catch (e) {
      print('❌ 获取实时天气失败：$e');
    }

    print('\n' + '=' * 50);
    print('✅ 测试完成！');

  } catch (e, stackTrace) {
    print('\n❌ 测试失败：');
    print(e);
    print('\n堆栈跟踪：');
    print(stackTrace);
  }
}

Future<String> _generateJWT(
  String credentialId,
  String projectId,
  String privateKeyPath,
) async {
  final now = DateTime.now();
  final iat = now.millisecondsSinceEpoch ~/ 1000 - 30;
  final exp = iat + 900;

  final header = jsonEncode({'alg': 'EdDSA', 'kid': credentialId});
  final payload = jsonEncode({'sub': projectId, 'iat': iat, 'exp': exp});

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

  final tmpFile = File(
    '${Directory.systemTemp.path}/jwt_data_${DateTime.now().millisecondsSinceEpoch}.txt',
  );
  await tmpFile.writeAsString(headerPayload);

  try {
    final result = await Process.run(
      'openssl',
      ['pkeyutl', '-sign', '-inkey', privateKeyPath, '-rawin', '-in', tmpFile.path],
    );

    if (result.exitCode != 0) {
      throw Exception('OpenSSL 签名失败: ${result.stderr}');
    }

    final signature = base64.encode(result.stdout as List<int>)
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');

    return '$headerPayload.$signature';
  } finally {
    await tmpFile.delete();
  }
}
