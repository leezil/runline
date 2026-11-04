import 'dart:async';

import 'package:flutter/foundation.dart';

enum RunningStatus { running, paused, finished }

/// Measures active running time. The ticker only refreshes the UI; elapsed time
/// comes from a monotonic clock so delayed browser ticks do not lose time.
class RunningTimer extends ChangeNotifier {
  RunningTimer({Duration Function()? now}) : _now = now ?? _monotonicClock() {
    _startedAt = _now();
    _startTicker();
  }

  final Duration Function() _now;
  late Duration _startedAt;
  Duration _accumulated = Duration.zero;
  RunningStatus _status = RunningStatus.running;
  Timer? _ticker;
  int _lastNotifiedSecond = 0;

  static Duration Function() _monotonicClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  RunningStatus get status => _status;

  Duration get elapsed => _status == RunningStatus.running
      ? _accumulated + (_now() - _startedAt)
      : _accumulated;

  String get formattedElapsed {
    final seconds = elapsed.inSeconds;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final second = elapsed.inSeconds;
      if (second != _lastNotifiedSecond) {
        _lastNotifiedSecond = second;
        notifyListeners();
      }
    });
  }

  void pause() {
    if (_status != RunningStatus.running) return;
    _accumulated = elapsed;
    _status = RunningStatus.paused;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void resume() {
    if (_status != RunningStatus.paused) return;
    _startedAt = _now();
    _status = RunningStatus.running;
    _startTicker();
    notifyListeners();
  }

  void finish() {
    if (_status == RunningStatus.finished) return;
    _accumulated = elapsed;
    _status = RunningStatus.finished;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _accumulated = elapsed;
    _status = RunningStatus.finished;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
