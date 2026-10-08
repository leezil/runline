import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) => const ScreenPlaceholder(
    title: '활동',
    description: '최근 러닝 기록과 통계를 확인하세요.',
    icon: Icons.directions_run,
  );
}
