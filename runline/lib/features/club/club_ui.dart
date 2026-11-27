import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';

typedef ClubMap = Map<String, dynamic>;

String clubError(Object error) {
  if (error is! RunlineApiException) return '요청을 처리하지 못했어요. 다시 시도해주세요.';
  return const {
        'ALREADY_IN_CLUB': '이미 가입한 클럽이 있어요. 클럽 홈을 새로고침해주세요.',
        'CLUB_MEMBERSHIP_REQUIRED': '현재 클럽원만 이용할 수 있어요.',
        'OWNER_REQUIRED': '클럽장만 이용할 수 있어요.',
        'OWNER_MUST_TRANSFER_OR_CLOSE': '클럽장을 위임한 뒤 탈퇴해주세요.',
        'ALREADY_PARTICIPATING': '이미 참가 중인 러닝이에요.',
        'RUN_NOT_RECRUITING': '모집이 마감됐거나 정원이 찬 러닝이에요.',
        'RUN_NOT_EDITABLE': '러닝이 시작되었거나 취소되어 변경할 수 없어요.',
        'RUN_NOT_CANCELLABLE': '러닝이 시작되어 취소할 수 없어요.',
        'CAPACITY_BELOW_ATTENDANCE': '정원은 현재 참가 인원보다 적게 설정할 수 없어요.',
        'CREATOR_MUST_CANCEL_RUN': '생성자는 참가 취소 대신 러닝을 취소해주세요.',
        'ATTACHMENT_LIMIT': '사진과 문서는 공지당 최대 5개까지 첨부할 수 있어요.',
      }[error.code] ??
      error.message;
}

String clubDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

String runStateLabel(dynamic state) =>
    const {
      'recruiting': '모집 중',
      'closed': '모집 마감',
      'in_progress': '진행 중',
      'ended': '종료',
      'cancelled': '취소',
    }[state] ??
    '';

Future<bool> confirmClubAction(
  BuildContext context,
  String title,
  String message,
) async {
  final api = context.findAncestorWidgetOfExactType<ClubSessionGate>()?.api;
  return await showDialog<bool>(
        context: context,
        builder: (context) {
          final dialog = AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인'),
              ),
            ],
          );
          return api == null
              ? dialog
              : ClubSessionGate(api: api, child: dialog);
        },
      ) ??
      false;
}

void clubMessage(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));

Future<T?> openClubPage<T>(
  BuildContext context,
  RunlineApi api,
  Widget child,
) => Navigator.of(context).push<T>(
  MaterialPageRoute(
    builder: (_) => ClubSessionGate(api: api, child: child),
  ),
);

/// Dispose the previous account's screens and forms on logout/account switch.
/// Token rotation for the same account preserves in-progress forms.
class ClubSessionGate extends StatefulWidget {
  const ClubSessionGate({
    super.key,
    required this.api,
    required this.child,
    this.allowAccountSwitch = false,
  });
  final RunlineApi api;
  final Widget child;
  final bool allowAccountSwitch;
  @override
  State<ClubSessionGate> createState() => _ClubSessionGateState();
}

class _ClubSessionGateState extends State<ClubSessionGate> {
  late String? _account;
  @override
  void initState() {
    super.initState();
    _account = widget.api.session.userId;
  }

  @override
  void didUpdateWidget(ClubSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) _account = widget.api.session.userId;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.api.session,
    builder: (context, _) {
      final signedIn = widget.api.session.isSignedIn;
      final changed =
          !widget.allowAccountSwitch && _account != widget.api.session.userId;
      if (!signedIn || changed) {
        return Scaffold(
          appBar: AppBar(title: const Text('클럽')),
          body: Center(
            child: Text(
              signedIn ? '계정이 변경되었어요. 클럽 홈으로 돌아가주세요.' : '로그인 후 클럽을 이용해주세요.',
            ),
          ),
        );
      }
      return KeyedSubtree(
        key: ValueKey(widget.api.session.userId),
        child: widget.child,
      );
    },
  );
}

class ClubPageController extends ChangeNotifier {
  ClubPageController(this.api, this.path);
  final RunlineApi api;
  String path;
  final items = <ClubMap>[];
  String? cursor;
  String? error;
  bool loading = false;
  bool failedMore = false;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load({bool more = false}) async {
    if (more && (loading || cursor == null)) return;
    final generation = more ? _generation : ++_generation;
    if (!more) {
      items.clear();
      cursor = null;
    }
    loading = true;
    error = null;
    failedMore = more;
    notifyListeners();
    try {
      final uri = Uri.parse(path);
      final params = {...uri.queryParameters, if (more) 'cursor': cursor!};
      final result = await api.json(
        uri.replace(queryParameters: params.isEmpty ? null : params).toString(),
      );
      if (_disposed || generation != _generation) return;
      final seen = items.map((item) => item['id']).toSet();
      items.addAll(
        (result['items'] as List).cast<ClubMap>().where(
          (item) => seen.add(item['id']),
        ),
      );
      cursor = result['nextCursor'] as String?;
    } catch (failure) {
      if (!_disposed && generation == _generation) error = clubError(failure);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class ClubPagedList extends StatelessWidget {
  const ClubPagedList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.emptyText,
    this.header = const [],
    this.onRefresh,
  });
  final ClubPageController controller;
  final Widget Function(ClubMap) itemBuilder;
  final String emptyText;
  final List<Widget> header;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => RefreshIndicator(
      onRefresh: onRefresh ?? () => controller.load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ...header,
          for (final item in controller.items) itemBuilder(item),
          if (controller.items.isEmpty &&
              !controller.loading &&
              controller.error == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(emptyText, textAlign: TextAlign.center),
            ),
          if (controller.error != null)
            TextButton(
              onPressed: controller.loading
                  ? null
                  : () => controller.load(more: controller.failedMore),
              child: Text('${controller.error} 다시 시도'),
            ),
          if (controller.loading)
            const Center(child: CircularProgressIndicator()),
          if (!controller.loading &&
              controller.error == null &&
              controller.cursor != null)
            TextButton(
              onPressed: () => controller.load(more: true),
              child: const Text('더 보기'),
            ),
        ],
      ),
    ),
  );
}

class ClubLoadError extends StatelessWidget {
  const ClubLoadError({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TextButton(
        onPressed: retry,
        child: Text('${clubError(error)} 다시 시도'),
      ),
    ),
  );
}
