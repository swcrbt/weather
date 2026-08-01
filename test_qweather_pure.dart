import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dio/dio.dart';

/// 和风天气 API 测试（纯 Dart 版本）
void main() async {
  print('🌤️ 和风天气 API 测试');
  print('=' * 50);

  // 配置
  const String credentialId = 'KNB28DQJ4P';  // 凭据 ID (kid)
  const String projectId = '34KXEK29E5';       // 项目 ID (sub)
  const String privateKeyPath = 'assets/keys/private_key.pem';
  // 使用和风天气分配的独立 API Host
  const String apiHost = 'mp52qdxmd9.re.qweatherapi.com';
  final String baseUrl = 'https://$apiHost/v7/';

  try {
    // 加载私钥（转换为 bytes）
    final privateKeyBytes = File(privateKeyPath).readAsBytesSync();
    
    // 创建 JWT
    final jwt = JWT(
      {
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30,  // 当前时间前30秒，防止时间误差
        'exp': DateTime.now().add(Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,  // 15分钟后过期
        'sub': projectId,  // 项目 ID
      },
      header: {
        'alg': 'EdDSA',
        'kid': credentialId,  // 凭据 ID
      },
    );

    final token = jwt.sign(
      EdDSAPrivateKey(privateKeyBytes),
      algorithm: JWTAlgorithm.EdDSA,
    );

    print('\n✅ JWT Token 生成成功');
    print('Token: ${token.substring(0, 50)}...');

    // 创建 Dio 实例
    final dio = Dio()
      ..options.baseUrl = baseUrl
      ..options.headers['Authorization'] = 'Bearer $token';

    // 添加请求拦截器，打印请求详情（用于调试）
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => print('[DIO] $obj'),
    ));

    // 测试 1：搜索城市（GeoAPI 使用独立的域名）
    print('\n📍 测试城市搜索...');
    try {
      final response = await dio.get(
        'https://geoapi.qweather.com/v2/city/lookup',
        queryParameters: {'location': '广州'},
      );
      
      final data = response.data as Map<String, dynamic>;
      if (data['code'] == '200') {
        final cities = data['location'] as List<dynamic>;
        print('✅ 城市搜索成功！找到 ${cities.length} 个城市');
        for (var city in cities.take(3)) {
          print('  - ${city['name']} (ID: ${city['id']})');
        }
      } else {
        print('❌ API 返回错误：${data['code']}');
      }
    } catch (e) {
      print('❌ 城市搜索失败：$e');
    }

    // 使用广州的城市 ID
    const String guangzhouId = '101280101';

    // 测试 2：获取实时天气
    print('\n🌡️ 测试实时天气...');
    try {
      final response = await dio.get(
        'weather/now',
        queryParameters: {'location': guangzhouId},
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

    // 测试 3：获取7天预报
    print('\n📅 测试7天预报...');
    try {
      final response = await dio.get(
        'weather/7d',
        queryParameters: {'location': guangzhouId},
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

    // 测试 4：获取空气质量
    print('\n🌫️ 测试空气质量...');
    try {
      final response = await dio.get(
        'air/now',
        queryParameters: {'location': guangzhouId},
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

    // 测试 5：获取分钟级降水
    print('\n🌧️ 测试分钟级降水...');
    try {
      final response = await dio.get(
        'minutely/5m',
        queryParameters: {'location': '113.2644,23.1291'},
      );
      
      final data = response.data as Map<String, dynamic>;
      if (data['code'] == '200') {
        final minutely = data['minutely'] as List<dynamic>;
        print('✅ 分钟级降水获取成功！');
        for (var minute in minutely.take(5)) {
          print('  ${minute['fxTime']}: ${minute['precip']}mm');
        }
      } else {
        print('❌ API 返回错误：${data['code']}');
      }
    } catch (e) {
      print('❌ 获取分钟级降水失败：$e');
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
