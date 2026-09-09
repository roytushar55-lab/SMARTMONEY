import '../../../core/network/authorized_api_client.dart';
import '../models/admin_cashback.dart';

class AdminCashbackApiService {
  AdminCashbackApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<AdminCashbackPage> list({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = StringBuffer('?page=$page&pageSize=$pageSize');
    if (status != null && status.isNotEmpty) {
      query.write('&status=$status');
    }

    final json = await _client.getJson('/api/admin/cashbacks$query');
    return AdminCashbackPage.fromJson(json as Map<String, dynamic>);
  }

  Future<CashbackDecision> approve(String cashbackId) async {
    final json = await _client.postJson(
      '/api/admin/cashbacks/$cashbackId/approve',
    );
    return CashbackDecision.fromJson(json as Map<String, dynamic>);
  }

  Future<CashbackDecision> reject(String cashbackId) async {
    final json = await _client.postJson(
      '/api/admin/cashbacks/$cashbackId/reject',
    );
    return CashbackDecision.fromJson(json as Map<String, dynamic>);
  }

  Future<CashbackDecision> reverse(String cashbackId) async {
    final json = await _client.postJson(
      '/api/admin/cashbacks/$cashbackId/reverse',
    );
    return CashbackDecision.fromJson(json as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
