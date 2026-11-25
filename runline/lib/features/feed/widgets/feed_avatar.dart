import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../shared/media/runline_api.dart';
import '../../../shared/media/runline_image.dart';

class FeedAvatar extends StatelessWidget {
  const FeedAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.api,
    this.radius = 24,
  });
  final String name;
  final String? avatarUrl;
  final RunlineApi api;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFE6E9FF),
      child: Center(
        child: Text(
          name.trim().isEmpty ? '러' : name.trim().characters.first,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: radius * .75,
          ),
        ),
      ),
    );
    final url = Uri.tryParse(avatarUrl ?? '');
    Widget image = fallback;
    if (url != null && (avatarUrl ?? '').isNotEmpty) {
      if ((!url.hasScheme &&
              !url.hasAuthority &&
              url.path.startsWith('/api/v1/')) ||
          ((url.scheme == 'https' || url.scheme == 'http') &&
              url.hasAuthority &&
              api.baseUri.hasScheme &&
              api.baseUri.hasAuthority &&
              url.origin == api.baseUri.origin &&
              url.path.startsWith('/api/v1/'))) {
        image = RunlineImage(path: avatarUrl!, api: api);
      } else if (url.scheme == 'https' &&
          url.host.isNotEmpty &&
          url.userInfo.isEmpty) {
        // Public profile images must never receive a Runline Bearer token.
        image = Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    }
    return ClipOval(
      child: SizedBox.square(dimension: radius * 2, child: image),
    );
  }
}
