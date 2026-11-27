import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';

class ClubNoticesScreen extends StatelessWidget {
  const ClubNoticesScreen({super.key});
  @override
  Widget build(BuildContext context) => _ClubScaffold(
    title: '공지',
    trailing: const [Icons.search, Icons.add],
    child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
      _NoticeCard(name: '서연', date: '26.11.05', message: '서울 저녁 러너스 클럽원 회식을 진행하려고 합니다!\n참석 여부 투표 부탁드려요. 장소는 한체대 정문 앞의 퀸비어에서 진행할 예정입니다~', poll: true),
      const SizedBox(height: AppSpacing.lg), Text('지난 공지', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: AppSpacing.sm),
      const _NoticeCard(name: '지현', date: '26.11.03', message: '2일 단체 러닝에서 에어팟 분실하신 분 계신가요? 클럽 장님께 맡겨두었습니다. 주인분은 빨리 찾아가세요 🙋'),
      const SizedBox(height: AppSpacing.sm), const _NoticeCard(name: '서연', date: '26.11.03', message: '--'),
    ]),
  );
}

class ClubMembersScreen extends StatelessWidget {
  const ClubMembersScreen({super.key});
  @override
  Widget build(BuildContext context) => _ClubScaffold(
    title: '멤버', trailing: const [Icons.search, Icons.add],
    child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
      ...['서연', '민수', '지현', '이서연', '박민수', '김지현', '최성례', '김민준', '오승윤'].asMap().entries.map((entry) => _MemberRow(name: entry.value, host: entry.key == 0, muted: entry.key > 5)),
    ]),
  );
}

class ClubRunningScreen extends StatelessWidget {
  const ClubRunningScreen({super.key});
  @override
  Widget build(BuildContext context) => _ClubScaffold(
    title: '클럽 러닝', trailing: const [Icons.search, Icons.add],
    child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
      const ClubRunCard(title: '서울숲 저녁 러닝', status: '모집중'), const SizedBox(height: AppSpacing.sm),
      const ClubRunCard(title: '뚝섬 한바퀴', status: '모집중'), const SizedBox(height: AppSpacing.lg),
      Text('지난 클럽 러닝', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: AppSpacing.sm),
      const ClubRunCard(title: '서울숲 저녁 러닝', status: '종료', finished: true),
    ]),
  );
}

class ClubChatScreen extends StatefulWidget { const ClubChatScreen({super.key}); @override State<ClubChatScreen> createState() => _ClubChatScreenState(); }
class _ClubChatScreenState extends State<ClubChatScreen> {
  final _controller = TextEditingController(); final _sent = <String>[];
  @override void dispose() { _controller.dispose(); super.dispose(); }
  void _send() { final text = _controller.text.trim(); if (text.isEmpty) return; setState(() { _sent.add(text); _controller.clear(); }); }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Column(children: [
    const Padding(padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0), child: _ClubHeader(title: '채팅')),
    const Divider(), Expanded(child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
      const _ChatDateDivider(date: '26.11.05'),
      const _OtherMessage(name: '서연', text: '서울 러너스 클럽 채팅방 입니다.', time: '14:30'),
      const _OtherMessage(name: '서연', text: '클럽원간의 매너를 지켜주세요. 부적절한 발언 시, 클럽 퇴장 조치하겠습니다. 다들 즐거운 러닝 라이프를 공유 해요~', time: '14:30'),
      const _OtherMessage(name: '민준', text: '안녕하세요, 박민준입니다.', time: '14:35'), const _MyMessage(text: '안녕하세요!!', time: '14:37'),
      const _ChatDateDivider(date: '26.11.05'), const _OtherMessage(name: '민준', text: '오늘 러닝뒤에 야식 먹으실 분ㅋㅋ', time: '17:23'), ..._sent.map((text) => _MyMessage(text: text, time: '방금')),
    ])), Padding(padding: const EdgeInsets.all(AppSpacing.sm), child: Row(children: [Expanded(child: TextField(controller: _controller, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: '메시지를 입력하세요', contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24))))), IconButton(onPressed: _send, icon: const Icon(Icons.send_outlined), color: AppColors.primary, tooltip: '전송')]))
  ])));
}

