import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rain/core/constants/app_constants.dart';
import 'package:rain/core/di/provider_refs.dart';
import 'package:rain/core/utils/url_launcher_util.dart';
import 'package:rain/core/weather/aqi_helper.dart';
import 'package:rain/data/models/air_quality_api.dart';
import 'package:rain/features/aqimap/application/aqi_map_providers.dart';
import 'package:rain/features/aqimap/domain/aqi_station.dart';
import 'package:rain/i18n/tr.dart';

/// 监测站详情底部卡片：实测 AQI/PM2.5/PM10 + 逐小时 AQI 柱状图。
class AqiStationDetailSheet extends ConsumerWidget {
  const AqiStationDetailSheet({
    super.key,
    required this.station,
    this.isNearest = false,
  });

  final AqiStation station;

  /// 是否为距主位置最近的站点（彩云「最近的站点」标签）。
  final bool isNearest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final standard = settings.aqiStandard;
    final color = AqiHelper.severityColor(AqiHelper.american, station.aqi);
    final hourly = ref.watch(aqiStationHourlyProvider(station)).asData?.value;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        station.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isNearest)
                        Chip(
                          label: Text('aqiStationNearest'.tr),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelStyle: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _AqiRing(station: station, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AqiHelper.severityLabel(
                          AqiHelper.american,
                          station.aqi,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'aqiStationMeasured'.tr,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _PollutantTile(label: 'pm25'.tr, value: station.pm25),
                const SizedBox(width: 8),
                _PollutantTile(label: 'pm10'.tr, value: station.pm10),
              ],
            ),
            const SizedBox(height: 16),
            if (hourly != null)
              _HourlyBarChart(
                hourly: hourly,
                standard: standard,
                barColor: color,
              )
            else
              const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => openUrl(AppConstants.qweatherAttributionUrl),
              child: Text(
                'aqiStationDataSource'.tr,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AqiRing extends StatelessWidget {
  const _AqiRing({required this.station, required this.color});

  final AqiStation station;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 3),
    ),
    child: Center(
      child: Text(
        '${station.aqi.round()}',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ),
  );
}

class _PollutantTile extends StatelessWidget {
  const _PollutantTile({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                value == null ? '—' : '${value!.round()}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('µg/m³', style: theme.textTheme.labelSmall),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// 未来 24 小时逐小时 AQI 柱状图，当前小时高亮。
class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({
    required this.hourly,
    required this.standard,
    required this.barColor,
  });

  final AirQualityDataApi hourly;
  final String standard;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final series =
        (standard == AqiHelper.american
            ? hourly.hourly.usAqi
            : hourly.hourly.europeanAqi) ??
        const <double?>[];
    final times = hourly.hourly.time ?? const <String>[];
    if (series.isEmpty || times.isEmpty) return const SizedBox.shrink();

    // 与主数据源一致：timezone=auto，时间串为当地时间（无 offset）。
    final now = DateTime.now();
    var startIndex = 0;
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.tryParse(times[i]);
      if (t != null && !t.isAfter(now)) startIndex = i;
    }

    final visible = <int>[];
    for (var i = startIndex; i < series.length && visible.length < 24; i++) {
      visible.add(i);
    }
    if (visible.isEmpty) return const SizedBox.shrink();

    final values = [for (final i in visible) series[i] ?? 0.0];
    final maxValue = values.fold<double>(
      AqiHelper.scaleMax(standard) / 2,
      (a, b) => b > a ? b : a,
    );

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var k = 0; k < visible.length; k++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: FractionallySizedBox(
                      heightFactor: (values[k] / maxValue).clamp(0.04, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: k == 0
                              ? barColor
                              : barColor.withValues(alpha: 0.65),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('now'.tr, style: theme.textTheme.labelSmall),
            for (final offset in [6, 12, 18])
              if (offset < visible.length)
                Text(
                  DateFormat(
                    'HH:mm',
                  ).format(DateTime.parse(times[visible[offset]])),
                  style: theme.textTheme.labelSmall,
                ),
            Text(
              DateFormat('HH:mm').format(DateTime.parse(times[visible.last])),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}
