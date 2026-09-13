class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  final String email;
  final String otp;
  final String newPassword;

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'otp': otp.trim(),
      'newPassword': newPassword,
    };
  }
}
