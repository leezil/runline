import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/test_map_placeholder.dart';

class FeedPostDetailScreen extends StatefulWidget {
  const FeedPostDetailScreen({
    super.key,
    required this.name,
    required this.initial,
    required this.text,
    required this.likes,
    required this.comments,
    this.isPhoto = false,
  });

  final String name;
  final String initial;
  final String text;
  final int likes;
  final int comments;
  final bool isPhoto;

  @override
  State<FeedPostDetailScreen> createState() => _FeedPostDetailScreenState();
}

class _FeedPostDetailScreenState extends State<FeedPostDetailScreen> {
  final _commentController = TextEditingController();
  final _newComments = <String>[];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    setState(() {
      _newComments.add(comment);
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
          const _BackHeader(),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedProfileScreen(name: widget.name, initial: widget.initial))),
            borderRadius: BorderRadius.circular(99),
            child: Row(children: [_FeedAvatar(initial: widget.initial), const SizedBox(width: AppSpacing.sm), Text(widget.name, style: Theme.of(context).textTheme.titleLarge)]),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.text, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 260,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: widget.isPhoto
                  ? const _FeedPhotoDetailPreview()
                  : const TestMapPlaceholder(height: 260, borderRadius: 14),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [const Icon(Icons.favorite_border, size: 26), const SizedBox(width: AppSpacing.xs), Text('${widget.likes}'), const SizedBox(width: AppSpacing.lg), const Icon(Icons.chat_bubble_outline, size: 24), const SizedBox(width: AppSpacing.xs), Text('${widget.comments + _newComments.length}'), const Spacer(), const Icon(Icons.bookmark_border, size: 26)]),
          const Divider(height: AppSpacing.xl),
          _CommentRow(
            name: '민수',
            initial: '민',
            text: '굿ㅈㄷ',
            likes: 8,
            onProfileTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedProfileScreen(name: '민수', initial: '민'))),
          ),
          const SizedBox(height: AppSpacing.md),
          _CommentRow(
            name: '서연',
            initial: '서',
            text: '카페 정보좀ㅎ',
            likes: 23,
            onProfileTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedProfileScreen(name: '서연', initial: '서'))),
          ),
          ..._newComments.map((comment) => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _CommentRow(
              name: '민지 러너',
              initial: '민',
              text: comment,
              likes: 0,
              onProfileTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedProfileScreen(name: '민지 러너', initial: '민'))),
            ),
          )),
              ],
            ),
          ),
          _CommentInput(controller: _commentController, onSubmit: _submitComment),
        ],
      ),
    ),
  );
}

class FeedProfileScreen extends StatefulWidget {
  const FeedProfileScreen({super.key, required this.name, required this.initial});
  final String name;
  final String initial;

  @override
  State<FeedProfileScreen> createState() => _FeedProfileScreenState();
}

class _FeedProfileScreenState extends State<FeedProfileScreen> {
  var _selectedTab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0), child: _BackHeader()),
          const SizedBox(height: AppSpacing.md),
          _FeedAvatar(initial: widget.initial, radius: 42),
          const SizedBox(height: AppSpacing.sm),
          Text(widget.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(onPressed: () => setState(() => _selectedTab = 0), icon: Icon(Icons.grid_view_outlined, color: _selectedTab == 0 ? AppColors.primary : AppColors.text), tooltip: '게시물'),
              IconButton(onPressed: () => setState(() => _selectedTab = 1), icon: Icon(Icons.map_outlined, color: _selectedTab == 1 ? AppColors.primary : AppColors.text), tooltip: '루트'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: _selectedTab == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(left: _selectedTab == 0 ? 82 : 0, right: _selectedTab == 1 ? 82 : 0),
              child: Container(height: 2, width: 44, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: _selectedTab == 0 ? GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              children: const [
                _ProfilePhoto(color: Color(0xFF705E52), icon: Icons.directions_run),
                TestMapPlaceholder(borderRadius: 0),
                _ProfilePhoto(color: Color(0xFF566D8C), icon: Icons.directions_run),
                TestMapPlaceholder(borderRadius: 0),
                _ProfileStatsTile(),
                _ProfilePhoto(color: Color(0xFF82A3C2), icon: Icons.landscape_outlined),
              ],
            ) : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

class _BackHeader extends StatelessWidget {
  const _BackHeader();
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left), iconSize: 32, tooltip: '뒤로'));
}
class _CommentInput extends StatelessWidget {
  const _CommentInput({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요',
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onSubmit,
            icon: const Icon(Icons.send_outlined),
            color: AppColors.primary,
            tooltip: '댓글 등록',
          ),
        ],
      ),
    ),
  );
}
class _FeedPhotoDetailPreview extends StatelessWidget {
  const _FeedPhotoDetailPreview();
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FeedPhotoDetailPainter(),
    child: const ColoredBox(color: Color(0xFFD8E0EC)),
  );
}
class _FeedPhotoDetailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * .48), Paint()..color = const Color(0xFFB9CEE2));
    canvas.drawRect(Rect.fromLTWH(0, size.height * .48, size.width, size.height * .52), Paint()..color = const Color(0xFF92B66A));
    canvas.drawPath(Path()..moveTo(0, size.height)..lineTo(size.width * .45, size.height * .45)..lineTo(size.width * .78, size.height * .45)..lineTo(size.width, size.height)..close(), Paint()..color = const Color(0xFFE6DFD0));
    final building = Paint()..color = const Color(0xFF7A8790);
    for (var index = 0; index < 8; index++) {
      canvas.drawRect(Rect.fromLTWH(index * 48, size.height * .22 - (index % 3) * 12, 35, 55 + (index % 3) * 12), building);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _FeedAvatar extends StatelessWidget { const _FeedAvatar({required this.initial, this.radius = 24}); final String initial; final double radius; @override Widget build(BuildContext context) => CircleAvatar(radius: radius, backgroundColor: const Color(0xFFE6E9FF), child: Text(initial, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: radius * .75))); }
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.name, required this.initial, required this.text, required this.likes, required this.onProfileTap});
  final String name, initial, text;
  final int likes;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(onTap: onProfileTap, borderRadius: BorderRadius.circular(99), child: _FeedAvatar(initial: initial, radius: 22)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: InkWell(
          onTap: onProfileTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: Theme.of(context).textTheme.titleMedium), Text(text)]),
        ),
      ),
      Column(children: [const Icon(Icons.favorite_border, size: 21), Text('$likes', style: Theme.of(context).textTheme.bodySmall)]),
    ],
  );
}
class _ProfilePhoto extends StatelessWidget { const _ProfilePhoto({required this.color, required this.icon}); final Color color; final IconData icon; @override Widget build(BuildContext context) => ColoredBox(color: color, child: Center(child: Icon(icon, size: 46, color: Colors.white.withValues(alpha: .78)))); }
class _ProfileStatsTile extends StatelessWidget { const _ProfileStatsTile(); @override Widget build(BuildContext context) => ColoredBox(color: const Color(0xFFF5F6FA), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('42.3 km', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900)), const Text('2026년 9월')]))); }
