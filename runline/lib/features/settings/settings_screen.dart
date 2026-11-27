import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_label_action.dart';
import '../club/club_settings_screen.dart';
import '../club/club_ui.dart';
import '../feed/widgets/feed_avatar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.api});

  final RunlineApi? api;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  bool _signingOut = false;
  Map<String, dynamic>? _profile;
  String? _profileError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _api.session.addListener(_loadProfile);
    _api.profileChanges.addListener(_loadProfile);
    _loadProfile();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      final oldApi = oldWidget.api ?? RunlineApi.instance;
      oldApi.session.removeListener(_loadProfile);
      oldApi.profileChanges.removeListener(_loadProfile);
      _api.session.addListener(_loadProfile);
      _api.profileChanges.addListener(_loadProfile);
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _api.session.removeListener(_loadProfile);
    _api.profileChanges.removeListener(_loadProfile);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final generation = ++_generation;
    setState(() {
      _profile = null;
      _profileError = null;
    });
    if (!_api.session.isSignedIn) return;
    try {
      final result = await _api.json('/me');
      if (mounted && generation == _generation) {
        setState(() => _profile = result['profile'] as Map<String, dynamic>);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _profileError = error is RunlineApiException
              ? error.message
              : '프로필을 불러오지 못했어요.',
        );
      }
    }
  }

  Future<void> _editProfile() async {
    if (!_api.session.isSignedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인 후 프로필을 편집해주세요.')));
      return;
    }
    await openClubPage<bool>(context, _api, ClubProfileEditorScreen(api: _api));
    if (mounted) await _loadProfile();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await _api.session.signOut();
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
            Center(
              child: FeedAvatar(
                name: _profile?['nickname'] as String? ?? '러너',
                avatarUrl: _profile?['avatarUrl'] as String?,
                api: _api,
                radius: 44,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                _profile?['nickname'] as String? ?? '러너',
                style: textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            if (!_api.session.isSignedIn)
              const Center(child: Text('로그인 후 프로필을 편집해주세요.')),
            if (_profileError != null)
              TextButton(
                onPressed: _loadProfile,
                child: Text('$_profileError 다시 시도'),
              ),
            const SizedBox(height: AppSpacing.xxl),
            ListenableBuilder(
              listenable: _api.session,
              builder: (context, _) => _api.session.isSignedIn
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
                      onPressed: _signingOut ? null : _editProfile,
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
