bool get webTestLoginEnabled => false;
bool get hasWebLoginCallback => false;
void startWebTestLogin() => throw StateError('웹 로그인은 지원하지 않습니다.');
Map<String, String> consumeWebLoginCallback() =>
    throw StateError('웹 로그인은 지원하지 않습니다.');
