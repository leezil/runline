import 'package:flutter/material.dart';

import 'club_image_compose_screen.dart';
import 'runline_api.dart';
import 'runline_image.dart';

class ProfileAvatarButton extends StatefulWidget {
  const ProfileAvatarButton({super.key});
  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  Future<Map<String, dynamic>>? _profile;
  @override
  void initState() {
    super.initState();
    RunlineApi.instance.session.addListener(_refresh);
    _load();
  }

  void _load() {
    _profile = RunlineApi.instance.session.isSignedIn
        ? RunlineApi.instance.json('/me/profile')
        : null;
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    RunlineApi.instance.session.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '프로필 사진 변경',
    onPressed: () async {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              const ClubImageComposeScreen(kind: ClubImageComposeKind.avatar),
        ),
      );
      if (result == true && mounted) _refresh();
    },
    icon: SizedBox(
      width: 40,
      height: 40,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          final url = snapshot.data?['profile']?['avatar_url'] as String?;
          return CircleAvatar(
            child: url == null
                ? const Icon(Icons.person_outline)
                : ClipOval(
                    child: SizedBox.expand(
                      child: RunlineImage(path: url, thumbnail: true),
                    ),
                  ),
          );
        },
      ),
    ),
  );
}
