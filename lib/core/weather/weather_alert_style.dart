import 'package:flutter/material.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/i18n/tr.dart';

/// 预警级别 → 颜色/排序，供 banner、详情页与卡片角标共用。
class WeatherAlertStyle {
  WeatherAlertStyle._();

  /// 仅保留 active 且未过期的预警，按级别从高到低排序。
  ///
  /// alert 时间为 UTC 时刻，与 DateTime.now() 直接比较（epoch 语义），
  /// 与设备和地点时区无关。
  static List<WeatherAlert> activeAlerts(List<WeatherAlert>? alerts) {
    if (alerts == null || alerts.isEmpty) return const [];
    final now = DateTime.now();
    final active =
        alerts.where((alert) {
          if (alert.status != null && alert.status != 'active') return false;
          final end = alert.endTime;
          return end == null || end.isAfter(now);
        }).toList();
    active.sort(
      (a, b) => severityRank(b).compareTo(severityRank(a)),
    );
    return active;
  }

  static WeatherAlert? highestSeverity(List<WeatherAlert> alerts) =>
      alerts.isEmpty ? null : alerts.first;

  static int severityRank(WeatherAlert alert) => switch (alert.severity) {
    'Extreme' => 6,
    'Severe' => 5,
    'Moderate' => 4,
    'Minor' => 3,
    'Unknown' => 1,
    _ => 0,
  };

  /// 预警级别色：优先和风 severityColor，退回 CAP severity 映射。
  static Color colorOf(WeatherAlert alert) {
    final named = alert.severityColor?.toLowerCase() ?? '';
    if (named.contains('red')) return const Color(0xFFE53935);
    if (named.contains('orange')) return const Color(0xFFFB8C00);
    if (named.contains('yellow')) return const Color(0xFFFDD835);
    if (named.contains('blue')) return const Color(0xFF1E88E5);
    if (named.contains('white')) return const Color(0xFF90A4AE);
    return switch (alert.severity) {
      'Extreme' => const Color(0xFFE53935),
      'Severe' => const Color(0xFFFB8C00),
      'Moderate' => const Color(0xFFFDD835),
      'Minor' => const Color(0xFF1E88E5),
      _ => const Color(0xFF90A4AE),
    };
  }
}

/// 预警详情底部弹窗：逐条展示标题、级别、发布机构、时段与全文。
///
/// [utcOffsetSeconds] 为地点时区偏移（来自天气数据），用于把 UTC 预警
/// 时间转成地点本地墙钟显示；缺省时回退设备时区。
Future<void> showWeatherAlertDetails(
  BuildContext context, {
  required List<WeatherAlert> alerts,
  int? utcOffsetSeconds,
}) {
  final active = WeatherAlertStyle.activeAlerts(alerts);
  if (active.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _WeatherAlertDetailsSheet(
      alerts: active,
      utcOffsetSeconds: utcOffsetSeconds,
    ),
  );
}

class _WeatherAlertDetailsSheet extends StatelessWidget {
  const _WeatherAlertDetailsSheet({
    required this.alerts,
    this.utcOffsetSeconds,
  });

  final List<WeatherAlert> alerts;
  final int? utcOffsetSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'weatherAlerts'.tr,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _WeatherAlertTile(
                    alert: alerts[index],
                    utcOffsetSeconds: utcOffsetSeconds,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherAlertTile extends StatelessWidget {
  const _WeatherAlertTile({required this.alert, this.utcOffsetSeconds});

  final WeatherAlert alert;
  final int? utcOffsetSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = WeatherAlertStyle.colorOf(alert);
    final title = alert.title?.trim();
    final typeName = alert.typeName?.trim();
    final sender = alert.sender?.trim();
    final text = alert.text?.trim();

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (typeName != null && typeName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          typeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (sender != null && sender.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(sender, style: theme.textTheme.bodySmall),
            ],
            if (alert.startTime != null || alert.endTime != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatPeriod(alert, utcOffsetSeconds),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (text != null && text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  /// 简化时间格式 `MM-dd HH:mm`，避免引入 locale 依赖。
  ///
  /// alert 时间存 UTC；有地点 offset 时转成地点本地墙钟（UTC 对象 + offset
  /// 后其 getter 即为地点时间），否则回退设备时区。
  static String _formatPeriod(WeatherAlert alert, int? utcOffsetSeconds) {
    DateTime toDisplay(DateTime utc) {
      final offset = utcOffsetSeconds;
      if (offset == null) return utc.toLocal();
      return utc.add(Duration(seconds: offset));
    }

    final start = alert.startTime == null ? null : toDisplay(alert.startTime!);
    final end = alert.endTime == null ? null : toDisplay(alert.endTime!);
    String format(DateTime? time) => time == null
        ? '?'
        : '${time.month.toString().padLeft(2, '0')}-'
              '${time.day.toString().padLeft(2, '0')} '
              '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';
    if (start == null && end == null) return '';
    if (start == null) return '~ ${format(end)}';
    if (end == null) return format(start);
    return '${format(start)} ~ ${format(end)}';
  }
}