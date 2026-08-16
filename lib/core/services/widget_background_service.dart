import 'dart:io';

import 'package:rain/core/bootstrap/background_bootstrap.dart';
import 'package:rain/core/settings/clock_skew_persistence.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:isar_community/isar.dart';
import 'package:rain/core/constants/app_constants.dart';
import 'package:rain/core/database/isar_schemas.dart';
import 'package:rain/core/services/background_refresh_log.dart';
import 'package:rain/core/services/notification_service.dart';
import 'package:rain/i18n/locale_utils.dart';
import 'package:rain/i18n/strings.g.dart';
import 'package:rain/data/datasources/weather_local_datasource.dart';
import 'package:rain/data/datasources/weather_remote_datasource.dart';
import 'package:rain/data/models/db.dart';
import 'package:rain/data/repositories/weather_repository.dart';
import 'package:workmanager/workmanager.dart';

const _widgetUpdateTaskName = 'widgetUpdate';

/// Registers the Android periodic task that refreshes home screen widgets.
Future<void> registerWidgetBackgroundTask() async {
  if (!Platform.isAndroid) return;
  await Workmanager().registerPeriodicTask(
    _widgetUpdateTaskName,
    'widgetBackgroundUpdate',
    frequency: AppConstants.workManagerMinInterval,
    initialDelay: const Duration(minutes: 1),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// Ensures the periodic widget task is scheduled after app updates or OEM clears.
Future<void> ensureWidgetBackgroundTaskScheduled() async {
  if (!Platform.isAndroid) return;
  final scheduled = await Workmanager().isScheduledByUniqueName(
    _widgetUpdateTaskName,
  );
  if (!scheduled) {
    await registerWidgetBackgroundTask();
  }
}

/// Schedules a one-off widget refresh on the next app launch.
Future<void> registerWidgetBootUpdateTask() async {
  if (!Platform.isAndroid) return;
  await Workmanager().registerOneOffTask(
    'widgetBootUpdate',
    'widgetBackgroundUpdate',
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// Returns true when the device appears to have internet access.
Future<bool> hasBackgroundInternetAccess() =>
    InternetConnection().hasInternetAccess;

/// Refreshes the main forecast when the widget cache is stale, or always when
/// [forceRefresh] is true.
///
/// Exported for unit tests; used by [runWidgetBackgroundRefresh].
Future<void> refreshMainWeatherIfStale(
  Isar isar, {
  bool forceRefresh = false,
  Future<bool> Function()? internetAccess,
}) async {
  final local = WeatherLocalDatasource(isar);
  final location = await local.getLocation();
  if (location?.lat == null || location?.lon == null) return;

  if (!forceRefresh) {
    final cacheIsEmpty = await local.isMainWeatherEmpty();
    final staleAfter = AppConstants.widgetWeatherRefreshThreshold();
    if (!cacheIsEmpty && !await local.isMainWeatherExpired(staleAfter)) {
      return;
    }
  }
  if (!await (internetAccess ?? hasBackgroundInternetAccess)()) return;

  final resolvedLocation = location!;
  final remote = WeatherRemoteDatasource();
  if (resolvedLocation.address?.trim().isEmpty ?? true) {
    try {
      final details = await remote
          .reverseGeocode(
            resolvedLocation.lat!,
            resolvedLocation.lon!,
            languageCode: LocaleSettings.currentLocale.languageCode,
          )
          .timeout(const Duration(seconds: 5));
      if (details != null) {
        resolvedLocation.address = details.address;
        if (resolvedLocation.city?.trim().isEmpty ?? true) {
          resolvedLocation.city = details.city;
        }
        if (resolvedLocation.district?.trim().isEmpty ?? true) {
          resolvedLocation.district = details.district;
        }
      }
    } catch (e, st) {
      logBackgroundError('reverseGeocodeWidgetLocation', e, st);
    }
  }

  final repo = WeatherRepository(remote, local);
  final weather = await repo.fetchWeather(
    resolvedLocation.lat!,
    resolvedLocation.lon!,
  );
  await repo.writeCache(weather, resolvedLocation);
  if (weather.clockSkewSeconds != null) {
    await persistClockSkewInIsar(isar, weather.clockSkewSeconds!);
  }
}

/// Applies the stored UI locale before formatting weather in a background isolate.
Future<void> _applyBackgroundLocale(Isar isar) async {
  try {
    final settings = await isar.settings.where().findFirst();
    final appLocale = settings?.language != null
        ? appLocaleFromLanguageCode(settings!.language)
        : AppLocale.enUs;
    await applyAppLocale(
      appLocale,
      onFormattingError: (e, st) =>
          logBackgroundError('ensureDateFormatting', e, st),
    );
  } catch (e, st) {
    logBackgroundError('applyBackgroundLocale', e, st);
  }
}

/// Fetches stale main weather when online, then pushes widget data from disk.
///
/// It also refreshes the persistent notification and tops up forecast alarms,
/// matching the foreground side effects in
/// [MainWeatherNotifier._syncForegroundSideEffects].
Future<bool> runWidgetBackgroundRefresh(
  Future<bool> Function(Isar isar) updateWidgets, {
  Future<void> Function(Isar isar)? refreshStaleWeather,
}) async {
  Isar? isar;
  var ownsIsar = false;
  var widgetUpdated = false;
  var weatherRefreshFailed = false;
  String? failureError;

  try {
    await prepareBackgroundIsolate();

    isar = Isar.getInstance();
    if (isar == null || !isar.isOpen) {
      isar = await openWeatherIsar();
      ownsIsar = true;
    }

    await _applyBackgroundLocale(isar);

    try {
      await (refreshStaleWeather ?? refreshMainWeatherIfStale)(isar);
    } catch (e, st) {
      weatherRefreshFailed = true;
      logBackgroundError('refreshMainWeatherIfStale', e, st);
      failureError ??= e.toString();
    }

    try {
      widgetUpdated = await updateWidgets(isar);
    } catch (e, st) {
      logBackgroundError('updateWidgets', e, st);
      failureError ??= e.toString();
    }

    try {
      await updatePersistentNotificationFromIsar(isar);
    } catch (e, st) {
      logBackgroundError('updatePersistentNotificationFromIsar', e, st);
      failureError ??= e.toString();
    }

    try {
      await replenishForecastNotificationsFromIsar(isar);
    } catch (e, st) {
      logBackgroundError('replenishForecastNotificationsFromIsar', e, st);
      failureError ??= e.toString();
    }

    final success = !weatherRefreshFailed && widgetUpdated;
    await recordBackgroundRefreshResult(
      success: success,
      error: failureError,
    );
    return success;
  } catch (e, st) {
    logBackgroundError('runWidgetBackgroundRefresh', e, st);
    await recordBackgroundRefreshResult(success: false, error: e.toString());
    return false;
  } finally {
    if (ownsIsar) {
      await isar?.close();
    }
  }
}
