class RunlineSession {
  const RunlineSession({
    this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  factory RunlineSession.fromJson(Map<String, dynamic> json) => RunlineSession(
    userId: json['user']?['id'] as String?,
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessTokenExpiresAt: DateTime.parse(
      json['accessTokenExpiresAt'] as String,
    ),
  );

  final String? userId;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
}
