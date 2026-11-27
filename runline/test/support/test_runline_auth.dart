import 'package:runline/features/auth/runline_auth.dart';

class TestRunlineAuth extends RunlineAuth {
  String? _token;

  @override
  String? get accessToken => _token;
  @override
  bool get isSignedIn => _token != null;
  @override
  String? get userId => isSignedIn ? 'test-user' : null;
  @override
  Future<bool> hasSession() async => isSignedIn;

  void setAccessToken(String? token) {
    _token = token;
    notifyListeners();
  }
}
