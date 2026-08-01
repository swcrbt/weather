import 'dart:convert';
import 'dart:math';

/// 降水预警服务
/// 基于和风天气分钟级降水数据提供预警功能
class PrecipitationAlertService {
  /// 降水强度等级
  static const Map<String, double> _precipitationLevels = {
    '无雨': 0.0,
    '小雨': 0.1,
    '中雨': 2.5,
    '大雨': 8.0,
    '暴雨': 20.0,
  };

  /// 分析分钟级降水数据，生成预警信息
  /// 
  /// [minuteData] 分钟级降水数据，格式：
  /// ```json
  /// {
  ///   "minutely": [
  ///     {"fxTime": "2024-01-01T12:00+08:00", "precip": "0.0", "type": "rain"},
  ///     ...
  ///   ]
  /// }
  /// ```
  /// 
  /// 返回预警信息，如果没有降水则返回 null
  static String? analyzePrecipitationAlert(Map<String, dynamic> data) {
    try {
      final minutely = data['minutely'] as List<dynamic>?;
      if (minutely == null || minutely.isEmpty) {
        return null;
      }

      // 查找第一个有降水的时间点
      int firstRainIndex = -1;
      double firstRainAmount = 0.0;
      
      for (int i = 0; i < minutely.length; i++) {
        final minute = minutely[i] as Map<String, dynamic>;
        final precip = double.tryParse(minute['precip'].toString()) ?? 0.0;
        
        if (precip > 0) {
          firstRainIndex = i;
          firstRainAmount = precip;
          break;
        }
      }

      // 如果没有降水
      if (firstRainIndex == -1) {
        return null;
      }

      // 计算距离降水开始的时间（分钟）
      final minutesUntilRain = firstRainIndex * 5; // 每5分钟一个数据点
      
      // 判断降水强度
      String intensity = _getIntensityDescription(firstRainAmount);
      
      // 生成预警信息
      if (minutesUntilRain == 0) {
        return '正在下$intensity';
      } else if (minutesUntilRain <= 30) {
        return '${minutesUntilRain}分钟后开始下$intensity';
      } else if (minutesUntilRain <= 60) {
        return '${minutesUntilRain ~/ 60}小时${minutesUntilRain % 60}分钟后开始下$intensity';
      } else {
        return '${minutesUntilRain ~/ 60}小时后开始下$intensity';
      }

    } catch (e) {
      return null;
    }
  }

  /// 获取降水强度描述
  static String _getIntensityDescription(double precip) {
    if (precip >= _precipitationLevels['暴雨']!) {
      return '暴雨';
    } else if (precip >= _precipitationLevels['大雨']!) {
      return '大雨';
    } else if (precip >= _precipitationLevels['中雨']!) {
      return '中雨';
    } else if (precip >= _precipitationLevels['小雨']!) {
      return '小雨';
    }
    return '小雨';
  }

  /// 获取降水趋势（未来2小时）
  /// 
  /// 返回降水趋势描述：持续、减弱、增强
  static String getPrecipitationTrend(List<dynamic> minutely) {
    if (minutely.length < 12) return ''; // 需要至少1小时的数据

    // 计算前30分钟和后30分钟的平均降水强度
    double firstHalfSum = 0;
    double secondHalfSum = 0;

    for (int i = 0; i < 6 && i < minutely.length; i++) {
      final minute = minutely[i] as Map<String, dynamic>;
      firstHalfSum += double.tryParse(minute['precip'].toString()) ?? 0.0;
    }

    for (int i = 6; i < 12 && i < minutely.length; i++) {
      final minute = minutely[i] as Map<String, dynamic>;
      secondHalfSum += double.tryParse(minute['precip'].toString()) ?? 0.0;
    }

    final firstHalfAvg = firstHalfSum / 6;
    final secondHalfAvg = secondHalfSum / 6;

    // 判断趋势
    if (secondHalfAvg > firstHalfAvg * 1.5) {
      return '增强';
    } else if (secondHalfAvg < firstHalfAvg * 0.5) {
      return '减弱';
    } else {
      return '持续';
    }
  }

  /// 生成降水图表数据（用于小部件显示）
  /// 
  /// 返回未来60分钟的降水强度数组（0-100）
  static List<int> generateChartData(List<dynamic> minutely) {
    final data = <int>[];
    
    for (int i = 0; i < min(12, minutely.length); i++) {
      final minute = minutely[i] as Map<String, dynamic>;
      final precip = double.tryParse(minute['precip'].toString()) ?? 0.0;
      
      // 将降水强度映射到 0-100
      int intensity;
      if (precip >= 20) {
        intensity = 100;
      } else if (precip >= 8) {
        intensity = 75 + ((precip - 8) / 12 * 25).round();
      } else if (precip >= 2.5) {
        intensity = 50 + ((precip - 2.5) / 5.5 * 25).round();
      } else if (precip >= 0.1) {
        intensity = 10 + ((precip - 0.1) / 2.4 * 40).round();
      } else {
        intensity = 0;
      }
      
      data.add(intensity.clamp(0, 100));
    }
    
    return data;
  }
}
