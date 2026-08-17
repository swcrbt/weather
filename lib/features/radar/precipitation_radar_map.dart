import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:rain/core/constants/app_constants.dart';
import 'package:rain/features/radar/domain/radar_timeline.dart';
import 'package:rain/i18n/tr.dart';

/// 叠加在基础地图上的单帧降水雷达瓦片。
class PrecipitationRadarLayer extends StatelessWidget {
  const PrecipitationRadarLayer({
    super.key,
    required this.timeline,
    required this.frame,
  });

  final RadarTimeline timeline;
  final RadarFrame frame;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.72,
    child: TileLayer(
      key: ValueKey(frame.time),
      urlTemplate: timeline.tileUrl(frame),
      userAgentPackageName: AppConstants.mapUserAgentPackageName,
      maxNativeZoom: 7,
      maxZoom: 18,
      panBuffer: 1,
    ),
  );
}

/// 雷达模式开关。
class RadarLayerButton extends StatelessWidget {
  const RadarLayerButton({
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
      tooltip: 'precipitation'.tr,
      icon: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              enabled ? Icons.water_drop : Icons.water_drop_outlined,
              color: enabled ? Theme.of(context).colorScheme.primary : null,
            ),
    ),
  );
}

/// 降水强度颜色图例。
class RadarLegend extends StatelessWidget {
  const RadarLegend({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'precipitation'.tr,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(width: 8),
            ...const [
              Color(0xFF45D6C7),
              Color(0xFF53BF5B),
              Color(0xFFFFD54F),
              Color(0xFFFF8A3D),
              Color(0xFFE53935),
            ].map(
              (color) => ColoredBox(
                color: color,
                child: const SizedBox(width: 18, height: 7),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 雷达时间轴、播放控制以及加载和失败状态。
class RadarTimelinePanel extends StatelessWidget {
  const RadarTimelinePanel({
    super.key,
    required this.timeline,
    required this.error,
    required this.loading,
    required this.selectedIndex,
    required this.playing,
    required this.onPlayPause,
    required this.onFrameSelected,
    required this.onRetry,
  });

  final RadarTimeline? timeline;
  final Object? error;
  final bool loading;
  final int selectedIndex;
  final bool playing;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onFrameSelected;
  final VoidCallback onRetry;

  String _formatTime(DateTime time) => DateFormat('HH:mm').format(time);

  @override
  Widget build(BuildContext context) {
    final frames = timeline?.frames ?? const <RadarFrame>[];
    final safeIndex = frames.isEmpty
        ? 0
        : selectedIndex.clamp(0, frames.length - 1);
    final selected = frames.isEmpty ? null : frames[safeIndex];

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
                  label: 'precipitation'.tr,
                  child: IconButton(
                    onPressed: frames.length > 1 ? onPlayPause : null,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'precipitation'.tr,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        selected == null
                            ? loading
                                  ? 'loading'.tr
                                  : 'timeUnavailable'.tr
                            : DateFormat(
                                'M/d HH:mm',
                              ).format(selected.localTime),
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
            if (loading && frames.isEmpty)
              const LinearProgressIndicator()
            else if (error != null && frames.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'error_occurred'.tr,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (frames.isNotEmpty) ...[
              Slider(
                value: safeIndex.toDouble(),
                min: 0,
                max: (frames.length - 1).toDouble(),
                divisions: frames.length > 1 ? frames.length - 1 : null,
                label: _formatTime(frames[safeIndex].localTime),
                semanticFormatterCallback: (_) =>
                    _formatTime(frames[safeIndex].localTime),
                onChanged: frames.length > 1
                    ? (value) => onFrameSelected(value.round())
                    : null,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(frames.first.localTime),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    _formatTime(frames[safeIndex].localTime),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _formatTime(frames.last.localTime),
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
