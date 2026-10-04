class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    this.referralCode,
    required this.ageConfirmed,
    required this.termsAccepted,
    required this.consentVersion,
  });

  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String? referralCode;
  final bool ageConfirmed;
  final bool termsAccepted;
  final String consentVersion;

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phoneNumber': phoneNumber.trim(),
      'password': password,
      'referralCode': referralCode?.trim().isEmpty == true
          ? null
          : referralCode?.trim(),
      'ageConfirmed': ageConfirmed,
      'termsAccepted': termsAccepted,
      'consentVersion': consentVersion,
    };
  }
}
