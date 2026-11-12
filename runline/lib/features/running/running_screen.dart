import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../shared/widgets/runline_map_view.dart';
import 'running_timer.dart';
import 'running_goal.dart';
import 'running_controller.dart';
import 'running_location.dart';
import '../route_recommendation/recommended_route.dart';
import 'history/running_history_repository.dart';
import 'history/running_record.dart';
import 'history/running_session_recorder.dart';
import 'history/running_record_detail_screen.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({
    super.key,
    this.createTimer = RunningTimer.new,
    this.goal,
    this.selectedRoute,
    this.location,
    this.history,
  });

  final RunningTimer Function() createTimer;
  final RunningLocation? location;
  final RunningHistoryRepository? history;

  /// The optional goal for this run. Direct START remains a run without a goal.
  final RunningGoal? goal;

  /// Validated API route snapshot. Navigation is outside this screen's scope.
  final RecommendedRoute? selectedRoute;

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen>
    with WidgetsBindingObserver {
  late final RunningTimer _timer;
  late final RunningController _run;
  RecommendedRoute? _route;
  RunningSessionRecorder? _recorder;
  bool _loadingHistory = true;
  bool _storageError = false;
  bool _saving = false;
  bool _retryingStorage = false;
  bool _foreground = true;
  bool _following = true;
  int _recenter = 0;

  @override
  void initState() {
    super.initState();
    _timer = widget.createTimer();
    _run = RunningController(
      location: widget.location ?? GeolocatorRunningLocation(),
      timer: _timer,
      goal: widget.goal,
      route: widget.selectedRoute,
    );
    _route = widget.selectedRoute;
    WidgetsBinding.instance.addObserver(this);
    _initializeHistory();
  }

  Future<void> _initializeHistory() async {
    RunningRecord? restored;
    try {
      final repository = widget.history ?? await RunningHistory.open();
      final unfinished = await repository.list(finished: false);
      if (!mounted || _timer.status == RunningStatus.finished) return;
      if (unfinished.isNotEmpty) {
        final recover = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('미완료 러닝'),
            content: const Text(
              '저장된 러닝을 이어서 진행할까요? 복구 후 재개를 누르면 GPS를 다시 확인합니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('새 러닝'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('이어서 진행'),
              ),
            ],
          ),
        );
        if (!mounted || _timer.status == RunningStatus.finished) return;
        if (recover == true) {
          restored = unfinished.first;
          _run.restore(restored);
          _route = restored.route;
        }
      }
      _recorder = RunningSessionRecorder(
        run: _run,
        repository: repository,
        route: _route,
        restored: restored,
      )..addListener(_historyChanged);
    } catch (_) {
      // Storage failure must not crash tracking or expose a raw database error.
      _storageError = true;
    }
    if (!mounted || _timer.status == RunningStatus.finished) return;
    setState(() => _loadingHistory = false);
    if (restored == null && _foreground) await _run.startOrResume();
  }

  void _historyChanged() {
    if (mounted) setState(() => _storageError = _recorder!.hasSaveError);
  }

  Future<void> _retryStorage() async {
    if (_retryingStorage) return;
    setState(() => _retryingStorage = true);
    try {
      if (_recorder == null) {
        final repository = widget.history ?? await RunningHistory.open();
        if (!mounted) return;
        _recorder = RunningSessionRecorder(
          run: _run,
          repository: repository,
          route: _route,
        )..addListener(_historyChanged);
      }
      _recorder!.checkpoint();
      await _recorder!.flush();
      if (mounted) setState(() => _storageError = _recorder!.hasSaveError);
    } catch (_) {
      if (mounted) setState(() => _storageError = true);
    } finally {
      if (mounted) setState(() => _retryingStorage = false);
    }
  }

  Future<void> _finish() async {
    if (_saving || _timer.status == RunningStatus.finished) return;
    setState(() => _saving = true);
    await _run.finish();
    await _recorder?.flush();
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder?.removeListener(_historyChanged);
    _recorder?.dispose();
    _run.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _run.pause();
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _run,
    builder: (context, _) {
      final nav = _run.navigation;
      final finished = _timer.status == RunningStatus.finished;
      return Scaffold(
        appBar: AppBar(
          title: Text(switch (_timer.status) {
            RunningStatus.ready => '러닝 시작 준비',
            RunningStatus.paused => '러닝 일시정지',
            RunningStatus.finished => '러닝 결과',
            RunningStatus.running => '러닝 진행 중',
          }),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Semantics(
                          label: '러닝 지도',
                          child: RunlineMapView(
                            routeCoordinates: _route?.canRun == true
                                ? _route!.coordinates
                                : const [],
                            currentPosition: _run.currentPosition,
                            trackSegments: _run.trackSegments,
                            completedRouteSegments:
                                nav?.completedSegments ?? const [],
                            directionCoordinates:
                                nav?.directionCoordinates ?? const [],
                            remainingRouteSegments: nav?.unpassedSegments,
                            routeRun: nav != null,
                            followLocation: _following,
                            recenterToken: _recenter,
                            onUserGesture: () {
                              if (_following) {
                                setState(() => _following = false);
                              }
                            },
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: FloatingActionButton.small(
                            heroTag: 'running-location',
                            key: const Key('recenter-location'),
                            tooltip: _following ? '현재 위치 추적 중' : '현재 위치로 돌아가기',
                            onPressed: _run.currentPosition == null
                                ? null
                                : () => setState(() {
                                    _following = true;
                                    _recenter++;
                                  }),
                            child: Icon(
                              _following
                                  ? Icons.gps_fixed
                                  : Icons.gps_not_fixed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nav != null
                            ? '추천 경로 러닝 · ${_route!.name} · ${_route!.distanceKm.toStringAsFixed(2)} km'
                            : '자유 러닝',
                        key: const Key('running-mode'),
                      ),
                      Text(
                        nav != null
                            ? '파랑: 미통과 코스 · 초록: 통과 · 보라: 실제 이동 · 주황 화살표: 진행 방향'
                            : '초록: 실제 이동 · 청록 마커: 현재 위치',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_loadingHistory) const Text('저장된 러닝 확인 중'),
                      if (_storageError)
                        const Text(
                          '기록을 저장하지 못했습니다. 저장 공간과 브라우저 설정을 확인해주세요.',
                          key: Key('running-storage-error'),
                          textAlign: TextAlign.center,
                        ),
                      if (_storageError)
                        TextButton(
                          onPressed: _retryingStorage ? null : _retryStorage,
                          child: const Text('저장 다시 시도'),
                        ),
                      Text(
                        switch (_run.gpsStatus) {
                          GpsStatus.connecting => 'GPS 연결 중',
                          GpsStatus.tracking => '위치 측정 중',
                          GpsStatus.weak => 'GPS 신호가 약합니다. 열린 공간에서 신호를 확인해주세요.',
                          GpsStatus.denied => '위치 권한이 필요합니다. 허용 후 다시 시작해주세요.',
                          GpsStatus.deniedForever =>
                            '위치 권한이 차단되었습니다. 앱 또는 브라우저 설정에서 허용해주세요.',
                          GpsStatus.serviceDisabled => '위치 서비스를 켜주세요.',
                          GpsStatus.unavailable =>
                            '위치를 사용할 수 없습니다. 지원 환경과 연결을 확인해주세요.',
                          GpsStatus.paused => 'GPS 측정 일시정지',
                          GpsStatus.finished => 'GPS 측정 종료',
                        },
                        key: const Key('gps-status'),
                        textAlign: TextAlign.center,
                      ),
                      if (nav != null) ...[
                        Text(
                          !nav.passageReliable &&
                                  _timer.status == RunningStatus.running
                              ? '정확한 GPS 신호를 기다리고 있습니다. 코스 통과 판정을 보류합니다.'
                              : nav.offRoute
                              ? '추천 코스를 벗어났습니다. 파란 코스로 돌아가세요.'
                              : nav.completed
                              ? '코스를 완주했습니다.'
                              : '코스 시작점에서 순서대로 진행하세요. 주황 화살표로 다음 방향을 확인하세요.',
                          key: const Key('route-guidance'),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '코스 통과 ${(nav.passedMeters / 1000).toStringAsFixed(2)} km · 미통과 ${(nav.remainingMeters / 1000).toStringAsFixed(2)} km',
                          key: const Key('course-distances'),
                        ),
                        Text(
                          nav.matchedMeters == null
                              ? '코스상 현재 위치 확인 중'
                              : '코스상 현재 위치 ${(nav.matchedMeters! / 1000).toStringAsFixed(2)} / ${(nav.totalMeters / 1000).toStringAsFixed(2)} km',
                          key: const Key('course-position'),
                        ),
                        LinearProgressIndicator(
                          value: nav.progress,
                          key: const Key('course-progress'),
                        ),
                      ],
                      if (_run.goal case final goal?) ...[
                        Text(switch (goal) {
                          DistanceGoal(:final distanceKm) =>
                            '목표 ${distanceKm.toStringAsFixed(2)} km',
                          DurationGoal(:final duration) =>
                            '목표 ${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                        }, key: const Key('running-goal-label')),
                        // Route runs use geometric passage progress, never total GPS distance.
                        LinearProgressIndicator(
                          value: nav?.progress ?? _run.goalProgress,
                          key: const Key('running-goal-progress'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _RunningMetric(
                        label: '거리',
                        value:
                            '${(_run.measurement.distanceMeters / 1000).toStringAsFixed(2)} km',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _RunningMetric(
                              label: '시간',
                              value: _timer.formattedElapsed,
                            ),
                          ),
                          Expanded(
                            child: _RunningMetric(
                              label: '평균 페이스',
                              value: _run.pace,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: finished
                    ? Row(
                        children: [
                          if (_recorder?.savedRecord?.isFinished == true)
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('open-running-record'),
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).push<void>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RunningRecordDetailScreen(
                                                recordId: _recorder!.id,
                                                repository:
                                                    _recorder!.repository,
                                              ),
                                        ),
                                      ),
                                child: const Text('기록 상세'),
                              ),
                            ),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('확인'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _run.preparing || _loadingHistory
                                  ? null
                                  : () {
                                      if (_timer.status ==
                                          RunningStatus.running) {
                                        _run.pause();
                                      } else {
                                        _run.startOrResume();
                                      }
                                    },
                              icon: Icon(
                                _timer.status == RunningStatus.running
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              label: Text(switch (_timer.status) {
                                RunningStatus.ready => '다시 시작',
                                RunningStatus.paused => '재개',
                                _ => '일시정지',
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _loadingHistory ? null : _finish,
                              icon: const Icon(Icons.stop),
                              label: const Text('종료'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RunningMetric extends StatelessWidget {
  const _RunningMetric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
