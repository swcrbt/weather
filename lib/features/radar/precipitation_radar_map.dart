import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 降水雷达地图组件
/// 显示实时降水雷达图层
class PrecipitationRadarMap extends StatelessWidget {
  const PrecipitationRadarMap({
    super.key,
    required this.center,
    this.zoom = 8.0,
    this.showRadar = true,
  });

  /// 地图中心位置
  final LatLng center;

  /// 缩放级别
  final double zoom;

  /// 是否显示雷达图层
  final bool showRadar;

  /// 和风天气降水雷达图层 URL
  String get _radarUrl {
    return 'https://tiles.qweather.com/radar/{z}/{x}/{y}.png';
  }

  /// 基础地图图层 URL
  String get _baseMapUrl {
    return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
      ),
      children: [
        // 基础地图图层
        TileLayer(
          urlTemplate: _baseMapUrl,
          subdomains: const ['a', 'b', 'c'],
        ),
        
        // 降水雷达图层
        if (showRadar)
          TileLayer(
            urlTemplate: _radarUrl,
            subdomains: const ['a', 'b', 'c'],
          ),
        
        // 当前位置标记
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        
        // 图例
        const RadarLegend(),
      ],
    );
  }
}

/// 雷达图例
class RadarLegend extends StatelessWidget {
  const RadarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '降水强度',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem('暴雨', Colors.red),
            _buildLegendItem('大雨', Colors.orange),
            _buildLegendItem('中雨', Colors.yellow),
            _buildLegendItem('小雨', Colors.green),
            _buildLegendItem('无雨', Colors.transparent),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
