import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rain/core/constants/app_constants.dart';
import 'package:rain/core/di/provider_refs.dart';
import 'package:rain/core/settings/app_settings_notifier.dart';
import 'package:rain/core/weather/aqi_helper.dart';
import 'package:rain/core/weather/beaufort_helper.dart';
import 'package:rain/core/weather/status_data.dart';
import 'package:rain/core/weather/status_weather.dart';
import 'package:rain/core/weather/time_index_helper.dart';
import 'package:rain/core/weather/weather_icon_theme.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/features/weather/presentation/widgets/hourly_chart/hourly_temperature_painter.dart';
import 'package:rain/i18n/tr.dart';

/// Hourly forecast chart card: temperature curves, condition spans with
/// precipitation probability, AQI/UV color bars, wind/gust Beaufort segments,
/// a time axis, and a tap-selectable detail bubble.
class HourlyForecastCard extends ConsumerStatefulWidget {
  const HourlyForecastCard({
    super.key,
    required this.weatherCard,
    required this.selectedHour,
    required this.onHourSelected,
  });

  final WeatherCard weatherCard;
  final int selectedHour;
  final ValueChanged<int> onHourSelected;

  @override
  ConsumerState<HourlyForecastCard> createState() => _HourlyForecastCardState();
}

class _HourlyForecastCardState extends ConsumerState<HourlyForecastCard> {
  static const double _slotWidth = 56;
  static const double _chartHeight = 120;
  static const double _conditionHeight = 56;
  static const double _barRowHeight = 18;
  static const double _windRowHeight = 26;
  static const double _axisHeight = 22;
  static const double _rowGap = 8;
  static const double _labelWidth = 64;
  static const double _bubbleWidth = 176;

