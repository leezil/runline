import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'runline_auth.dart';
import 'web_test_login.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authentication,
    this.completeWebLogin = false,
  });
  final TabAuthentication authentication;
  final bool completeWebLogin;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  late bool _completeWebLogin = widget.completeWebLogin;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.completeWebLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _login());
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (kIsWeb && !_completeWebLogin) {
        startWebTestLogin();
        return;
      }
      await widget.authentication.signIn();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '로그인에 실패했습니다. 서버 설정과 네트워크를 확인하고 다시 시도해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _completeWebLogin = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Runline',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                const Text('로그인하고 러너들의 소식을 만나보세요.'),
                const SizedBox(height: 24),
                if (kIsWeb && !webTestLoginEnabled)
                  const Text('웹 로그인은 테스트 빌드에서만 사용할 수 있습니다.'),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_loading) const CircularProgressIndicator(),
                FilledButton(
                  onPressed: _loading || (kIsWeb && !webTestLoginEnabled)
                      ? null
                      : _login,
                  child: const Text('카카오로 계속하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
