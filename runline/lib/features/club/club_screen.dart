import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context) => const ScreenPlaceholder(
    title: '클럽',
    description: '함께 달릴 러닝 크루를 찾아보세요.',
    icon: Icons.groups,
  );
}
