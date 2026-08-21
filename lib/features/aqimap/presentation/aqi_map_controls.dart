import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rain/core/weather/aqi_helper.dart';
import 'package:rain/features/aqimap/domain/aqi_grid.dart';
import 'package:rain/i18n/tr.dart';

/// 空气质量图层开关。
class AqiLayerButton extends StatelessWidget {
  const AqiLayerButton({
    super.key,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 3,
    borderRadius: BorderRadius.circular(8),
    child: IconButton(
      onPressed: onPressed,
      tooltip: 'airQuality'.tr,
      icon: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.air,
              color: enabled ? Theme.of(context).colorScheme.primary : null,
            ),
    ),
  );
}

/// AQI 热力图色带图例（左好右差，跟随当前 AQI 标准）。
class AqiLegend extends StatelessWidget {
  const AqiLegend({super.key, required this.standard});

  final String standard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AqiHelper.scaleColors(standard);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AqiHelper.standardLabel(standard),
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Container(
                width: 120,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3.5),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AqiHelper.severityLabel(standard, 0),
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      AqiHelper.severityLabel(
                        standard,
                        AqiHelper.scaleMax(standard) + 1,
                      ),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「AQI 站点地图」开关卡片。
class AqiStationToggleCard extends StatelessWidget {
  const AqiStationToggleCard({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
    elevation: 3,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'aqiStationMap'.tr,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    ),
  );
}

/// AQI 时间轴面板：逐小时滑块 + 播放控制（120 小时预报）。
class AqiTimelinePanel extends StatelessWidget {
  const AqiTimelinePanel({
    super.key,
    required this.grid,
    required this.error,
    required this.loading,
    required this.selectedIndex,
    required this.playing,
    required this.onPlayPause,
    required this.onFrameSelected,
    required this.onRetry,
  });

  final AqiGrid? grid;
  final Object? error;
  final bool loading;
  final int selectedIndex;
  final bool playing;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onFrameSelected;
  final VoidCallback onRetry;

  DateTime _frameTime(int epochSeconds) => DateTime.fromMillisecondsSinceEpoch(
    epochSeconds * Duration.millisecondsPerSecond,
    isUtc: true,
  ).toLocal();

  String _formatTime(int epochSeconds) =>
      DateFormat('M/d HH:mm').format(_frameTime(epochSeconds));

  @override
  Widget build(BuildContext context) {
    final times = grid?.times ?? const <int>[];
    final safeIndex = times.isEmpty
        ? 0
        : selectedIndex.clamp(0, times.length - 1);

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      elevation: 5,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  toggled: playing,
                  label: 'airQuality'.tr,
                  child: IconButton(
                    onPressed: times.length > 1 ? onPlayPause : null,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        times.isEmpty
                            ? 'aqiTrendTitle'.tr
                            : '${times.length} h · ${'aqiTrendTitle'.tr}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        times.isEmpty
                            ? loading
                                  ? 'loading'.tr
                                  : 'timeUnavailable'.tr
                            : _formatTime(times[safeIndex]),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (error != null)
                  IconButton(
                    onPressed: onRetry,
                    tooltip: 'retry'.tr,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            if (loading && times.isEmpty)
              const LinearProgressIndicator()
            else if (error != null && times.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'error_occurred'.tr,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (times.isNotEmpty) ...[
              Slider(
                value: safeIndex.toDouble(),
                min: 0,
                max: (times.length - 1).toDouble(),
                label: _formatTime(times[safeIndex]),
                semanticFormatterCallback: (_) => _formatTime(times[safeIndex]),
                onChanged: times.length > 1
                    ? (value) => onFrameSelected(value.round())
                    : null,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('M/d').format(_frameTime(times.first)),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    _formatTime(times[safeIndex]),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('M/d').format(_frameTime(times.last)),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
