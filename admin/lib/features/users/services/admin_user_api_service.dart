import '../../../core/network/authorized_api_client.dart';
import '../models/admin_user_lookup.dart';
import '../models/admin_user_stats.dart';

class AdminUserApiService {
  AdminUserApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<AdminUserPage> listUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? isActive,
  }) async {
    final query = StringBuffer('/api/admin/users?page=$page&pageSize=$pageSize');
    if (search != null && search.trim().isNotEmpty) {
      query.write('&search=${Uri.encodeQueryComponent(search.trim())}');
    }
    if (isActive != null) {
      query.write('&isActive=$isActive');
    }
    final json = await _client.getJson(query.toString());
    return AdminUserPage.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminUserStats> getStats() async {
    final json = await _client.getJson('/api/admin/users/stats');
    return AdminUserStats.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminUserDetail> getUserDetail(String userId) async {
    final json = await _client.getJson('/api/admin/users/$userId');
    return AdminUserDetail.fromJson(json as Map<String, dynamic>);
  }

  /// Returns the server-confirmed `isActive` value from the status endpoint's
  /// `{ userId, email, isActive }` response.
  Future<bool> setActive(String userId, bool isActive) async {
    final json = await _client.postJson(
      '/api/admin/users/$userId/status',
      body: {'isActive': isActive},
    );
    final decoded = json as Map<String, dynamic>;
    return decoded['isActive'] as bool? ?? isActive;
  }

  /// [role] must be "Customer" or "Admin" — the backend rejects anything else.
  Future<void> changeRole(String userId, String role) async {
    await _client.postJson('/api/admin/users/$userId/role', body: {'role': role});
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
