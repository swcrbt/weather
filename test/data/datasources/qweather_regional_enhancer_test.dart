import 'package:flutter_test/flutter_test.dart';
import 'package:rain/data/datasources/qweather_regional_enhancer.dart';

void main() {
  group('QWeatherRegionalEnhancer.supports', () {
    test('supports mainland China bounding box', () {
      final enhancer = QWeatherRegionalEnhancer();
      expect(enhancer.supports(39.9, 116.4), isTrue); // 北京
      expect(enhancer.supports(23.1, 113.3), isTrue); // 广州
      expect(enhancer.supports(18.0, 73.0), isTrue); // 边界
    });

    test('rejects coordinates outside China', () {
      final enhancer = QWeatherRegionalEnhancer();
      expect(enhancer.supports(55.7, 37.6), isFalse); // 莫斯科
      expect(enhancer.supports(35.7, 139.7), isFalse); // 东京
      expect(enhancer.supports(-33.9, 151.2), isFalse); // 悉尼
    });
  });
}