import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import 'club_ui.dart';

class ClubRunEditorScreen extends StatefulWidget {
  const ClubRunEditorScreen({
    super.key,
    required this.clubId,
    this.run,
    this.api,
  });
  final String clubId;
  final ClubMap? run;
  final RunlineApi? api;
  @override
  State<ClubRunEditorScreen> createState() => _ClubRunEditorScreenState();
}

class _ClubRunEditorScreenState extends State<ClubRunEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description, _location, _capacity;
  late DateTime _start, _end, _deadline;
  bool _saving = false;
  String? _error;
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  @override
  void initState() {
    super.initState();
    final run = widget.run;
    _title = TextEditingController(text: run?['title'] as String? ?? '');
    _description = TextEditingController(
      text: run?['description'] as String? ?? '',
    );
    _location = TextEditingController(text: run?['location'] as String? ?? '');
    _capacity = TextEditingController(
      text: (run?['capacity'] ?? 10).toString(),
    );
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _start = run == null
        ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19)
        : DateTime.parse(run['starts_at'] as String).toLocal();
    _end = run == null
        ? _start.add(const Duration(hours: 1))
        : DateTime.parse(run['ends_at'] as String).toLocal();
    _deadline = run == null
        ? _start.subtract(const Duration(hours: 1))
        : DateTime.parse(run['registration_closes_at'] as String).toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pick(String field) async {
    final current = field == 'start'
        ? _start
        : field == 'end'
        ? _end
        : _deadline;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (field == 'start') {
        _start = value;
      } else if (field == 'end') {
        _end = value;
      } else {
        _deadline = value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final original = widget.run;
    final values = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'location': _location.text.trim(),
      'capacity': int.parse(_capacity.text),
      'startsAt': _start.toUtc().toIso8601String(),
      'endsAt': _end.toUtc().toIso8601String(),
      'registrationClosesAt': _deadline.toUtc().toIso8601String(),
    };
    final body = Map<String, dynamic>.from(values);
    if (original != null) {
      const keys = {
        'startsAt': 'starts_at',
        'endsAt': 'ends_at',
        'registrationClosesAt': 'registration_closes_at',
      };
      body.removeWhere(
        (key, value) => keys.containsKey(key)
            ? DateTime.parse(original[keys[key]] as String)
                  .isAtSameMomentAs(DateTime.parse(value as String))
            : original[key] == value,
      );
    }
    final scheduleChanged =
        original == null ||
        body.containsKey('startsAt') ||
        body.containsKey('registrationClosesAt');
    String? issue;
    if (!_end.isAfter(_start)) {
      issue = '종료 시간은 시작 시간 이후로 선택해주세요.';
    } else if (_deadline.isAfter(_start)) {
      issue = '모집 마감은 시작 시간 이전으로 선택해주세요.';
    } else if (scheduleChanged &&
        (!_start.isAfter(DateTime.now()) ||
            !_deadline.isAfter(DateTime.now()))) {
      issue = '시작 시간과 모집 마감은 현재 시간 이후로 선택해주세요.';
    } else if (original != null &&
        int.parse(_capacity.text) < (original['participant_count'] as int)) {
      issue = '정원은 현재 참가 인원보다 적게 설정할 수 없어요.';
    }
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    if (body.isEmpty) {
      Navigator.pop(context, original!['id'] as String);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _api.json(
        '/clubs/${widget.clubId}/runs${original == null ? '' : '/${original['id']}'}',
        method: original == null ? 'POST' : 'PATCH',
        body: body,
      );
      if (mounted) Navigator.pop(context, result['run']['id'] as String);
    } catch (error) {
      if (mounted) setState(() => _error = clubError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.run == null ? '클럽 러닝 만들기' : '클럽 러닝 수정'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _title,
              enabled: !_saving,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '러닝 제목'),
              validator: (value) =>
                  value?.trim().isNotEmpty == true ? null : '제목을 입력해주세요.',
            ),
            TextFormField(
              controller: _location,
              enabled: !_saving,
              maxLength: 300,
              decoration: const InputDecoration(labelText: '모임 장소'),
              validator: (value) =>
                  value?.trim().isNotEmpty == true ? null : '모임 장소를 입력해주세요.',
            ),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              maxLength: 5000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '러닝 설명'),
            ),
            TextFormField(
              controller: _capacity,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '정원 (생성자 포함)'),
              validator: (value) {
                final n = int.tryParse(value ?? '');
                return n != null && n >= 1 && n <= 10000
                    ? null
                    : '1~10,000명을 입력해주세요.';
              },
            ),
            for (final entry in {
              'start': '시작 시간',
              'end': '종료 시간',
              'deadline': '모집 마감',
            }.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                subtitle: Text(
                  clubDate(
                    (entry.key == 'start'
                            ? _start
                            : entry.key == 'end'
                            ? _end
                            : _deadline)
                        .toIso8601String(),
                  ),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _saving ? null : () => _pick(entry.key),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중…' : '저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
