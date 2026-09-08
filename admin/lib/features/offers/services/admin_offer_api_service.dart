import '../../../core/network/authorized_api_client.dart';
import '../models/admin_offer.dart';

class AdminOfferApiService {
  AdminOfferApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<List<AdminOffer>> list({String? storeId}) async {
    final query = storeId == null ? '' : '?storeId=$storeId';
    final json = await _client.getJson('/api/admin/offers$query');
    return (json as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminOffer.fromJson)
        .toList();
  }

  Future<AdminOffer> create(Map<String, dynamic> body) async {
    final json = await _client.postJson('/api/admin/offers', body: body);
    return AdminOffer.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminOffer> update(String id, Map<String, dynamic> body) async {
    final json = await _client.putJson('/api/admin/offers/$id', body: body);
    return AdminOffer.fromJson(json as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
