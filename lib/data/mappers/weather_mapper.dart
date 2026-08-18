import 'package:rain/data/models/db.dart';
import 'package:rain/data/models/weather_api.dart';
import 'package:rain/core/weather/time_index_helper.dart';

/// Maps Open-Meteo API responses to local Isar cache models.
class WeatherMapper {
  /// Returns the number of leading hourly slots that precede the normalized
  /// forecast start. [pastDays] must match the request parameter used by the
  /// datasource.
  static int _pastHourCount(WeatherDataApi weatherData, int pastDays) {
    final times = weatherData.hourly.time;
    final daily = weatherData.daily.time;
    if (pastDays <= 0 ||
        times == null ||
        times.isEmpty ||
        daily == null ||
        daily.length <= pastDays) {
      return 0;
    }

    // Open-Meteo includes past days in daily.time as well. Only treat the
    // response as a past-day response when hourly and daily start together.
    final firstHour = TimeIndexHelper.parseForecastDate(times.first);
    final firstDaily = daily.first;
    if (!_sameDate(firstHour, firstDaily)) return 0;

    final normalizedDate = daily[pastDays];
    for (var i = 0; i < times.length; i++) {
      final date = TimeIndexHelper.parseForecastDate(times[i]);
      if (_sameDate(date, normalizedDate)) return i;
    }
    return 0;
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Returns the number of daily slots that precede the normalized forecast.
  static int _pastDayCount(WeatherDataApi weatherData, int pastDays) {
    final times = weatherData.hourly.time;
    final daily = weatherData.daily.time;
    if (pastDays <= 0 ||
        times == null ||
        times.isEmpty ||
        daily == null ||
        daily.length <= pastDays) {
      return 0;
    }
    final firstHour = TimeIndexHelper.parseForecastDate(times.first);
    return _sameDate(firstHour, daily.first) ? pastDays : 0;
  }

  /// Drops leading entries and returns an empty list when the source is too
  /// short, so malformed parallel API arrays cannot be reused at a wrong index.
  static List<T>? _slice<T>(List<T>? values, int start) {
    if (values == null || start <= 0) return values;
    if (start >= values.length) return <T>[];
    return values.sublist(start);
  }

  static List<T>? _prefix<T>(List<T>? values, int length) {
    if (values == null || length <= 0) return null;
    return values.take(length).toList();
  }

  /// Converts API forecast data into the main weather cache shape.
  static MainWeatherCache toMainWeatherCache(
    WeatherDataApi weatherData, {
    int clockSkewSeconds = 0,
    int pastDays = 0,
  }) {
    final past = _pastHourCount(weatherData, pastDays);
    final dailyPast = _pastDayCount(weatherData, pastDays);
    return MainWeatherCache(
      time: _slice(weatherData.hourly.time, past),
      temperature2M: _slice(weatherData.hourly.temperature2M, past),
      relativehumidity2M: _slice(weatherData.hourly.relativeHumidity2M, past),
      apparentTemperature: _slice(weatherData.hourly.apparentTemperature, past),
      precipitation: _slice(weatherData.hourly.precipitation, past),
      rain: _slice(weatherData.hourly.rain, past),
      weathercode: _slice(weatherData.hourly.weatherCode, past),
      surfacePressure: _slice(weatherData.hourly.surfacePressure, past),
      visibility: _slice(weatherData.hourly.visibility, past),
      evapotranspiration: _slice(weatherData.hourly.evapotranspiration, past),
      windspeed10M: _slice(weatherData.hourly.windSpeed10M, past),
      winddirection10M: _slice(weatherData.hourly.windDirection10M, past),
      windgusts10M: _slice(weatherData.hourly.windGusts10M, past),
      cloudcover: _slice(weatherData.hourly.cloudCover, past),
      uvIndex: _slice(weatherData.hourly.uvIndex, past),
      dewpoint2M: _slice(weatherData.hourly.dewpoint2M, past),
      precipitationProbability: _slice(
        weatherData.hourly.precipitationProbability,
        past,
      ),
      shortwaveRadiation: _slice(weatherData.hourly.shortwaveRadiation, past),
      timeMinutely15: weatherData.minutely15?.time,
      precipitationMinutely15: weatherData.minutely15?.precipitation,
      rainMinutely15: weatherData.minutely15?.rain,
      showersMinutely15: weatherData.minutely15?.showers,
      precipitationProbabilityMinutely15:
          weatherData.minutely15?.precipitationProbability,
      timePast: _prefix(weatherData.hourly.time, past),
      temperature2MPast: _prefix(weatherData.hourly.temperature2M, past),
      timeDaily: _slice(weatherData.daily.time, dailyPast),
      weathercodeDaily: _slice(weatherData.daily.weatherCode, dailyPast),
      temperature2MMax: _slice(weatherData.daily.temperature2MMax, dailyPast),
      temperature2MMin: _slice(weatherData.daily.temperature2MMin, dailyPast),
      apparentTemperatureMax: _slice(
        weatherData.daily.apparentTemperatureMax,
        dailyPast,
      ),
      apparentTemperatureMin: _slice(
        weatherData.daily.apparentTemperatureMin,
        dailyPast,
      ),
      sunrise: _slice(weatherData.daily.sunrise, dailyPast),
      sunset: _slice(weatherData.daily.sunset, dailyPast),
      precipitationSum: _slice(weatherData.daily.precipitationSum, dailyPast),
      precipitationProbabilityMax: _slice(
        weatherData.daily.precipitationProbabilityMax,
        dailyPast,
      ),
      windspeed10MMax: _slice(weatherData.daily.windSpeed10MMax, dailyPast),
      windgusts10MMax: _slice(weatherData.daily.windGusts10MMax, dailyPast),
      uvIndexMax: _slice(weatherData.daily.uvIndexMax, dailyPast),
      rainSum: _slice(weatherData.daily.rainSum, dailyPast),
      winddirection10MDominant: _slice(
        weatherData.daily.windDirection10MDominant,
        dailyPast,
      ),
      timezone: weatherData.timezone,
      utcOffsetSeconds: weatherData.utcOffsetSeconds,
      clockSkewSeconds: clockSkewSeconds,
      timestamp: DateTime.now(),
    );
  }

  /// Converts API forecast data into a city weather card with location fields.
  static WeatherCard toWeatherCard(
    WeatherDataApi weatherData,
    double lat,
    double lon,
    String city,
    String district, {
    int clockSkewSeconds = 0,
    int pastDays = 0,
  }) {
    final past = _pastHourCount(weatherData, pastDays);
    final dailyPast = _pastDayCount(weatherData, pastDays);
    return WeatherCard(
      time: _slice(weatherData.hourly.time, past),
      temperature2M: _slice(weatherData.hourly.temperature2M, past),
      relativehumidity2M: _slice(weatherData.hourly.relativeHumidity2M, past),
      apparentTemperature: _slice(weatherData.hourly.apparentTemperature, past),
      precipitation: _slice(weatherData.hourly.precipitation, past),
      rain: _slice(weatherData.hourly.rain, past),
      weathercode: _slice(weatherData.hourly.weatherCode, past),
      surfacePressure: _slice(weatherData.hourly.surfacePressure, past),
      visibility: _slice(weatherData.hourly.visibility, past),
      evapotranspiration: _slice(weatherData.hourly.evapotranspiration, past),
      windspeed10M: _slice(weatherData.hourly.windSpeed10M, past),
      winddirection10M: _slice(weatherData.hourly.windDirection10M, past),
      windgusts10M: _slice(weatherData.hourly.windGusts10M, past),
      cloudcover: _slice(weatherData.hourly.cloudCover, past),
      uvIndex: _slice(weatherData.hourly.uvIndex, past),
      dewpoint2M: _slice(weatherData.hourly.dewpoint2M, past),
      precipitationProbability: _slice(
        weatherData.hourly.precipitationProbability,
        past,
      ),
      shortwaveRadiation: _slice(weatherData.hourly.shortwaveRadiation, past),
      timePast: _prefix(weatherData.hourly.time, past),
      temperature2MPast: _prefix(weatherData.hourly.temperature2M, past),
      timeDaily: _slice(weatherData.daily.time, dailyPast),
      weathercodeDaily: _slice(weatherData.daily.weatherCode, dailyPast),
      temperature2MMax: _slice(weatherData.daily.temperature2MMax, dailyPast),
      temperature2MMin: _slice(weatherData.daily.temperature2MMin, dailyPast),
      apparentTemperatureMax: _slice(
        weatherData.daily.apparentTemperatureMax,
        dailyPast,
      ),
      apparentTemperatureMin: _slice(
        weatherData.daily.apparentTemperatureMin,
        dailyPast,
      ),
      sunrise: _slice(weatherData.daily.sunrise, dailyPast),
      sunset: _slice(weatherData.daily.sunset, dailyPast),
      precipitationSum: _slice(weatherData.daily.precipitationSum, dailyPast),
      precipitationProbabilityMax: _slice(
        weatherData.daily.precipitationProbabilityMax,
        dailyPast,
      ),
      windspeed10MMax: _slice(weatherData.daily.windSpeed10MMax, dailyPast),
      windgusts10MMax: _slice(weatherData.daily.windGusts10MMax, dailyPast),
      uvIndexMax: _slice(weatherData.daily.uvIndexMax, dailyPast),
      rainSum: _slice(weatherData.daily.rainSum, dailyPast),
      winddirection10MDominant: _slice(
        weatherData.daily.windDirection10MDominant,
        dailyPast,
      ),
      lat: lat,
      lon: lon,
      city: city,
      district: district,
      timezone: weatherData.timezone,
      utcOffsetSeconds: weatherData.utcOffsetSeconds,
      clockSkewSeconds: clockSkewSeconds,
      timestamp: DateTime.now(),
    );
  }

  /// Copies forecast fields from [updated] onto [oldCard] and refreshes timestamp.
  static void copyWeatherCardFields(WeatherCard oldCard, WeatherCard updated) {
    oldCard
      ..time = updated.time
      ..weathercode = updated.weathercode
      ..temperature2M = updated.temperature2M
      ..apparentTemperature = updated.apparentTemperature
      ..relativehumidity2M = updated.relativehumidity2M
      ..precipitation = updated.precipitation
      ..rain = updated.rain
      ..surfacePressure = updated.surfacePressure
      ..visibility = updated.visibility
      ..evapotranspiration = updated.evapotranspiration
      ..windspeed10M = updated.windspeed10M
      ..winddirection10M = updated.winddirection10M
      ..windgusts10M = updated.windgusts10M
      ..cloudcover = updated.cloudcover
      ..uvIndex = updated.uvIndex
      ..dewpoint2M = updated.dewpoint2M
      ..precipitationProbability = updated.precipitationProbability
      ..shortwaveRadiation = updated.shortwaveRadiation
      ..timePast = updated.timePast
      ..temperature2MPast = updated.temperature2MPast
      ..europeanAqi = updated.europeanAqi
      ..usAqi = updated.usAqi
      ..pm25 = updated.pm25
      ..pm10 = updated.pm10
      ..ozone = updated.ozone
      ..co = updated.co
      ..no2 = updated.no2
      ..so2 = updated.so2
      ..timeDaily = updated.timeDaily
      ..weathercodeDaily = updated.weathercodeDaily
      ..temperature2MMax = updated.temperature2MMax
      ..temperature2MMin = updated.temperature2MMin
      ..apparentTemperatureMax = updated.apparentTemperatureMax
      ..apparentTemperatureMin = updated.apparentTemperatureMin
      ..sunrise = updated.sunrise
      ..sunset = updated.sunset
      ..precipitationSum = updated.precipitationSum
      ..precipitationProbabilityMax = updated.precipitationProbabilityMax
      ..windspeed10MMax = updated.windspeed10MMax
      ..windgusts10MMax = updated.windgusts10MMax
      ..uvIndexMax = updated.uvIndexMax
      ..rainSum = updated.rainSum
      ..winddirection10MDominant = updated.winddirection10MDominant
      ..timezone = updated.timezone
      ..utcOffsetSeconds = updated.utcOffsetSeconds
      ..clockSkewSeconds = updated.clockSkewSeconds
      ..timestamp = DateTime.now();
  }
}
