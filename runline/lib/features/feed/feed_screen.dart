import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) => const ScreenPlaceholder(
    title: '피드',
    description: '러너들의 새로운 활동을 확인하세요.',
    icon: Icons.article,
  );
}
