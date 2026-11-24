import 'package:flutter/material.dart';

import 'facility.dart';
import 'facility_controller.dart';

class FacilityControls extends StatelessWidget {
  const FacilityControls({super.key, required this.controller});
  final FacilityController controller;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .95),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final type in FacilityType.values)
                FilterChip(
                  key: ValueKey('facility-${type.name}'),
                  label: Text(type.label),
                  avatar: Icon(
                    type == FacilityType.toilet ? Icons.wc : Icons.videocam,
                    size: 18,
                  ),
                  selected: controller.types.contains(type),
                  onSelected: (_) => controller.toggle(type),
                ),
            ],
          ),
          if (controller.loading) const LinearProgressIndicator(minHeight: 2),
          if (controller.message != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.message!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  onPressed: controller.retry,
                  tooltip: '시설 다시 조회',
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

void showFacilityDetails(BuildContext context, Facility facility) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facility.name.isEmpty ? facility.type.label : facility.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (facility.address.isNotEmpty) Text(facility.address),
              const SizedBox(height: 8),
              Text(
                facility.description.isEmpty
                    ? '상세 정보가 제공되지 않았습니다.'
                    : facility.description,
              ),
              if (facility.type == FacilityType.toilet &&
                  facility.coordinateSource != 'source')
                const Text('주소로 변환한 위치로 실제 입구와 차이가 있을 수 있습니다.'),
              if (facility.sourceDate != null)
                Text('데이터 기준일 ${facility.sourceDate}'),
              const SizedBox(height: 8),
              const Text('출처 · 행정안전부 공공데이터'),
            ],
          ),
        ),
      ),
    ),
  );
}
