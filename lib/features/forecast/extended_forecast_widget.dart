import 'package:flutter/material.dart';

/// 扩展预报组件
/// 显示14天预报和72小时预报
class ExtendedForecastWidget extends StatelessWidget {
  const ExtendedForecastWidget({
    super.key,
    required this.hourlyData,
    required this.dailyData,
  });

  /// 72小时逐小时预报数据
  final List<Map<String, dynamic>> hourlyData;

  /// 14天逐日预报数据
  final List<Map<String, dynamic>> dailyData;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab 切换
          TabBar(
            tabs: const [
              Tab(text: '72小时预报'),
              Tab(text: '14天预报'),
            ],
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
          
          // Tab 内容
          Expanded(
            child: TabBarView(
              children: [
                // 72小时预报
                _buildHourlyForecast(),
                
                // 14天预报
                _buildDailyForecast(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建72小时逐小时预报
  Widget _buildHourlyForecast() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: hourlyData.length,
      itemBuilder: (context, index) {
        final hour = hourlyData[index];
        return Container(
          width: 80,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 时间
              Text(
                hour['time'] ?? '--:--',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              
              // 天气图标
              Icon(
                _getWeatherIcon(hour['icon'] ?? 'cloud'),
                size: 24,
              ),
              const SizedBox(height: 8),
              
              // 温度
              Text(
                '${hour['temp'] ?? '--'}°',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // 降水概率
              if (hour['precipProbability'] != null)
                Text(
                  '${hour['precipProbability']}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建14天逐日预报
  Widget _buildDailyForecast() {
    return ListView.builder(
      itemCount: dailyData.length,
      itemBuilder: (context, index) {
        final day = dailyData[index];
        return ListTile(
          leading: SizedBox(
            width: 60,
            child: Text(
              day['date'] ?? '--/--',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          title: Row(
            children: [
              // 天气图标
              Icon(
                _getWeatherIcon(day['icon'] ?? 'cloud'),
                size: 24,
              ),
              const SizedBox(width: 8),
              
              // 天气描述
              Expanded(
                child: Text(
                  day['text'] ?? '--',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          trailing: SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 最高温度
                Text(
                  '${day['tempMax'] ?? '--'}°',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                
                // 温度范围指示
                Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade300,
                        Colors.blue.shade300,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                
                // 最低温度
                Text(
                  '${day['tempMin'] ?? '--'}°',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 根据天气图标名称获取图标
  IconData _getWeatherIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'sun':
      case 'clear':
        return Icons.wb_sunny;
      case 'cloud':
        return Icons.cloud;
      case 'rain':
        return Icons.water_drop;
      case 'snow':
        return Icons.ac_unit;
      case 'storm':
        return Icons.thunderstorm;
      case 'fog':
        return Icons.foggy;
      default:
        return Icons.cloud;
    }
  }
}
