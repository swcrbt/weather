import 'package:rain/data/datasources/qweather_datasource.dart';

/// 和风天气 API 测试
void main() async {
  print('🌤️ 和风天气 API 测试');
  print('=' * 50);

  final qweather = QWeatherDataSource();

  try {
    // 测试 1：获取实时天气（北京）
    print('\n🌡️ 测试实时天气...');
    final weather = await qweather.getCurrentWeather('101010100');
    if (weather['code'] == '200') {
      final now = weather['now'] as Map<String, dynamic>;
      print('✅ 实时天气获取成功！');
      print('  温度：${now['temp']}°C');
      print('  天气：${now['text']}');
      print('  湿度：${now['humidity']}%');
    } else {
      print('❌ API 返回错误：${weather['code']}');
    }

    // 测试 2：获取7天预报
    print('\n📅 测试7天预报...');
    final forecast = await qweather.get7DayForecast('101010100');
    if (forecast['code'] == '200') {
      final daily = forecast['daily'] as List<dynamic>;
      print('✅ 7天预报获取成功！');
      for (var day in daily.take(3)) {
        print('  ${day['fxDate']}: ${day['tempMin']}°C - ${day['tempMax']}°C ${day['textDay']}');
      }
    } else {
      print('❌ API 返回错误：${forecast['code']}');
    }

    // 测试 3：获取空气质量
    print('\n🌫️ 测试空气质量...');
    final aqi = await qweather.getAirQuality('101010100');
    if (aqi['code'] == '200') {
      final now = aqi['now'] as Map<String, dynamic>;
      print('✅ 空气质量获取成功！');
      print('  AQI：${now['aqi']}');
      print('  等级：${now['category']}');
    } else {
      print('❌ API 返回错误：${aqi['code']}');
    }

    print('\n' + '=' * 50);
    print('✅ 所有测试完成！');

  } catch (e) {
    print('\n❌ 测试失败：$e');
  }
}
