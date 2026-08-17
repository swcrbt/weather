import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rain/features/radar/data/radar_remote_datasource.dart';
import 'package:rain/features/radar/domain/radar_timeline.dart';

final radarRemoteDatasourceProvider = Provider<RadarRemoteDatasource>(
  (ref) => RadarRemoteDatasource(),
);

final radarTimelineProvider = FutureProvider.autoDispose<RadarTimeline>((ref) {
  return ref.watch(radarRemoteDatasourceProvider).fetchTimeline();
});
