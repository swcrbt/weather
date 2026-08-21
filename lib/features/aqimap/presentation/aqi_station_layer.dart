import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rain/core/weather/aqi_helper.dart';
import 'package:rain/features/aqimap/domain/aqi_station.dart';
import 'package:rain/features/aqimap/presentation/aqi_station_detail_sheet.dart';

/// 监测站 AQI 数字气泡图层（彩云式青色圆角气泡，点击展开详情）。
class AqiStationLayer extends StatelessWidget {
  const AqiStationLayer({
    super.key,
    required this.stations,
    this.nearestStationId,
  });

  final List<AqiStation> stations;

  /// 距主位置最近的站点 id（详情卡片显示「最近的站点」标签）。
  final String? nearestStationId;

  @override
  Widget build(BuildContext context) => MarkerLayer(
    markers: [
      for (final station in stations)
        Marker(
          point: station.position,
          width: 44,
          height: 36,
          child: GestureDetector(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => AqiStationDetailSheet(
                station: station,
                isNearest: station.id == nearestStationId,
              ),
            ),
            child: _AqiStationBubble(station: station),
          ),
        ),
    ],
  );
}

class _AqiStationBubble extends StatelessWidget {
  const _AqiStationBubble({required this.station});

  final AqiStation station;

  @override
  Widget build(BuildContext context) {
    // 气泡数值始终是实测 US EPA AQI，配色也固定用 US 标准，避免与
    // 热力图所选标准混淆（图例仅描述热力图）。
    final color = AqiHelper.severityColor(AqiHelper.american, station.aqi);
    return Tooltip(
      message:
          '${station.name} · AQI ${station.aqi.round()} · '
          '${AqiHelper.severityLabel(AqiHelper.american, station.aqi)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
        ),
        child: Center(
          child: Text(
            '${station.aqi.round()}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
