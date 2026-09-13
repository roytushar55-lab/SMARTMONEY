/// Mirrors the backend's `AdminUserLookupResponse`.
class AdminUserLookup {
  const AdminUserLookup({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final String userId;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;

  factory AdminUserLookup.fromJson(Map<String, dynamic> json) {
    return AdminUserLookup(
      userId: '${json['userId']}',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  AdminUserLookup copyWith({String? role}) {
    return AdminUserLookup(
      userId: userId,
      email: email,
      fullName: fullName,
      role: role ?? this.role,
      isActive: isActive,
    );
  }
}
