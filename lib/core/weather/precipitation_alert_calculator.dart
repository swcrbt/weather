import 'package:rain/core/weather/time_index_helper.dart';

/// Rain intensity bands derived from Open-Meteo precipitation per 15 minutes.
enum RainIntensity { light, moderate, heavy, torrential }

enum PrecipitationAlertKind { starts, stops, changes }

/// A compact event describing the next meaningful precipitation change.
class PrecipitationAlert {
  const PrecipitationAlert({
    required this.kind,
    required this.minutes,
    this.from,
    this.to,
  });

  final PrecipitationAlertKind kind;
  final int minutes;
  final RainIntensity? from;
  final RainIntensity? to;
}

/// Derives widget-friendly rain events from 15-minute forecast rows.
class PrecipitationAlertCalculator {
  PrecipitationAlertCalculator._();

  static const double _rainThresholdMm = 0.1;
  static const int _stableSlots = 2;
  static const int _slotMinutes = 15;

  /// Returns the earliest meaningful start, intensity change, or stop event.
  ///
  /// Open-Meteo amounts are totals for each 15-minute slot. They are converted
  /// to an hourly rate for the standard light/moderate/heavy rain bands.
  static PrecipitationAlert? calculate({
    required List<String> times,
    required List<double?> precipitation,
    List<double?>? rain,
    List<double?>? showers,
    required DateTime now,
  }) {
    final count = times.length < precipitation.length
        ? times.length
        : precipitation.length;
    if (count == 0) return null;

    final slots = <_RainSlot>[];
    for (var index = 0; index < count; index++) {
      try {
        final time = TimeIndexHelper.parseForecastDateTime(times[index]);
        final amount = _amountAt(
          precipitation[index],
          rain != null && index < rain.length ? rain[index] : null,
          showers != null && index < showers.length ? showers[index] : null,
        );
        if (amount == null) continue;
        slots.add(_RainSlot(time: time, intensity: _intensity(amount)));
      } on FormatException {
        // Ignore malformed parallel rows rather than shifting an event.
      }
    }
    if (slots.isEmpty) return null;

    final activeIndex = _activeIndex(slots, now);
    if (activeIndex == null) {
      final firstFuture = slots.indexWhere((slot) => !slot.time.isBefore(now));
      if (firstFuture < 0) return null;
      final startIndex = _firstWetIndex(slots, firstFuture);
      if (startIndex == null) return null;
      return PrecipitationAlert(
        kind: PrecipitationAlertKind.starts,
        minutes: _minutesUntil(slots[startIndex].time, now),
      );
    }

    final current = slots[activeIndex].intensity;
    if (current == null) {
      final startIndex = _firstWetIndex(slots, activeIndex + 1);
      if (startIndex == null) return null;
      return PrecipitationAlert(
        kind: PrecipitationAlertKind.starts,
        minutes: _minutesUntil(slots[startIndex].time, now),
      );
    }

    PrecipitationAlert? nextChange;
    PrecipitationAlert? nextStop;
    for (var index = activeIndex + 1; index < slots.length; index++) {
      final slot = slots[index];
      if (slot.intensity == null) {
        if (_hasStableDryRun(slots, index)) {
          nextStop = PrecipitationAlert(
            kind: PrecipitationAlertKind.stops,
            minutes: _minutesUntil(slot.time, now),
          );
          break;
        }
        continue;
      }
      if (nextChange == null &&
          slot.intensity != current &&
          _hasStableIntensityRun(slots, index, slot.intensity!)) {
        nextChange = PrecipitationAlert(
          kind: PrecipitationAlertKind.changes,
          minutes: _minutesUntil(slot.time, now),
          from: current,
          to: slot.intensity,
        );
      }
    }

    if (nextStop == null) {
      for (var index = activeIndex + 1; index < slots.length; index++) {
        if (slots[index].intensity == null && _hasStableDryRun(slots, index)) {
          nextStop = PrecipitationAlert(
            kind: PrecipitationAlertKind.stops,
            minutes: _minutesUntil(slots[index].time, now),
          );
          break;
        }
      }
    }

    if (nextChange == null) return nextStop;
    if (nextStop == null || nextChange.minutes <= nextStop.minutes) {
      return nextChange;
    }
    return nextStop;
  }

  static double? _amountAt(
    double? precipitation,
    double? rain,
    double? showers,
  ) {
    final values = [
      precipitation,
      rain,
      showers,
    ].whereType<double>().where((value) => value >= 0).toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  static RainIntensity? _intensity(double amountPer15Minutes) {
    if (amountPer15Minutes < _rainThresholdMm) return null;
    final hourlyRate = amountPer15Minutes * 4;
    if (hourlyRate < 2.5) return RainIntensity.light;
    if (hourlyRate < 8) return RainIntensity.moderate;
    if (hourlyRate < 16) return RainIntensity.heavy;
    return RainIntensity.torrential;
  }

  static int? _activeIndex(List<_RainSlot> slots, DateTime now) {
    var latestPast = -1;
    for (var index = 0; index < slots.length; index++) {
      if (!slots[index].time.isAfter(now)) latestPast = index;
    }
    if (latestPast < 0) return null;
    return now.difference(slots[latestPast].time).inMinutes <= _slotMinutes
        ? latestPast
        : null;
  }

  static int? _firstWetIndex(List<_RainSlot> slots, int start) {
    for (var index = start; index < slots.length; index++) {
      if (slots[index].intensity != null) return index;
    }
    return null;
  }

  static bool _hasStableIntensityRun(
    List<_RainSlot> slots,
    int start,
    RainIntensity intensity,
  ) {
    if (start + _stableSlots > slots.length) return false;
    for (var index = start; index < start + _stableSlots; index++) {
      if (slots[index].intensity != intensity) return false;
    }
    return true;
  }

  static bool _hasStableDryRun(List<_RainSlot> slots, int start) {
    if (start + _stableSlots > slots.length) return false;
    for (var index = start; index < start + _stableSlots; index++) {
      if (slots[index].intensity != null) return false;
    }
    return true;
  }

  static int _minutesUntil(DateTime time, DateTime now) {
    final seconds = time.difference(now).inSeconds;
    if (seconds <= 0) return 0;
    return (seconds / 60).ceil();
  }
}

class _RainSlot {
  const _RainSlot({required this.time, required this.intensity});

  final DateTime time;
  final RainIntensity? intensity;
}
