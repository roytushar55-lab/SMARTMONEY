class ForgotPasswordResponse {
  const ForgotPasswordResponse({required this.message});

  final String message;

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(message: json['message'] as String? ?? '');
  }
}
