import 'package:flutter/material.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/core/weather/time_index_helper.dart';
import 'package:rain/features/weather/presentation/widgets/daily/daily_container.dart';
import 'package:rain/features/weather/presentation/widgets/weather_hourly_sections.dart';
import 'package:rain/features/weather/presentation/widgets/hourly.dart';
import 'package:rain/features/weather/presentation/widgets/hourly_chart/hourly_forecast_card.dart';
import 'package:rain/features/weather/presentation/widgets/hourly_strip.dart';
import 'package:rain/features/weather/presentation/widgets/now.dart';
import 'package:rain/features/weather/presentation/widgets/sunset_sunrise.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Scrollable weather detail layout shared by the main and city detail screens.
class WeatherDetailView extends StatelessWidget {
  const WeatherDetailView({
    super.key,
    required this.weatherCard,
    required this.hourIndex,
    required this.dayIndex,
    required this.aqiStandard,
    required this.itemScrollController,
    required this.onHourSelected,
    this.showDailyTap,
  });

  final WeatherCard weatherCard;
  final int hourIndex;
  final int dayIndex;
  final String aqiStandard;
  final ItemScrollController itemScrollController;
  final void Function(int hour, int day) onHourSelected;
  final VoidCallback? showDailyTap;

  @override
  Widget build(BuildContext context) {
    final sunrise = _at(weatherCard.sunrise, dayIndex);
    final sunset = _at(weatherCard.sunset, dayIndex);
    final tempMax = _at(weatherCard.temperature2MMax, dayIndex);
    final tempMin = _at(weatherCard.temperature2MMin, dayIndex);
    final weather = _at(weatherCard.weathercode, hourIndex);
    final degree = _at(weatherCard.temperature2M, hourIndex);
    final time = _at(weatherCard.time, hourIndex);
    final feels = _at(weatherCard.apparentTemperature, hourIndex) ?? degree;

    if (sunrise == null ||
        sunset == null ||
        tempMax == null ||
        tempMin == null ||
        weather == null ||
        degree == null ||
        time == null ||
        feels == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      children: [
        Now(
          time: time,
          weather: weather,
          degree: degree,
          feels: feels,
          timeDay: sunrise,
          timeNight: sunset,
          tempMax: tempMax,
          tempMin: tempMin,
          updatedAt: weatherCard.timestamp,
        ),
        HourlyStripCard(
          child: ScrollablePositionedList.separated(
            key: const PageStorageKey('hourly'),
            separatorBuilder: (_, _) => const HourlyStripSeparator(),
            scrollDirection: Axis.horizontal,
            itemScrollController: itemScrollController,
            itemCount: weatherCard.time?.length ?? 0,
            itemBuilder: (ctx, i) {
              final time = _at(weatherCard.time, i);
              final weather = _at(weatherCard.weathercode, i);
              final degree = _at(weatherCard.temperature2M, i);
              final daily = weatherCard.timeDaily;
              final date = time == null
                  ? null
                  : TimeIndexHelper.parseForecastDateTime(time);
              final day = date == null || daily == null
                  ? -1
                  : TimeIndexHelper.indexOfCalendarDay(daily, date);
              final timeDay = day < 0 ? null : _at(weatherCard.sunrise, day);
              final timeNight = day < 0 ? null : _at(weatherCard.sunset, day);
              if (time == null ||
                  weather == null ||
                  degree == null ||
                  timeDay == null ||
                  timeNight == null) {
                return const SizedBox.shrink();
              }
              return HourlyStripTile(
                key: ValueKey('hour-$i-$hourIndex'),
                selected: i == hourIndex,
                onTap: () => onHourSelected(i, day),
                child: Hourly(
                  time: time,
                  weather: weather,
                  degree: degree,
                  timeDay: timeDay,
                  timeNight: timeNight,
                ),
              );
            },
          ),
        ),
        HourlyForecastCard(
          key: ValueKey('hourly-chart-${weatherCard.timestamp}'),
          weatherCard: weatherCard,
          selectedHour: hourIndex,
          onHourSelected: (selected) {
            final time = weatherCard.time?[selected];
            final daily = weatherCard.timeDaily;
            if (time == null || daily == null || daily.isEmpty) return;
            final date = TimeIndexHelper.parseForecastDateTime(time);
            final day = TimeIndexHelper.indexOfCalendarDay(daily, date);
            if (day >= 0) onHourSelected(selected, day);
          },
        ),
        SunsetSunrise(timeSunrise: sunrise, timeSunset: sunset),
        WeatherHourlySections(
          weatherCard: weatherCard,
          hourIndex: hourIndex,
          aqiStandard: aqiStandard,
        ),
        DailyContainer(
          weatherData: weatherCard,
          dayIndex: dayIndex,
          hourIndex: hourIndex,
          onTap: showDailyTap ?? () {},
        ),
      ],
    );
  }

  T? _at<T>(List<T>? values, int index) =>
      values == null || index < 0 || index >= values.length
      ? null
      : values[index];
}
