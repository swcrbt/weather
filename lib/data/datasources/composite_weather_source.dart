import 'dart:async';

import 'package:rain/core/utils/debug_log.dart';
import 'package:rain/data/datasources/weather_enhancement.dart';
import 'package:rain/data/datasources/weather_source.dart';
import 'package:rain/data/models/db.dart';

/// 组合数据源：主源 + 区域增强器，向业务层提供整合后的最优数据。
///
/// - 主数据来自 [primary]；
/// - 支持该坐标的增强器与主请求并行抓取，成功后就地合并；
/// - CJK 查询词的城市搜索路由到 [secondarySearch]（如和风 GeoAPI）。
///
/// 增强层失败静默跳过（增强器的固有语义），监控入口在日志。
class CompositeWeatherSource implements WeatherSource {
  CompositeWeatherSource({
    required WeatherSource primary,
    WeatherSource? secondarySearch,
    List<RegionalWeatherEnhancer> enhancers = const [],
  }) : // 参数为公开命名，无法使用私有字段的 initializing formal。
       // ignore: prefer_initializing_formals
       _primary = primary,
       // ignore: prefer_initializing_formals
       _secondarySearch = secondarySearch,
       _enhancers = List.unmodifiable(enhancers);
  final WeatherSource _primary;
  final WeatherSource? _secondarySearch;
  final List<RegionalWeatherEnhancer> _enhancers;

  static final RegExp _cjkRegExp = RegExp(
    r'[\u3000-\u303f\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]',
  );

  @override
  Future<MainWeatherCache> fetchWeather(double lat, double lon) async {
    final pending = <(RegionalWeatherEnhancer, Future<WeatherEnhancement?>)>[
      for (final enhancer in _enhancers)
        if (enhancer.supports(lat, lon))
          (
            enhancer,
            enhancer.fetchEnhancement(lat, lon),
          ),
    ];
    final MainWeatherCache cache;
    try {
      cache = await _primary.fetchWeather(lat, lon);
    } catch (_) {
      _abandon(pending);
      rethrow;
    }
    await _applyTo(pending, cache);
    return cache;
  }

  /// 主请求失败时为已发起的增强请求订阅错误，避免 unhandled async error。
  static void _abandon(
    List<(RegionalWeatherEnhancer, Future<WeatherEnhancement?>)> pending,
  ) {
    for (final (_, future) in pending) {
      unawaited(future.then<void>((_) {}, onError: (_) {}));
    }
  }

  @override
  Future<WeatherCard> fetchWeatherCard(
    double lat,
    double lon,
    String city,
    String district,
  ) async {
    final pending = <(RegionalWeatherEnhancer, Future<WeatherEnhancement?>)>[
      for (final enhancer in _enhancers)
        if (enhancer.supports(lat, lon))
          (
            enhancer,
            enhancer.fetchEnhancement(lat, lon),
          ),
    ];
    final WeatherCard card;
    try {
      card = await _primary.fetchWeatherCard(lat, lon, city, district);
    } catch (_) {
      _abandon(pending);
      rethrow;
    }
    await _applyToCard(pending, card);
    return card;
  }

  /// 等待住处增强结果并合并进 [cache]；单个增强失败不影响主数据与其他增强。
  Future<void> _applyTo(
    List<(RegionalWeatherEnhancer, Future<WeatherEnhancement?>)> pending,
    MainWeatherCache cache,
  ) async {
    for (final (enhancer, future) in pending) {
      try {
        final data = await future;
        if (data != null) enhancer.merge(cache, data);
      } catch (e, stackTrace) {
        debugLogError('CompositeWeatherSource._applyTo', e, stackTrace);
      }
    }
  }

  Future<void> _applyToCard(
    List<(RegionalWeatherEnhancer, Future<WeatherEnhancement?>)> pending,
    WeatherCard card,
  ) async {
    for (final (enhancer, future) in pending) {
      try {
        final data = await future;
        if (data != null) enhancer.mergeCard(card, data);
      } catch (e, stackTrace) {
        debugLogError('CompositeWeatherSource._applyToCard', e, stackTrace);
      }
    }
  }

  @override
  Future<Iterable<CitySearchResult>> searchCities(
    String query,
    String? languageCode,
  ) async {
    final secondary = _secondarySearch;
    if (secondary != null && _cjkRegExp.hasMatch(query)) {
      return secondary.searchCities(query, languageCode);
    }
    return _primary.searchCities(query, languageCode);
  }
}