import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rain/core/weather/aqi_helper.dart';
import 'package:rain/features/aqimap/domain/aqi_grid.dart';

/// 把 [AqiGrid] 某一帧渲染成平滑 AQI 热力图，叠加在基础地图之上。
///
/// 网格先以双线性插值重采样到小位图（每网格单元 16×16 像素），
/// 绘制时再按视野投影矩形放大并启用高质量滤波，得到连续色带。
/// 位图按（网格 × 帧 × 标准）缓存，播放时间轴时只重算当前帧。
class AqiHeatmapLayer extends StatefulWidget {
  const AqiHeatmapLayer({
    super.key,
    required this.grid,
    required this.timeIndex,
    required this.standard,
  });

  final AqiGrid grid;
  final int timeIndex;
  final String standard;

  @override
  State<AqiHeatmapLayer> createState() => _AqiHeatmapLayerState();
}

class _AqiHeatmapLayerState extends State<AqiHeatmapLayer> {
  /// 位图相对网格的放大倍数。
  static const int _pixelsPerCell = 16;

  /// 热力图整体不透明度。
  static const double _alpha = 0.5;

  ui.Image? _image;
  Object? _renderKey;
  int _renderGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scheduleRender();
  }

  @override
  void didUpdateWidget(covariant AqiHeatmapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleRender();
  }

  @override
  void dispose() {
    _renderGeneration++;
    _image?.dispose();
    super.dispose();
  }

  Object _keyFor() =>
      (identityHashCode(widget.grid), widget.timeIndex, widget.standard);

  void _scheduleRender() {
    final key = _keyFor();
    if (key == _renderKey) return;
    _renderKey = key;
    final generation = ++_renderGeneration;
    unawaited(_render(key, generation));
  }

  Future<void> _render(Object key, int generation) async {
    final grid = widget.grid;
    final width = grid.cols * _pixelsPerCell;
    final height = grid.rows * _pixelsPerCell;
    final pixels = Uint8List(width * height * 4);
    final timeIndex = widget.timeIndex;
    final standard = widget.standard;

    for (var y = 0; y < height; y++) {
      final lat =
          grid.bounds.north -
          (grid.bounds.north - grid.bounds.south) * (y + 0.5) / height;
      for (var x = 0; x < width; x++) {
        final lon =
            grid.bounds.west +
            (grid.bounds.east - grid.bounds.west) * (x + 0.5) / width;
        final aqi = grid.sampleAqi(standard, timeIndex, LatLng(lat, lon));
        if (aqi == null) continue;
        final color = AqiHelper.heatmapColor(standard, aqi);
        final offset = (y * width + x) * 4;
        pixels[offset] = (color.r * 255).round();
        pixels[offset + 1] = (color.g * 255).round();
        pixels[offset + 2] = (color.b * 255).round();
        pixels[offset + 3] = (_alpha * 255).round();
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;

    if (!mounted || generation != _renderGeneration) {
      image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.maybeOf(context);
    final image = _image;
    if (camera == null || image == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _AqiHeatmapPainter(
          image: image,
          bounds: widget.grid.bounds,
          camera: camera,
        ),
        size: camera.size,
      ),
    );
  }
}

class _AqiHeatmapPainter extends CustomPainter {
  _AqiHeatmapPainter({
    required this.image,
    required this.bounds,
    required this.camera,
  });

  final ui.Image image;
  final LatLngBounds bounds;
  final MapCamera camera;

  @override
  void paint(Canvas canvas, Size size) {
    final nw = camera.latLngToScreenOffset(LatLng(bounds.north, bounds.west));
    final se = camera.latLngToScreenOffset(LatLng(bounds.south, bounds.east));
    final dest = Rect.fromPoints(nw, se);
    if (dest.isEmpty) return;

    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      dest,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_AqiHeatmapPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.bounds != bounds ||
      oldDelegate.camera != camera;
}
