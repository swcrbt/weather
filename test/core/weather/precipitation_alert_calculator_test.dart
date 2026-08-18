import 'package:flutter_test/flutter_test.dart';
import 'package:rain/core/weather/precipitation_alert_calculator.dart';

void main() {
  group('PrecipitationAlertCalculator', () {
    test('finds minutes until rain starts', () {
      final alert = PrecipitationAlertCalculator.calculate(
        times: ['2026-06-05T10:00', '2026-06-05T10:15', '2026-06-05T10:30'],
        precipitation: [0.0, 0.2, 0.2],
        now: DateTime(2026, 6, 5, 10, 7),
      );

      expect(alert?.kind, PrecipitationAlertKind.starts);
      expect(alert?.minutes, 8);
    });

    test('treats the first future wet slot as rain starting later', () {
      final alert = PrecipitationAlertCalculator.calculate(
        times: ['2026-06-05T10:15', '2026-06-05T10:30'],
        precipitation: [0.2, 0.2],
        now: DateTime(2026, 6, 5, 10, 7),
      );

      expect(alert?.kind, PrecipitationAlertKind.starts);
      expect(alert?.minutes, 8);
    });

    test('does not report events from an expired timeline', () {
      final alert = PrecipitationAlertCalculator.calculate(
        times: ['2026-06-05T09:00', '2026-06-05T09:15'],
        precipitation: [0.0, 0.2],
        now: DateTime(2026, 6, 5, 10, 7),
      );

      expect(alert, isNull);
    });

    test('finds minutes until heavy rain becomes light rain', () {
      final alert = PrecipitationAlertCalculator.calculate(
        times: ['2026-06-05T10:00', '2026-06-05T10:15', '2026-06-05T10:30'],
        precipitation: [2.1, 0.2, 0.2],
        now: DateTime(2026, 6, 5, 10, 7),
      );

      expect(alert?.kind, PrecipitationAlertKind.changes);
      expect(alert?.minutes, 8);
      expect(alert?.from, RainIntensity.heavy);
      expect(alert?.to, RainIntensity.light);
    });

    test('requires two dry slots before reporting that rain stops', () {
      final alert = PrecipitationAlertCalculator.calculate(
        times: [
          '2026-06-05T10:00',
          '2026-06-05T10:15',
          '2026-06-05T10:30',
          '2026-06-05T10:45',
        ],
        precipitation: [0.2, 0.2, 0.0, 0.0],
        now: DateTime(2026, 6, 5, 10, 7),
      );

      expect(alert?.kind, PrecipitationAlertKind.stops);
      expect(alert?.minutes, 23);
    });

    test('ignores invalid values and malformed timestamps', () {
      final alert = PrecipitationAlertCalculator.calculate(
        times: [
          'bad',
          '2026-06-05T10:15',
          '2026-06-05T10:30',
          '2026-06-05T10:45',
        ],
        precipitation: [null, -1.0, 0.0, 0.2],
        now: DateTime(2026, 6, 5, 10, 7),
      );

      expect(alert?.kind, PrecipitationAlertKind.starts);
      expect(alert?.minutes, 38);
    });
  });
}
