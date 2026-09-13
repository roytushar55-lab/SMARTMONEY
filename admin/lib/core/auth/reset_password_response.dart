class ResetPasswordResponse {
  const ResetPasswordResponse({required this.email, required this.message});

  final String email;
  final String message;

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      email: json['email'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}
