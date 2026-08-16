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
import 'package:rain/core/weather/message.dart';
import 'package:rain/core/weather/status_data.dart';
import 'package:rain/core/weather/status_weather.dart';
import 'package:rain/core/weather/time_index_helper.dart';
import 'package:rain/core/weather/weather_icon_theme.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/features/weather/presentation/widgets/hourly_chart/hourly_temperature_painter.dart';
import 'package:rain/i18n/tr.dart';

/// Hourly forecast chart card in badge style: day pills, temperature curve
/// with per-hour labels, condition spans, and per-hour badges for AQI, UV,
/// wind, and gusts above an hourly time axis.
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
  static const int _visibleSlotCount = 51;
  static const double _slotWidth = 68;
  static const double _chartHeight = 120;
  static const double _conditionHeight = 40;
  static const double _badgeRowHeight = 22;
  static const double _axisHeight = 22;
  static const double _pillRowHeight = 26;
  static const double _rowGap = 8;

  final ScrollController _controller = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _alignedToSelection = false;

  @override
  void didUpdateWidget(covariant HourlyForecastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedHour != widget.selectedHour) {
      _alignedToSelection = false;
    }
  }

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
    final message = Message();

    final clock = LocationClock.fromWeatherCard(
      card,
      settingsClockSkewSeconds: settings.clockSkewSeconds,
    );
    final nowIndex = TimeIndexHelper.getTime(times, clock);
    final dayIndex = card.timeDaily == null || card.timeDaily!.isEmpty
        ? 0
        : TimeIndexHelper.getDay(card.timeDaily!, clock);

    final selected = widget.selectedHour.clamp(0, times.length - 1).toInt();
    final maxStart = math.max(0, times.length - _visibleSlotCount);
    final start = (selected - 2).clamp(0, maxStart).toInt();
    final end = math.min(times.length, start + _visibleSlotCount);
    final count = end - start;
    if (count <= 1) return const SizedBox.shrink();

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
    final windowLabels = [
      for (final temp in windowTemps)
        temp == null ? null : statusData.getDegree(temp),
    ];
    final conditionSpans = _conditionSpans(card, start, count);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_alignedToSelection || !mounted || !_controller.hasClients) return;
      _alignedToSelection = true;
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
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _moveSelection(-1),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
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
                            (details.localPosition.dx / _slotWidth).floor();
                        if (index >= start && index < end) {
                          widget.onHourSelected(index);
                        }
                      },
                      child: SizedBox(
                        width: count * _slotWidth,
                        child: Column(
                          children: [
                            _buildDatePills(
                              context,
                              colorScheme,
                              times,
                              start,
                              count,
                              locale.languageCode,
                            ),
                            const SizedBox(height: _rowGap),
                            _buildChart(
                              context,
                              windowTemps,
                              windowPast,
                              windowLabels,
                              selectedLocal,
                              count,
                            ),
                            const SizedBox(height: _rowGap),
                            _buildConditions(
                              context,
                              statusWeather,
                              conditionSpans,
                            ),
                            const SizedBox(height: _rowGap),
                            _buildBadgeRow(
                              context,
                              start,
                              count,
                              selected,
                              t.air_quality,
                              (abs) {
                                final value = AqiHelper.aqiAt(
                                  card,
                                  abs,
                                  settings.aqiStandard,
                                );
                                if (value == null) return null;
                                return _BadgeData(
                                  text: _joinValueLabel(
                                    value.round().toString(),
                                    AqiHelper.severityLabel(
                                      settings.aqiStandard,
                                      value,
                                    ),
                                    locale.languageCode,
                                  ),
                                  color: AqiHelper.severityColor(
                                    settings.aqiStandard,
                                    value,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: _rowGap),
                            _buildBadgeRow(
                              context,
                              start,
                              count,
                              selected,
                              t.uv_index,
                              (abs) {
                                final uv = _safeAt(card.uvIndex, abs);
                                if (uv == null) return null;
                                final rounded = uv.round();
                                return _BadgeData(
                                  text:
                                      '$rounded ${message.getUvIndex(rounded)}',
                                  color: BeaufortHelper.uvColor(uv),
                                );
                              },
                            ),
                            const SizedBox(height: _rowGap),
                            _buildBadgeRow(
                              context,
                              start,
                              count,
                              selected,
                              t.wind,
                              (abs) {
                                final speed = _safeAt(card.windspeed10M, abs);
                                if (speed == null) return null;
                                final level = t.wind_level.replaceFirst(
                                  '{n}',
                                  '${BeaufortHelper.level(speed)}',
                                );
                                final direction = message.getDirection(
                                  _safeAt(card.winddirection10M, abs),
                                );
                                return _BadgeData(
                                  text: direction.isEmpty
                                      ? level
                                      : '$direction $level',
                                );
                              },
                            ),
                            const SizedBox(height: _rowGap),
                            _buildBadgeRow(
                              context,
                              start,
                              count,
                              selected,
                              t.windgusts,
                              (abs) {
                                final gust = _safeAt(card.windgusts10M, abs);
                                if (gust == null) return null;
                                final level = t.wind_level.replaceFirst(
                                  '{n}',
                                  '${BeaufortHelper.level(gust)}',
                                );
                                return _BadgeData(
                                  text: '${t.windgusts} $level',
                                );
                              },
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
          _safeAt(card.sunrise, dayIndex),
          statusData,
        ),
        const SizedBox(width: 12),
        _sunTime(
          context,
          themeId,
          'sunset.png',
          _safeAt(card.sunset, dayIndex),
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

  // --- day pills ------------------------------------------------------------

  Widget _buildDatePills(
    BuildContext context,
    ColorScheme colorScheme,
    List<String> times,
    int start,
    int count,
    String languageCode,
  ) {
    final dateFormat = DateFormat.Md(languageCode);
    final weekdayFormat = DateFormat.E(languageCode);
    final pills = <Widget>[];
    for (var i = 0; i < count; i++) {
      final date = TimeIndexHelper.parseForecastDateTime(times[start + i]);
      if (i != 0 && date.hour != 0) continue;
      pills.add(
        Positioned(
          left: i * _slotWidth + 2,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${dateFormat.format(date)} ${weekdayFormat.format(date)}',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(height: _pillRowHeight, child: Stack(children: pills));
  }

  // --- chart ----------------------------------------------------------------

  Widget _buildChart(
    BuildContext context,
    List<double?> windowTemps,
    List<double?> windowPast,
    List<String?> windowLabels,
    int selectedLocal,
    int count,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      height: _chartHeight,
      child: CustomPaint(
        size: Size(count * _slotWidth, _chartHeight),
        painter: HourlyTemperaturePainter(
          temperatures: windowTemps,
          previousDay: windowPast,
          labels: windowLabels,
          slotWidth: _slotWidth,
          selectedIndex: selectedLocal,
          lineColor: colorScheme.primary,
          previousColor: colorScheme.primary.withValues(alpha: 0.4),
          fillColor: colorScheme.primary.withValues(alpha: 0.14),
          ringColor: theme.cardTheme.color ?? colorScheme.surface,
          labelColor: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _conditionHeight,
      child: Stack(
        children: [
          for (final span in spans)
            if (span.start > 0)
              Positioned(
                left: span.start * _slotWidth,
                top: 0,
                bottom: 0,
                width: 1,
                child: ColoredBox(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
          for (final span in spans)
            Positioned(
              left: span.start * _slotWidth,
              width: span.length * _slotWidth,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (span.length * _slotWidth >= 40)
                    Text(
                      statusWeather.getText(span.code),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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

  // --- badge rows -----------------------------------------------------------

  /// Joins a metric value with its severity label; Chinese uses no space.
  String _joinValueLabel(String value, String label, String languageCode) =>
      languageCode == 'zh' ? '$value$label' : '$value $label';

  Widget _buildBadgeRow(
    BuildContext context,
    int start,
    int count,
    int selected,
    String semanticLabel,
    _BadgeData? Function(int abs) dataAt,
  ) {
    final row = SizedBox(
      height: _badgeRowHeight,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) _badge(context, dataAt(start + i)),
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      value: dataAt(selected)?.text,
      child: ExcludeSemantics(child: row),
    );
  }

  Widget _badge(BuildContext context, _BadgeData? data) {
    final colorScheme = Theme.of(context).colorScheme;
    final colored = data?.color != null;
    final background = colored
        ? data!.color!.withValues(alpha: 0.16)
        : colorScheme.surfaceContainerHighest.withValues(
            alpha: data == null ? 0.4 : 1,
          );
    final foreground = colored
        ? Color.alphaBlend(
            colorScheme.onSurface.withValues(alpha: 0.35),
            data!.color!,
          )
        : colorScheme.onSurfaceVariant;
    return Container(
      width: _slotWidth - 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: data?.text == null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  data!.text!,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
    );
  }

  // --- time axis ------------------------------------------------------------

  Widget _buildAxis(
    BuildContext context,
    Translations t,
    StatusData statusData,
    List<String> times,
    int nowIndex,
    int start,
    int count,
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    start + i == nowIndex
                        ? t.now
                        : statusData.getTimeFormat(times[start + i]),
                    style: start + i == nowIndex
                        ? textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )
                        : textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
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

class _BadgeData {
  const _BadgeData({required this.text, this.color});

  final String? text;
  final Color? color;
}
