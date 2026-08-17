/// 一帧带时间戳的降水雷达图。
class RadarFrame {
  const RadarFrame({required this.time, required this.path});

  /// 雷达帧的 UTC Unix 时间戳，单位为秒。
  final int time;

  /// RainViewer 返回的雷达瓦片相对路径。
  final String path;

  DateTime get localTime => DateTime.fromMillisecondsSinceEpoch(
    time * Duration.millisecondsPerSecond,
    isUtc: true,
  ).toLocal();
}

/// RainViewer 雷达时间轴及其瓦片主机。
class RadarTimeline {
  const RadarTimeline({required this.host, required this.frames});

  final String host;
  final List<RadarFrame> frames;

  String tileUrl(RadarFrame frame) =>
      '$host${frame.path}/256/{z}/{x}/{y}/2/1_1.png';
}
