class RefreshTokenResponse {
  const RefreshTokenResponse({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      accessToken: json['accessToken'] as String? ?? '',
      accessTokenExpiresAt:
          DateTime.tryParse(json['accessTokenExpiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }
}
