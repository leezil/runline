import 'package:flutter/material.dart';

import '../../../shared/widgets/runline_map_view.dart';
import '../../../shared/widgets/running_map_data.dart';
import '../route_navigation.dart';
import 'running_history_repository.dart';
import 'running_record.dart';

/// Independent entry point for Activity's owner: only an ID and repository.
class RunningRecordDetailScreen extends StatefulWidget {
  const RunningRecordDetailScreen({
    super.key,
    required this.recordId,
    this.repository,
  });
  final String recordId;
  final RunningHistoryRepository? repository;
  @override
  State<RunningRecordDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<RunningRecordDetailScreen> {
  late Future<RunningRecord?> _record;
  bool _showRoute = true, _showTrack = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _record =
        (widget.repository == null
                ? RunningHistory.open()
                : Future.value(widget.repository!))
            .then((repository) => repository.read(widget.recordId));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('러닝 기록 상세')),
    body: FutureBuilder<RunningRecord?>(
      future: _record,
      builder: (context, state) {
        if (state.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(_load),
              child: const Text('기록을 불러오지 못했습니다. 다시 시도'),
            ),
          );
        }
        if (state.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final record = state.data;
        if (record == null) return const Center(child: Text('기록을 찾을 수 없습니다.'));
        final route = record.route?.canRun == true ? record.route : null;
        final passage = record.passage;
        final nav = route != null && passage != null
            ? RouteNavigation(
                route.coordinates,
                settings: RouteNavigationSettings(
                  cellMeters: passage.cellMeters,
                ),
                restored: passage,
              )
            : null;
        final date = record.startedAt.toLocal();
        final seconds = record.activeTime.inSeconds;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              route == null ? '자유 러닝 기록' : '그림 루트 러닝 · ${route.name}',
              key: const Key('record-mode'),
            ),
            Text(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
            ),
            Text(
              '이동 거리 ${(record.distanceMeters / 1000).toStringAsFixed(2)} km',
            ),
            Text(
              '운동 시간 ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · 평균 페이스 ${record.averagePace} /km',
            ),
            if (route != null) ...[
              Text('선택 코스 ${route.distanceKm.toStringAsFixed(2)} km'),
              Text(
                nav == null
                    ? '이전 기록: 코스 통과 정보 없음'
                    : '코스 통과 ${(nav.progress * 100).toStringAsFixed(1)}% · ${nav.completed ? '완주' : '미완주'}',
                key: const Key('record-passage'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('추천 코스'),
                    selected: _showRoute,
                    onSelected: (value) => setState(() => _showRoute = value),
                  ),
                  FilterChip(
                    label: const Text('실제 이동'),
                    selected: _showTrack,
                    onSelected: (value) => setState(() => _showTrack = value),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 340,
              child: RunlineMapView(
                routeCoordinates: _showRoute
                    ? route?.coordinates ?? const []
                    : const [],
                completedRouteSegments: _showRoute
                    ? nav?.completedSegments ?? const []
                    : const [],
                trackSegments: _showTrack
                    ? gpsSegments(record.points, record.segmentStarts)
                    : const [],
                remainingRouteSegments: _showRoute
                    ? nav?.unpassedSegments
                    : null,
                routeRun: route != null,
              ),
            ),
            Text(
              route == null
                  ? '초록: 실제 이동 경로'
                  : '파랑: 추천 코스 · 초록: 통과 증거가 있는 구간 · 보라: 실제 이동 경로',
            ),
            if (record.points.isEmpty) const Text('저장된 GPS 좌표가 없습니다.'),
          ],
        );
      },
    ),
  );
}

/// Optional independent browser; does not change or replace ActivityScreen.
class RunningHistoryListScreen extends StatefulWidget {
  const RunningHistoryListScreen({super.key, this.repository});
  final RunningHistoryRepository? repository;
  @override
  State<RunningHistoryListScreen> createState() => _HistoryListState();
}

class _HistoryListState extends State<RunningHistoryListScreen> {
  late Future<(RunningHistoryRepository, List<RunningRecord>)> _records;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _records = () async {
      final repository = widget.repository ?? await RunningHistory.open();
      return (repository, await repository.list(finished: true));
    }();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('러닝 기록')),
    body: FutureBuilder<(RunningHistoryRepository, List<RunningRecord>)>(
      future: _records,
      builder: (context, state) {
        if (state.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(_load),
              child: const Text('기록 조회 다시 시도'),
            ),
          );
        }
        if (!state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (repository, records) = state.data!;
        if (records.isEmpty) {
          return const Center(child: Text('완료한 러닝 기록이 없습니다.'));
        }
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return ListTile(
              title: Text(record.route?.name ?? '자유 러닝'),
              subtitle: Text(
                '${record.startedAt.toLocal()} · ${(record.distanceMeters / 1000).toStringAsFixed(2)} km',
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => RunningRecordDetailScreen(
                    recordId: record.id,
                    repository: repository,
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
