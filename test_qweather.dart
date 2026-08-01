import 'dart:io';
import 'package:rain/data/datasources/qweather_datasource.dart';

/// 测试和风天气 API 连接
void main() async {
  print('️ 和风天气 API 测试');
  print('=' * 50);

  try {
    final qweather = QWeatherDataSource();

    // 测试 1：搜索城市
    print('\n📍 测试城市搜索...');
    final cities = await qweather.searchCities('广州');
    if (cities.isNotEmpty) {
      print('✅ 城市搜索成功！');
      print('找到 ${cities.length} 个城市：');
      for (var city in cities.take(3)) {
        print('  - ${city['name']} (ID: ${city['id']})');
      }
    } else {
      print('❌ 未找到城市');
    }

    // 使用广州的城市 ID
    final guangzhouId = '101280101';

    // 测试 2：获取实时天气
    print('\n🌡️ 测试实时天气...');
    final weather = await qweather.getCurrentWeather(guangzhouId);
    if (weather.containsKey('now')) {
      final now = weather['now'] as Map<String, dynamic>;
      print('✅ 实时天气获取成功！');
      print('  温度：${now['temp']}°C');
      print('  天气：${now['text']}');
      print('  湿度：${now['humidity']}%');
      print('  风向：${now['windDir']}');
      print('  风速：${now['windSpeed']} km/h');
    } else {
      print('❌ 获取实时天气失败');
      print('响应：$weather');
    }

    // 测试 3：获取7天预报
    print('\n📅 测试7天预报...');
    final forecast = await qweather.get7DayForecast(guangzhouId);
    if (forecast.containsKey('daily')) {
      final daily = forecast['daily'] as List<dynamic>;
      print('✅ 7天预报获取成功！');
      print('未来7天天气：');
      for (var day in daily.take(3)) {
        print('  ${day['fxDate']}: ${day['tempMin']}°C - ${day['tempMax']}°C ${day['textDay']}');
      }
    } else {
      print('❌ 获取7天预报失败');
      print('响应：$forecast');
    }

    // 测试 4：获取空气质量
    print('\n 测试空气质量...');
    final aqi = await qweather.getAirQuality(guangzhouId);
    if (aqi.containsKey('now')) {
      final now = aqi['now'] as Map<String, dynamic>;
      print('✅ 空气质量获取成功！');
      print('  AQI：${now['aqi']}');
      print('  等级：${now['category']}');
      print('  PM2.5：${now['pm2p5']}');
    } else {
      print(' 获取空气质量失败');
      print('响应：$aqi');
    }

    // 测试 5：获取分钟级降水
    print('\n️ 测试分钟级降水...');
    final precipitation = await qweather.getMinutePrecipitation(23.1291, 113.2644);
    if (precipitation.containsKey('minutely')) {
      final minutely = precipitation['minutely'] as List<dynamic>;
      print('✅ 分钟级降水获取成功！');
      print('未来5分钟降水：');
      for (var minute in minutely.take(5)) {
        print('  ${minute['fxTime']}: ${minute['precip']}mm');
      }
    } else {
      print('❌ 获取分钟级降水失败');
      print('响应：$precipitation');
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
