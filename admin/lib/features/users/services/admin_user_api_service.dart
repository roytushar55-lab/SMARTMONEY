import '../../../core/network/api_exception.dart';
import '../../../core/network/authorized_api_client.dart';
import '../models/admin_user_lookup.dart';

class AdminUserApiService {
  AdminUserApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  /// Returns null when no user has this email (backend 404).
  Future<AdminUserLookup?> findByEmail(String email) async {
    try {
      final json = await _client.getJson(
        '/api/admin/users?email=${Uri.encodeQueryComponent(email)}',
      );
      return AdminUserLookup.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.isNotFound) return null;
      rethrow;
    }
  }

  /// [role] must be "Customer" or "Admin" — the backend rejects anything else.
  Future<AdminUserLookup> changeRole(String userId, String role) async {
    final json = await _client.postJson(
      '/api/admin/users/$userId/role',
      body: {'role': role},
    );
    final decoded = json as Map<String, dynamic>;
    return AdminUserLookup(
      userId: '${decoded['userId']}',
      email: decoded['email'] as String? ?? '',
      fullName: '',
      role: decoded['role'] as String? ?? '',
      isActive: true,
    );
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
