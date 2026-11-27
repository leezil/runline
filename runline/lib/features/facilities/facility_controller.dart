import 'dart:async';

import 'package:flutter/foundation.dart';

import 'facility.dart';
import 'facility_api.dart';

class FacilityController extends ChangeNotifier {
  FacilityController(this.api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final FacilityApi api;
  final DateTime Function() _now;
  Set<FacilityType> _types = {};
  Set<FacilityType> get types => Set.unmodifiable(_types);
  List<Facility> items = const [];
  String? message;
  bool loading = false;
  FacilityBounds? _bounds;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;
  DateTime? _retryAt;
  DateTime? _nextRequestAt;
  bool _active = true;
  bool _failed = false;
  bool _inFlight = false;
  Completer<void>? _flightDone;
  final _cache =
      <
        ({
          FacilityBounds bounds,
          String viewKey,
          String types,
          DateTime expires,
          FacilityResult result,
        })
      >[];

  void toggle(FacilityType type) {
    _failed = false;
    _types = {..._types};
    if (!_types.remove(type)) _types.add(type);
    _schedule();
  }

  void updateBounds(FacilityBounds bounds) {
    if (_bounds?.key == bounds.key) return;
    _bounds = bounds;
    _schedule();
  }

  void retry() {
    _failed = false;
    _cache.clear();
    _schedule();
  }

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    _schedule();
  }

  void _schedule() {
    final generation = ++_generation;
    _debounce?.cancel();
    items = const [];
    loading = false;
    message = null;
    if (_types.isEmpty || !_active) {
      notifyListeners();
      return;
    }
    if (_failed) {
      message = '시설 조회를 다시 시도해주세요.';
      notifyListeners();
      return;
    }
    final bounds = _bounds;
    if (bounds == null) {
      message = '지도를 불러오면 주변 시설을 조회합니다.';
    } else if (!bounds.queryable) {
      message = '지도를 확대해 주변 시설을 확인해주세요.';
    } else {
      final cached = _cached(bounds);
      if (cached != null) {
        _showResult(cached, bounds);
        notifyListeners();
        return;
      }
      loading = true;
      _debounce = Timer(
        const Duration(milliseconds: 600),
        () => _load(bounds, generation),
      );
    }
    notifyListeners();
  }

  FacilityResult? _cached(FacilityBounds bounds) {
    final typeKey = (_types.map((t) => t.name).toList()..sort()).join(',');
    final now = _now();
    _cache.removeWhere((entry) => !now.isBefore(entry.expires));
    return _cache
        .where(
          (entry) =>
              entry.types == typeKey &&
              entry.bounds.contains(bounds) &&
              (!entry.result.truncated || entry.viewKey == bounds.key),
        )
        .lastOrNull
        ?.result;
  }

  void _showResult(FacilityResult result, FacilityBounds bounds) {
    items = List.unmodifiable(
      result.items.where(
        (f) => _types.contains(f.type) && bounds.containsPoint(f.position),
      ),
    );
    message = result.truncated
        ? '시설이 많아 일부만 표시합니다. 지도를 확대해주세요.'
        : result.notice ??
              (items.isEmpty
                  ? '이 영역에 조회된 시설이 없습니다. 지역별 수집 범위가 다를 수 있습니다.'
                  : null);
  }

  Future<void> _load(FacilityBounds bounds, int generation) async {
    if (_disposed || generation != _generation) return;
    if (_inFlight) {
      await _flightDone!.future;
      if (!_disposed && generation == _generation) {
        await _load(bounds, generation);
      }
      return;
    }
    final types = {..._types};
    final typeKey = (types.map((t) => t.name).toList()..sort()).join(',');
    bool waiting = false;
    try {
      final now = _now();
      if (_retryAt != null && now.isBefore(_retryAt!)) {
        throw const FacilityApiException('요청이 많습니다. 잠시 후 다시 시도해주세요.');
      }
      final cached = _cached(bounds);
      final query = bounds.expanded;
      if (cached == null &&
          _nextRequestAt != null &&
          now.isBefore(_nextRequestAt!)) {
        _debounce = Timer(_nextRequestAt!.difference(now), () {
          if (!_disposed && generation == _generation) {
            _load(bounds, generation);
          }
        });
        waiting = true;
        return;
      }
      if (cached == null) {
        _nextRequestAt = now.add(const Duration(seconds: 5));
        _inFlight = true;
        _flightDone = Completer<void>();
      }
      final result = cached ?? await api.fetch(query, types);
      if (_disposed) return;
      if (cached == null) {
        _cache.add((
          bounds: query,
          viewKey: bounds.key,
          types: typeKey,
          expires: now.add(const Duration(minutes: 2)),
          result: result,
        ));
        if (_cache.length > 12) _cache.removeAt(0);
      }
      if (generation != _generation) return;
      _showResult(result, bounds);
    } on FacilityApiException catch (error) {
      if (_disposed) return;
      if (error.retryAfter != null) {
        _retryAt = _now().add(error.retryAfter!);
      }
      if (generation != _generation) return;
      _failed = true;
      message = error.message;
    } finally {
      _inFlight = false;
      if (_flightDone != null && !_flightDone!.isCompleted) {
        _flightDone!.complete();
      }
      if (!_disposed && generation == _generation) {
        loading = waiting;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    api.close();
    super.dispose();
  }
}