class _ClubScaffold extends StatelessWidget { const _ClubScaffold({required this.title, required this.child, this.trailing = const []}); final String title; final Widget child; final List<IconData> trailing; @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0), child: _ClubHeader(title: title, trailing: trailing)), Expanded(child: child)]))); }
class _ClubHeader extends StatelessWidget { const _ClubHeader({required this.title, this.trailing = const []}); final String title; final List<IconData> trailing; @override Widget build(BuildContext context) => Row(children: [IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left), tooltip: '뒤로'), Text(title, style: Theme.of(context).textTheme.headlineMedium), const Spacer(), ...trailing.map((icon) => IconButton(onPressed: () {}, icon: Icon(icon)))]); }
class _Avatar extends StatelessWidget { const _Avatar({required this.name, this.muted = false}); final String name; final bool muted; @override Widget build(BuildContext context) => CircleAvatar(radius: 21, backgroundColor: muted ? const Color(0xFFD8D8D8) : const Color(0xFFE6E9FF), child: muted ? null : Text(name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary))); }
class _ChatDateDivider extends StatelessWidget {
  const _ChatDateDivider({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            date,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.subText,
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    ),
  );
}
class _NoticeCard extends StatelessWidget { const _NoticeCard({required this.name, required this.date, required this.message, this.poll = false}); final String name, date, message; final bool poll; @override Widget build(BuildContext context) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [_Avatar(name: name), const SizedBox(width: AppSpacing.xs), Text(name, style: Theme.of(context).textTheme.titleMedium), const Spacer(), Text(date, style: Theme.of(context).textTheme.bodySmall)]), const SizedBox(height: AppSpacing.md), Text(message), if (poll) ...[const SizedBox(height: AppSpacing.md), AppButton(label: '참석', onPressed: () {}), const SizedBox(height: AppSpacing.xs), AppButton(label: '불참', onPressed: () {})]])); }
class _MemberRow extends StatelessWidget { const _MemberRow({required this.name, required this.host, required this.muted}); final String name; final bool host, muted; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Row(children: [_Avatar(name: name, muted: muted), const SizedBox(width: AppSpacing.md), Text(name, style: Theme.of(context).textTheme.titleMedium), if (host) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.flag_outlined, size: 16, color: AppColors.primary))])); }
class ClubRunCard extends StatelessWidget {
  const ClubRunCard({
    super.key,
    required this.title,
    required this.status,
    this.finished = false,
  });

  final String title;
  final String status;
  final bool finished;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 112,
          decoration: BoxDecoration(
            color: finished ? const Color(0xFF9FA3AA) : const Color(0xFFAAC19A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.park_outlined, color: Colors.white, size: 48),
              ),
              Positioned(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: Chip(
                  label: Text(status),
                  labelStyle: const TextStyle(color: Colors.white),
                  backgroundColor: finished ? Colors.grey : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2026. 10. 01. (목) 19:00',
                          style: TextStyle(color: AppColors.subText),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '서울숲 공원 정문 · 12 / 20명',
                          style: TextStyle(color: AppColors.subText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppButton(
                    label: '참여하기',
                    onPressed: () {},
                    variant: AppButtonVariant.outlined,
                    expand: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
class _OtherMessage extends StatelessWidget { const _OtherMessage({required this.name, required this.text, required this.time}); final String name, text, time; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_Avatar(name: name), const SizedBox(width: AppSpacing.xs), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Container(padding: const EdgeInsets.all(AppSpacing.sm), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: Text(text, style: const TextStyle(color: Colors.white)))])), Text(time, style: Theme.of(context).textTheme.bodySmall)])); }
class _MyMessage extends StatelessWidget { const _MyMessage({required this.text, required this.time}); final String text, time; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(time, style: Theme.of(context).textTheme.bodySmall), const SizedBox(width: 4), Container(padding: const EdgeInsets.all(AppSpacing.sm), decoration: BoxDecoration(color: const Color(0xFFE9ECF2), borderRadius: BorderRadius.circular(12)), child: Text(text))])); }
