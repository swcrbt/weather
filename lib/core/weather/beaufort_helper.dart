import 'package:flutter/material.dart';

/// Beaufort wind force and UV index severity helpers for the hourly chart.
class BeaufortHelper {
  BeaufortHelper._();

  /// Inclusive upper bounds (km/h) of Beaufort forces 0–11; above is force 12.
  static const _limits = [1, 5, 11, 19, 28, 38, 49, 61, 74, 88, 102, 117];

  /// Beaufort force (0–12) for a wind speed in km/h; null counts as calm.
  static int level(double? kph) {
    if (kph == null) return 0;
    for (var i = 0; i < _limits.length; i++) {
      if (kph <= _limits[i]) return i;
    }
    return 12;
  }

  /// UV index severity color following the WHO exposure scale.
  static Color uvColor(double? uv) {
    if (uv == null) return const Color(0x269E9E9E);
    if (uv < 3) return const Color(0xFF7CC47F);
    if (uv < 6) return const Color(0xFFE3D14C);
    if (uv < 8) return const Color(0xFFE8A13D);
    if (uv < 11) return const Color(0xFFE06C6C);
    return const Color(0xFFB07AB8);
  }
}
