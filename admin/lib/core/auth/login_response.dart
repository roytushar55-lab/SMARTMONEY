class LoginResponse {
  const LoginResponse({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
  });

  final String userId;
  final String fullName;
  final String email;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      accessTokenExpiresAt:
          DateTime.tryParse(json['accessTokenExpiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }
}
