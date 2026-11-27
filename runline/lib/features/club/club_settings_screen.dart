import 'package:flutter/material.dart';

import '../../shared/media/club_image_compose_screen.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import '../feed/widgets/feed_avatar.dart';
import 'club_members_screen.dart';
import 'club_ui.dart';

class ClubSettingsScreen extends StatefulWidget {
  const ClubSettingsScreen({super.key, required this.clubId, this.api});
  final String clubId;
  final RunlineApi? api;
  @override
  State<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends State<ClubSettingsScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _region = TextEditingController(),
      _description = TextEditingController();
  ClubMap? _home;
  Object? _error;
  bool _busy = false;
  int _generation = 0;
  bool get _owner => _home?['membership']?['role'] == 'owner';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _name.dispose();
    _region.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetFields = true}) async {
    final generation = ++_generation;
    setState(() => _error = null);
    try {
      final result = await _api.json('/clubs/${widget.clubId}/home');
      if (!mounted || generation != _generation) return;
      if (resetFields) {
        _name.text = result['club']['name'] as String;
        _region.text = result['club']['region'] as String;
        _description.text = result['club']['description'] as String;
      }
      setState(() => _home = result);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error;
          _home = null;
        });
      }
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) clubMessage(context, clubError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _mutate(() async {
      await _api.json(
        '/clubs/${widget.clubId}',
        method: 'PATCH',
        body: {
          'name': _name.text.trim(),
          'region': _region.text.trim(),
          'description': _description.text.trim(),
        },
      );
      if (!mounted) return;
      clubMessage(context, '클럽 정보를 저장했어요.');
      await _load();
    });
  }

  Future<void> _exit() async {
    final close = _owner;
    if (!await confirmClubAction(
      context,
      close ? '클럽 폐쇄' : '클럽 탈퇴',
      close
          ? '클럽을 폐쇄하면 모든 멤버의 접근이 종료되고 진행 예정인 러닝도 취소됩니다. 폐쇄할까요?'
          : '클럽에서 탈퇴할까요? 예정된 참가·주최 러닝은 취소되고, 재가입해도 이전 채팅은 볼 수 없어요.',
    )) {
      return;
    }
    if (!mounted) return;
    await _mutate(() async {
      await _api.json(
        '/clubs/${widget.clubId}${close ? '' : '/leave'}',
        method: close ? 'DELETE' : 'POST',
      );
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _cover() async {
    await openClubPage(
      context,
      _api,
      ClubImageComposeScreen(
        kind: ClubImageComposeKind.clubCover,
        clubId: widget.clubId,
        api: _api,
      ),
    );
    if (mounted) await _load(resetFields: false);
  }

  Future<void> _removeCover() async {
    if (!await confirmClubAction(context, '대표 사진 삭제', '현재 클럽 대표 사진을 삭제할까요?')) {
      return;
    }
    if (!mounted) return;
    await _mutate(() async {
      await _api.json(
        '/clubs/${widget.clubId}',
        method: 'PATCH',
        body: {'imageUrl': null},
      );
      if (mounted) await _load(resetFields: false);
    });
  }

  Future<void> _members() async {
    await openClubPage(
      context,
      _api,
      ClubMembersScreen(
        clubId: widget.clubId,
        membership: _home!['membership'] as ClubMap,
        api: _api,
      ),
    );
    if (mounted) await _load(resetFields: false);
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('클럽 설정')),
        body: _error != null
            ? ClubLoadError(error: _error!, retry: () => _load())
            : home == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (home['club']['image_url'] != null)
                      SizedBox(
                        height: 180,
                        child: RunlineImage(
                          path: home['club']['image_url'] as String,
                          api: _api,
                          fit: BoxFit.contain,
                        ),
                      ),
                    if (_owner) ...[
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _busy ? null : _cover,
                            child: const Text('대표 사진 변경'),
                          ),
                          if (home['club']['image_url'] != null)
                            TextButton(
                              onPressed: _busy ? null : _removeCover,
                              child: const Text('대표 사진 삭제'),
                            ),
                        ],
                      ),
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 50,
                        decoration: const InputDecoration(labelText: '클럽 이름'),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : '클럽 이름을 입력해주세요.',
                      ),
                      TextFormField(
                        controller: _region,
                        enabled: !_busy,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: '활동 지역'),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : '활동 지역을 입력해주세요.',
                      ),
                      TextFormField(
                        controller: _description,
                        enabled: !_busy,
                        maxLength: 2000,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: '클럽 소개'),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: const Text('클럽 정보 저장'),
                      ),
                      const Divider(height: 32),
                      OutlinedButton(
                        onPressed: _busy ? null : _members,
                        child: const Text('멤버 관리 · 클럽장 위임'),
                      ),
                      const Text('클럽장은 다른 멤버에게 권한을 위임한 뒤 탈퇴할 수 있어요.'),
                    ] else ...[
                      Text(
                        home['club']['name'] as String,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(home['club']['region'] as String),
                      Text(home['club']['description'] as String),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _busy ? null : _exit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text(_owner ? '클럽 폐쇄' : '클럽 탈퇴'),
                    ),
                    if (_busy) const LinearProgressIndicator(),
                  ],
                ),
              ),
      ),
    );
  }
}

class ClubProfileEditorScreen extends StatefulWidget {
  const ClubProfileEditorScreen({super.key, this.api});
  final RunlineApi? api;
  @override
  State<ClubProfileEditorScreen> createState() =>
      _ClubProfileEditorScreenState();
}

class _ClubProfileEditorScreenState extends State<ClubProfileEditorScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  final _form = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  ClubMap? _profile;
  Object? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    try {
      final result = await _api.json('/me/profile');
      if (!mounted) return;
      if (reset) _nickname.text = result['profile']['nickname'] as String;
      setState(() {
        _profile = result['profile'] as ClubMap;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _save({bool removeAvatar = false}) async {
    if (_busy || (!removeAvatar && !_form.currentState!.validate())) return;
    setState(() => _busy = true);
    try {
      await _api.json(
        '/me/profile',
        method: 'PATCH',
        body: removeAvatar
            ? {'avatarUrl': null}
            : {'nickname': _nickname.text.trim()},
      );
      if (!mounted) return;
      if (removeAvatar) {
        await _load(reset: false);
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) clubMessage(context, clubError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _avatar() async {
    await openClubPage(
      context,
      _api,
      ClubImageComposeScreen(kind: ClubImageComposeKind.avatar, api: _api),
    );
    if (mounted) await _load(reset: false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('내 프로필 편집')),
      body: _error != null
          ? ClubLoadError(error: _error!, retry: _load)
          : _profile == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: FeedAvatar(
                      name: _profile!['nickname'] as String,
                      avatarUrl: _profile!['avatar_url'] as String?,
                      api: _api,
                      radius: 64,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : _avatar,
                        child: const Text('프로필 사진 변경'),
                      ),
                      if (_profile!['avatar_url'] != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _save(removeAvatar: true),
                          child: const Text('프로필 사진 삭제'),
                        ),
                    ],
                  ),
                  TextFormField(
                    controller: _nickname,
                    enabled: !_busy,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                      helperText: '클럽과 피드 등 앱 전체에서 사용하는 이름이에요.',
                      helperMaxLines: 2,
                    ),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : '닉네임을 입력해주세요.',
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _save(),
                    child: const Text('프로필 저장'),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ),
            ),
    ),
  );
}
