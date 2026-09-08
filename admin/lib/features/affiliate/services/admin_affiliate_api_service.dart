import '../../../core/network/authorized_api_client.dart';
import '../models/admin_affiliate_network.dart';

class AdminAffiliateApiService {
  AdminAffiliateApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<List<AdminAffiliateNetwork>> listNetworks() async {
    final json = await _client.getJson('/api/admin/affiliate-networks');
    return (json as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminAffiliateNetwork.fromJson)
        .toList();
  }

  Future<AdminAffiliateNetwork> createNetwork(String name, String code) async {
    final json = await _client.postJson(
      '/api/admin/affiliate-networks',
      body: {'name': name, 'code': code},
    );
    return AdminAffiliateNetwork.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminAffiliateNetwork> updateNetwork(
    String id, {
    required String name,
    required String code,
    required bool isActive,
  }) async {
    final json = await _client.putJson(
      '/api/admin/affiliate-networks/$id',
      body: {'name': name, 'code': code, 'isActive': isActive},
    );
    return AdminAffiliateNetwork.fromJson(json as Map<String, dynamic>);
  }

  Future<List<AdminStoreAffiliateMapping>> listMappings({String? storeId}) async {
    final query = storeId == null ? '' : '?storeId=$storeId';
    final json = await _client.getJson('/api/admin/store-affiliate-mappings$query');
    return (json as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminStoreAffiliateMapping.fromJson)
        .toList();
  }

  Future<AdminStoreAffiliateMapping> createMapping({
    required String storeId,
    required String affiliateNetworkId,
    required String externalMerchantId,
    String? externalMerchantName,
    String? merchantUrl,
  }) async {
    final json = await _client.postJson(
      '/api/admin/store-affiliate-mappings',
      body: {
        'storeId': storeId,
        'affiliateNetworkId': affiliateNetworkId,
        'externalMerchantId': externalMerchantId,
        'externalMerchantName': externalMerchantName,
        'merchantUrl': merchantUrl,
      },
    );
    return AdminStoreAffiliateMapping.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminStoreAffiliateMapping> updateMapping(
    String id, {
    required String externalMerchantId,
    String? externalMerchantName,
    String? merchantUrl,
    required bool isActive,
  }) async {
    final json = await _client.putJson(
      '/api/admin/store-affiliate-mappings/$id',
      body: {
        'externalMerchantId': externalMerchantId,
        'externalMerchantName': externalMerchantName,
        'merchantUrl': merchantUrl,
        'isActive': isActive,
      },
    );
    return AdminStoreAffiliateMapping.fromJson(json as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
