import 'package:flutter/material.dart';
import 'package:rain/data/datasources/qweather_datasource.dart';

/// 和风天气 API 使用示例
class QWeatherExample {
  /// 示例：获取实时天气
  static Future<void> getCurrentWeatherExample() async {
    final qweather = QWeatherDataSource();
    
    try {
      // 使用城市 ID 获取实时天气
      // 广州的城市 ID 示例：101280101
      final weather = await qweather.getCurrentWeather('101280101');
      
      debugPrint('实时天气：');
      debugPrint('温度：${weather['now']['temp']}°C');
      debugPrint('天气：${weather['now']['text']}');
      debugPrint('湿度：${weather['now']['humidity']}%');
    } catch (e) {
      debugPrint('获取天气失败：$e');
    }
  }
  
  /// 示例：获取7天预报
  static Future<void> get7DayForecastExample() async {
    final qweather = QWeatherDataSource();
    
    try {
      final forecast = await qweather.get7DayForecast('101280101');
      
      debugPrint('7天预报：');
      final daily = forecast['daily'] as List<dynamic>;
      for (var day in daily) {
        debugPrint(
          '${day['fxDate']}: '
          '${day['tempMin']}°C - ${day['tempMax']}°C '
          '${day['textDay']}'
        );
      }
    } catch (e) {
      debugPrint('获取预报失败：$e');
    }
  }
  
  /// 示例：获取分钟级降水预报
  static Future<void> getMinutePrecipitationExample() async {
    final qweather = QWeatherDataSource();
    
    try {
      // 广州的经纬度：23.1291, 113.2644
      final precipitation = await qweather.getMinutePrecipitation(23.1291, 113.2644);
      
      debugPrint('分钟级降水预报：');
      final minutely = precipitation['minutely'] as List<dynamic>;
      for (var minute in minutely.take(5)) {
        debugPrint('${minute['fxTime']}: ${minute['precip']}mm');
      }
    } catch (e) {
      debugPrint('获取降水预报失败：$e');
    }
  }
  
  /// 示例：获取空气质量
  static Future<void> getAirQualityExample() async {
    final qweather = QWeatherDataSource();
    
    try {
      final aqi = await qweather.getAirQuality('101280101');
      
      debugPrint('空气质量：');
      debugPrint('AQI：${aqi['now']['aqi']}');
      debugPrint('等级：${aqi['now']['category']}');
      debugPrint('PM2.5：${aqi['now']['pm2p5']}');
    } catch (e) {
      debugPrint('获取空气质量失败：$e');
    }
  }
  
  /// 示例：搜索城市
  static Future<void> searchCitiesExample() async {
    final qweather = QWeatherDataSource();
    
    try {
      final cities = await qweather.searchCities('广州');
      
      debugPrint('搜索结果：');
      for (var city in cities.take(5)) {
        debugPrint(
          '${city['name']} (${city['id']}): '
          '${city['lat']}, ${city['lon']}'
        );
      }
    } catch (e) {
      debugPrint('搜索城市失败：$e');
    }
  }
}
