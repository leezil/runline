import 'package:flutter/material.dart';

import 'route_api.dart';

class RouteSearchSettingsController {
  final fields = <String, TextEditingController>{
    'approach_m': TextEditingController(text: '1000'),
    'tolerance': TextEditingController(text: '0.2'),
    'candidate_limit': TextEditingController(text: '20'),
    'radius_m': TextEditingController(text: '2500'),
    'search_seconds': TextEditingController(text: '45'),
    'focus_longitude': TextEditingController(),
    'focus_latitude': TextEditingController(),
  };
  String routeType = 'auto', searchMode = 'overview', dataSource = 'osm';
  bool allowRotation = true, allowVertexAdjustment = true;

  RouteSearchOptions read() {
    double number(String key) {
      final value = double.tryParse(fields[key]!.text.trim());
      if (value == null) throw RouteApiException('$key 값을 숫자로 입력해주세요.');
      return value;
    }

    final limit = int.tryParse(fields['candidate_limit']!.text.trim());
    if (limit == null) {
      throw const RouteApiException('후보 상한은 1~30의 정수로 입력해주세요.');
    }
    return RouteSearchOptions(
      approachMeters: number('approach_m'),
      tolerance: number('tolerance'),
      candidateLimit: limit,
      radiusMeters: number('radius_m'),
      searchSeconds: number('search_seconds'),
      routeType: routeType,
      searchMode: searchMode,
      dataSource: dataSource,
      allowRotation: allowRotation,
      allowVertexAdjustment: allowVertexAdjustment,
      focusLongitude: double.tryParse(fields['focus_longitude']!.text.trim()),
      focusLatitude: double.tryParse(fields['focus_latitude']!.text.trim()),
    );
  }

  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
  }
}

class RouteSearchSettings extends StatefulWidget {
  const RouteSearchSettings({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final RouteSearchSettingsController controller;
  final bool enabled;
  @override
  State<RouteSearchSettings> createState() => _RouteSearchSettingsState();
}

class _RouteSearchSettingsState extends State<RouteSearchSettings> {
  RouteSearchSettingsController get c => widget.controller;

  Widget number(String key, String label) => TextField(
    key: ValueKey('search-$key'),
    controller: c.fields[key],
    enabled: widget.enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
  );

  Widget choice(
    String key,
    String label,
    String value,
    Map<String, String> choices,
    void Function(String) change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('search-$key'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: choices.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    onChanged: widget.enabled
        ? (value) => setState(() => change(value!))
        : null,
  );

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('세부 탐색 설정'),
    maintainState: true,
    children: [
      const Text('서버 명세의 기본값입니다. 조건을 바꿔도 경로 발견이 보장되지는 않습니다.'),
      number('approach_m', '허용 접근 거리 (0~1,500 m)'),
      number('tolerance', '거리 허용 오차 (0.05~0.5, 0.2 = ±20%)'),
      number('candidate_limit', '후보 상한 (정수 1~30)'),
      number('radius_m', '도로 조회 반경 (800~4,000 m)'),
      number('search_seconds', '탐색 시간 (3~45초, 도로 조회 시간 별도)'),
      choice('route_type', '경로 유형', c.routeType, const {
        'auto': '자동',
        'open': '열린 경로',
        'loop': '순환 경로',
      }, (v) => c.routeType = v),
      choice('search_mode', '탐색 방식', c.searchMode, const {
        'overview': '위치별 대표',
        'all': '전체',
        'local': '특정 위치 상세',
      }, (v) => c.searchMode = v),
      if (c.searchMode == 'local') ...[
        number('focus_longitude', '상세 탐색 경도 (124~132)'),
        number('focus_latitude', '상세 탐색 위도 (32~39)'),
      ],
      SwitchListTile(
        title: const Text('그림 회전 허용'),
        value: c.allowRotation,
        onChanged: widget.enabled
            ? (v) => setState(() => c.allowRotation = v)
            : null,
      ),
      SwitchListTile(
        title: const Text('꼭짓점 소폭 조정 허용'),
        value: c.allowVertexAdjustment,
        onChanged: widget.enabled
            ? (v) => setState(() => c.allowVertexAdjustment = v)
            : null,
      ),
      choice('data_source', '도로 데이터 (provider: local)', c.dataSource, const {
        'osm': '대한민국 OSM 실제 도로',
        'demo': '연결 테스트용 가상 도로',
      }, (v) => c.dataSource = v),
      if (c.dataSource == 'demo')
        const Text('demo 응답은 synthetic입니다. 실제 추천 코스나 러닝에 사용하지 않습니다.'),
    ],
  );
}
