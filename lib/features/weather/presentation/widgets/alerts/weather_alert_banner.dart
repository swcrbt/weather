import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:rain/core/weather/weather_alert_style.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/i18n/tr.dart';

/// 主界面顶部天气预警横幅：显示最高级别预警 + 展开详情。
class WeatherAlertBanner extends StatelessWidget {
  const WeatherAlertBanner({
    super.key,
    required this.alerts,
    this.utcOffsetSeconds,
    this.compact = false,
  });

  final List<WeatherAlert> alerts;

  /// 地点时区偏移，用于详情弹窗中的预警时段显示。
  final int? utcOffsetSeconds;

  /// 卡片等紧凑场景：只显示图标，不显示文案。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = WeatherAlertStyle.activeAlerts(alerts);
    if (active.isEmpty) return const SizedBox.shrink();

    final top = WeatherAlertStyle.highestSeverity(active)!;
    final color = WeatherAlertStyle.colorOf(top);
    final title = top.title?.trim().isNotEmpty == true
        ? top.title!.trim()
        : (top.typeName ?? 'weatherAlerts'.tr);

    if (compact) {
      return Semantics(
        label: 'weatherAlerts'.tr,
        child: Tooltip(
          message: title,
          child: Icon(Icons.crisis_alert, color: color, size: 22),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showWeatherAlertDetails(
            context,
            alerts: active,
            utcOffsetSeconds: utcOffsetSeconds,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.crisis_alert, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (active.length > 1) ...[
                        const SizedBox(height: 2),
                        Text(
                          'alertMore'.tr.replaceFirst(
                            '{n}',
                            '${active.length - 1}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(IconsaxPlusLinear.arrow_right_3, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}