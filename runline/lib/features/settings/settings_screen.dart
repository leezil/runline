import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../auth/runline_auth.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_label_action.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await RunlineAuth.instance.signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했습니다. 연결을 확인하고 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: '닫기',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Color(0xFFE6E9FF),
                child: Icon(
                  Icons.person_outline,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(child: Text('민지 러너', style: textTheme.headlineMedium)),
            const SizedBox(height: AppSpacing.xxs),
            Center(
              child: Text('runline@runner.com', style: textTheme.bodySmall),
            ),
            const SizedBox(height: AppSpacing.xxl),
            ListenableBuilder(
              listenable: RunlineAuth.instance,
              builder: (context, _) => RunlineAuth.instance.isSignedIn
                  ? OutlinedButton.icon(
                      onPressed: _signingOut ? null : _signOut,
                      icon: const Icon(Icons.logout),
                      label: Text(_signingOut ? '로그아웃 중...' : '로그아웃'),
                    )
                  : const SizedBox.shrink(),
            ),
            Text('설정', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: SizedBox(
                height: 196,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisExtent: 92,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.xs,
                  children: [
                    IconLabelAction(
                      label: '프로필 편집',
                      icon: Icons.edit_outlined,
                      onPressed: () {},
                    ),
                    IconLabelAction(
                      label: '도전 과제',
                      icon: Icons.emoji_events_outlined,
                      onPressed: () {},
                    ),
                    IconLabelAction(
                      label: '개인정보 관리',
                      icon: Icons.privacy_tip_outlined,
                      onPressed: () {},
                    ),
                    IconLabelAction(
                      label: '알림 설정',
                      icon: Icons.notifications_outlined,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