  final ScrollController _controller = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _alignedToNow = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _moveSelection(int delta) {
    final times = widget.weatherCard.time;
    if (times == null || times.isEmpty) return;
    final next = (widget.selectedHour + delta).clamp(0, times.length - 1);
    if (next != widget.selectedHour) widget.onHourSelected(next);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.weatherCard;
    final times = card.time;
    final temps = card.temperature2M;
    if (times == null || times.isEmpty || temps == null || temps.isEmpty) {
      return const SizedBox.shrink();
    }

    final settings = ref.watch(settingsProvider);
    final locale = ref.watch(localeProvider);
    final statusWeather = ref.watch(statusWeatherProvider);
    final t = LocaleSettings.instance.currentTranslations;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusData = StatusData(settings: settings, locale: locale);

    final clock = LocationClock.fromWeatherCard(
      card,
      settingsClockSkewSeconds: settings.clockSkewSeconds,
    );
    final nowIndex = TimeIndexHelper.getTime(times, clock);
    final dayIndex = card.timeDaily == null || card.timeDaily!.isEmpty
        ? 0
        : TimeIndexHelper.getDay(card.timeDaily!, clock);

    final start = math.max(0, nowIndex - 2);
    final end = math.min(times.length, nowIndex + 49);
    final count = end - start;
    if (count <= 1) return const SizedBox.shrink();
    _windowStart = start;

    final selected = widget.selectedHour.clamp(start, end - 1).toInt();
    final selectedLocal = selected - start;

    double? tempAt(int abs) =>
        abs >= 0 && abs < temps.length ? temps[abs] : null;

    final temperatureByTime = <String, double?>{
      for (var i = 0; i < times.length; i++) times[i]: tempAt(i),
      for (var i = 0; i < (card.timePast?.length ?? 0); i++)
        if (i < (card.temperature2MPast?.length ?? 0))
          card.timePast![i]: card.temperature2MPast![i],
    };

    /// Looks up the same local hour on the previous calendar day.
    double? temp24hAgo(int abs) {
      if (abs < 0 || abs >= times.length) return null;
      final date = TimeIndexHelper.parseForecastDateTime(times[abs]);
      final previous = DateTime(
        date.year,
        date.month,
        date.day - 1,
        date.hour,
        date.minute,
      );
      final key = DateFormat("yyyy-MM-dd'T'HH:mm").format(previous);
      return temperatureByTime[key];
    }

    final windowTemps = [for (var i = start; i < end; i++) tempAt(i)];
    final windowPast = [for (var i = start; i < end; i++) temp24hAgo(i)];
    final conditionSpans = _conditionSpans(card, start, count);
    final windSegments = _levelSegments(
      card.windspeed10M,
      card,
      start,
      count,
      splitOnDirection: true,
    );
    final gustSegments = _levelSegments(
      card.windgusts10M,
      card,
      start,
      count,
      splitOnDirection: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_alignedToNow || !mounted || !_controller.hasClients) return;
      _alignedToNow = true;
      final viewport = _controller.position.viewportDimension;
      final target = selectedLocal * _slotWidth - viewport * 0.35;
      _controller.jumpTo(
        target.clamp(0.0, _controller.position.maxScrollExtent).toDouble(),
      );
    });

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.cardBottomMargin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, t, statusData, card, dayIndex),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _labelWidth, child: _buildLabels(context, t)),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                          _moveSelection(-1),
                      const SingleActivator(
                        LogicalKeyboardKey.arrowRight,
                      ): () =>
                          _moveSelection(1),
                    },
                    child: Focus(
                      focusNode: _focusNode,
                      child: Semantics(
                        container: true,
                        label: t.hourly_forecast,
                        value: statusData.getTimeFormat(times[selected]),
                        child: SingleChildScrollView(
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              _focusNode.requestFocus();
                              final index =
                                  start +
                                  (details.localPosition.dx / _slotWidth)
                                      .floor();
                              if (index >= start && index < end) {
                                widget.onHourSelected(index);
                              }
                            },
                            child: SizedBox(
                              width: count * _slotWidth,
                              child: Column(
                                children: [
                                  _buildChart(
                                    context,
                                    card,
                                    statusData,
                                    statusWeather,
                                    t,
                                    locale.languageCode,
                                    windowTemps,
                                    windowPast,
                                    selectedLocal,
                                    start,
                                    count,
                                    tempAt,
                                    temp24hAgo,
                                  ),
                                  const SizedBox(height: _rowGap),
                                  _buildConditions(
                                    context,
                                    statusWeather,
                                    conditionSpans,
                                  ),
                                  const SizedBox(height: _rowGap),
                                  _buildBarRow(
                                    context,
                                    count,
                                    selectedLocal,
                                    (abs) => _aqiColor(
                                      card,
                                      abs,
                                      settings.aqiStandard,
                                    ),
                                    (abs) => AqiHelper.aqiAt(
                                      card,
                                      abs,
                                      settings.aqiStandard,
                                    )?.round().toString(),
                                    t.air_quality,
                                  ),
                                  const SizedBox(height: _rowGap),
                                  _buildBarRow(
                                    context,
                                    count,
                                    selectedLocal,
                                    (abs) => BeaufortHelper.uvColor(
                                      _safeAt(card.uvIndex, abs),
                                    ),
                                    (abs) => _safeAt<double>(
                                      card.uvIndex,
                                      abs,
                                    )?.round().toString(),
                                    t.uv_index,
                                  ),
                                  const SizedBox(height: _rowGap),
                                  _buildLevelRow(
                                    context,
                                    t,
                                    windSegments,
                                    withArrow: true,
                                  ),
                                  const SizedBox(height: _rowGap),
                                  _buildLevelRow(
                                    context,
                                    t,
                                    gustSegments,
                                    withArrow: false,
                                  ),
                                  const SizedBox(height: _rowGap),
                                  _buildAxis(
                                    context,
                                    t,
                                    statusData,
                                    times,
                                    nowIndex,
                                    start,
                                    count,
                                    locale.languageCode,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLegend(context, t, colorScheme.primary),
          ],
        ),
      ),
    );
  }

  // --- header & legend -----------------------------------------------------

  Widget _buildHeader(
    BuildContext context,
    Translations t,
    StatusData statusData,
    WeatherCard card,
    int dayIndex,
  ) {
    final themeId = ref.read(settingsProvider).weatherIconTheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          t.hourly_forecast,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        _sunTime(
          context,
          themeId,
          'sunrise.png',
          card.sunrise?[dayIndex],
          statusData,
        ),
        const SizedBox(width: 12),
        _sunTime(
          context,
          themeId,
          'sunset.png',
          card.sunset?[dayIndex],
          statusData,
        ),
      ],
    );
  }

  Widget _sunTime(
    BuildContext context,
    String themeId,
    String file,
    String? time,
    StatusData statusData,
  ) {
    if (time == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Image.asset(
          WeatherIconTheme.asset(file, themeId: themeId),
          width: 18,
          height: 18,
        ),
        Text(
          statusData.getTimeFormat(time),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context, Translations t, Color lineColor) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        _legendItem(t.current_temperature, lineColor, false, style),
        _legendItem(
          t.temperature24h_ago,
          lineColor.withValues(alpha: 0.4),
          true,
          style,
        ),
      ],
    );
  }

  Widget _legendItem(
    String label,
    Color color,
    bool dashed,
    TextStyle? style,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      CustomPaint(
        size: const Size(22, 10),
        painter: LineSamplePainter(color: color, dashed: dashed),
      ),
      Text(label, style: style),
    ],
  );

  // --- left label column ----------------------------------------------------

  Widget _buildLabels(BuildContext context, Translations t) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    Widget label(String text, double height) => SizedBox(
      height: height,
      child: Center(
        child: Text(
          text,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return Column(
      children: [
        label(t.temperature, _chartHeight + _rowGap + _conditionHeight),
        const SizedBox(height: _rowGap),
        label(t.air_quality, _barRowHeight),
        const SizedBox(height: _rowGap),
        label(t.uv_index, _barRowHeight),
        const SizedBox(height: _rowGap),
        label(t.wind, _windRowHeight),
        const SizedBox(height: _rowGap),
        label(t.windgusts, _windRowHeight),
        const SizedBox(height: _rowGap),
        const SizedBox(height: _axisHeight),
      ],
    );
  }

  // --- chart & bubble -------------------------------------------------------

  Widget _buildChart(
    BuildContext context,
    WeatherCard card,
    StatusData statusData,
    StatusWeather statusWeather,
    Translations t,
    String languageCode,
    List<double?> windowTemps,
    List<double?> windowPast,
    int selectedLocal,
    int start,
    int count,
    double? Function(int) tempAt,
    double? Function(int) temp24hAgo,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _chartHeight,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(count * _slotWidth, _chartHeight),
            painter: HourlyTemperaturePainter(
              temperatures: windowTemps,
              previousDay: windowPast,
              slotWidth: _slotWidth,
              selectedIndex: selectedLocal,
              lineColor: colorScheme.primary,
              previousColor: colorScheme.primary.withValues(alpha: 0.4),
              fillColor: colorScheme.primary.withValues(alpha: 0.14),
              ringColor: colorScheme.surface,
              gridColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          _buildBubble(
            context,
            card,
            statusData,
            statusWeather,
            t,
            languageCode,
            selectedLocal + start,
            selectedLocal,
            count,
            tempAt,
            temp24hAgo,
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    WeatherCard card,
    StatusData statusData,
    StatusWeather statusWeather,
    Translations t,
    String languageCode,
    int abs,
    int selectedLocal,
    int count,
    double? Function(int) tempAt,
    double? Function(int) temp24hAgo,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final times = card.time!;
    final time = times[abs];
    final temp = tempAt(abs);
    final previous = temp24hAgo(abs);
    final date = TimeIndexHelper.parseForecastDateTime(time);
    final dateLabel = DateFormat('MMMd', languageCode).format(date);
    final condition = statusWeather.getText(_safeAt(card.weathercode, abs));

    double? delta;
    if (temp != null && previous != null) {
      delta = temp - previous;
      if (ref.read(settingsProvider).degrees == 'fahrenheit') {
        delta = delta * 9 / 5;
      }
    }
    final arrow = delta == null
        ? ''
        : delta > 0
        ? '↑'
        : delta < 0
        ? '↓'
        : '±';

    final contentWidth = count * _slotWidth;
    final bubbleLeft =
        (selectedLocal * _slotWidth + _slotWidth / 2 - _bubbleWidth / 2)
            .clamp(0.0, math.max(0.0, contentWidth - _bubbleWidth))
            .toDouble();

    return Positioned(
      left: bubbleLeft,
      top: 0,
      child: SizedBox(
        width: _bubbleWidth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dateLabel ${statusData.getTimeFormat(time)} · $condition',
                style: TextStyle(color: colorScheme.onPrimary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusData.getDegree(temp),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${t.vs_yesterday} $arrow${delta.round().abs()}°',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- condition spans ------------------------------------------------------

  Widget _buildConditions(
    BuildContext context,
    StatusWeather statusWeather,
    List<_ConditionSpan> spans,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: _conditionHeight,
      child: Stack(
        children: [
          for (final span in spans)
            Positioned(
              left: span.start * _slotWidth,
              width: span.length * _slotWidth,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (span.code != null &&
                      statusWeather.getImageNowDaily(span.code).isNotEmpty)
                    Image.asset(
                      statusWeather.getImageNowDaily(span.code),
                      width: 20,
                      height: 20,
                    ),
                  if (span.length * _slotWidth >= 40)
                    Text(
                      statusWeather.getText(span.code),
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (span.maxProbability != null && span.maxProbability! >= 20)
                    Text(
                      '${span.maxProbability}%',
                      style: textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF4A90D9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<_ConditionSpan> _conditionSpans(WeatherCard card, int start, int count) {
    final spans = <_ConditionSpan>[];
    var spanStart = 0;
    for (var i = 1; i <= count; i++) {
      final sameCode =
          i < count &&
          _safeAt(card.weathercode, start + i) ==
              _safeAt(card.weathercode, start + spanStart);
      if (!sameCode) {
        int? maxProbability;
        for (var j = spanStart; j < i; j++) {
          final p = _safeAt(card.precipitationProbability, start + j);
          if (p != null && (maxProbability == null || p > maxProbability)) {
            maxProbability = p;
          }
        }
        spans.add(
          _ConditionSpan(
            start: spanStart,
            length: i - spanStart,
            code: _safeAt(card.weathercode, start + spanStart),
            maxProbability: maxProbability,
          ),
        );
        spanStart = i;
      }
    }
    return spans;
  }

  // --- bar & level rows -----------------------------------------------------

  Color _aqiColor(WeatherCard card, int abs, String standard) {
    final value = AqiHelper.aqiAt(card, abs, standard);
    if (value == null) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
    return AqiHelper.severityColor(standard, value).withValues(alpha: 0.85);
  }

  Widget _buildBarRow(
    BuildContext context,
    int count,
    int selectedLocal,
    Color Function(int abs) colorAt,
    String? Function(int abs) valueAt,
    String semanticLabel,
  ) {
    final start = _windowStart;
    final selectedValue = valueAt(start + selectedLocal);
    final row = SizedBox(
      height: _barRowHeight,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: _slotWidth - 3,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorAt(start + i),
                borderRadius: BorderRadius.circular(4),
              ),
              child: i == selectedLocal && valueAt(start + i) != null
                  ? Text(
                      valueAt(start + i)!,
                      style: TextStyle(
                        color:
                            ThemeData.estimateBrightnessForColor(
                                  colorAt(start + i),
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      value: selectedValue,
      child: ExcludeSemantics(child: row),
    );
  }

  Widget _buildLevelRow(
    BuildContext context,
    Translations t,
    List<_LevelSegment> segments, {
    required bool withArrow,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _windRowHeight,
      child: Row(
        children: [
          for (final segment in segments)
            Container(
              width: segment.length * _slotWidth - 2,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: segment.level == null || segment.length * _slotWidth < 36
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: [
                          if (withArrow && segment.direction != null)
                            Transform.rotate(
                              angle: (segment.direction! + 180) * math.pi / 180,
                              child: Icon(
                                Icons.arrow_upward,
                                size: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            t.wind_level.replaceFirst(
                              '{n}',
                              '${segment.level}',
                            ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  List<_LevelSegment> _levelSegments(
    List<double?>? values,
    WeatherCard card,
    int start,
    int count, {
    required bool splitOnDirection,
  }) {
    final segments = <_LevelSegment>[];
    var spanStart = 0;
    for (var i = 1; i <= count; i++) {
      final sameLevel =
          i < count &&
          _levelKey(values, start + i) == _levelKey(values, start + spanStart);
      final sameDirection =
          !splitOnDirection ||
          _safeAt(card.winddirection10M, start + i) ==
              _safeAt(card.winddirection10M, start + spanStart);
      final same = sameLevel && sameDirection;
      if (!same) {
        final value = _safeAt(values, start + spanStart);
        segments.add(
          _LevelSegment(
            start: spanStart,
            length: i - spanStart,
            level: value == null ? null : BeaufortHelper.level(value),
            direction: _safeAt(card.winddirection10M, start + spanStart),
          ),
        );
        spanStart = i;
      }
    }
    return segments;
  }

  int _levelKey(List<double?>? values, int abs) {
    final value = _safeAt(values, abs);
    return value == null ? -1 : BeaufortHelper.level(value);
  }

  int _windowStart = 0;

  // --- time axis ------------------------------------------------------------

  Widget _buildAxis(
    BuildContext context,
    Translations t,
    StatusData statusData,
    List<String> times,
    int nowIndex,
    int start,
    int count,
    String languageCode,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: _axisHeight,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(
              width: _slotWidth,
              child: Center(
                child: _axisLabel(
                  context,
                  t,
                  statusData,
                  times,
                  nowIndex,
                  start + i,
                  languageCode,
                  textTheme,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _axisLabel(
    BuildContext context,
    Translations t,
    StatusData statusData,
    List<String> times,
    int nowIndex,
    int abs,
    String languageCode,
    TextTheme textTheme,
  ) {
    String? label;
    var emphasized = false;
    if (abs == nowIndex) {
      label = t.now;
      emphasized = true;
    } else {
      final date = TimeIndexHelper.parseForecastDateTime(times[abs]);
      if (date.hour == 0) {
        label = DateFormat('MMMd', languageCode).format(date);
      } else if (date.hour % 4 == 0) {
        label = statusData.getTimeFormat(times[abs]);
      }
    }
    if (label == null) return const SizedBox.shrink();
    return Text(
      label,
      style: emphasized
          ? textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)
          : textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // --- helpers --------------------------------------------------------------

  T? _safeAt<T>(List<T?>? list, int index) =>
      list == null || index < 0 || index >= list.length ? null : list[index];
}

class _ConditionSpan {
  const _ConditionSpan({
    required this.start,
    required this.length,
    required this.code,
    this.maxProbability,
  });

  final int start;
  final int length;
  final int? code;
  final int? maxProbability;
}

class _LevelSegment {
  const _LevelSegment({
    required this.start,
    required this.length,
    required this.level,
    this.direction,
  });

  final int start;
  final int length;
  final int? level;
  final int? direction;
}
