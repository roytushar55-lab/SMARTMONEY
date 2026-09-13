import '../../../core/network/authorized_api_client.dart';
import '../models/admin_store.dart';

class AdminStoreApiService {
  AdminStoreApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<List<AdminStore>> list() async {
    final json = await _client.getJson('/api/admin/stores');
    return (json as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminStore.fromJson)
        .toList();
  }

  Future<AdminStore> create({
    required String name,
    String? slug,
    String? shortDescription,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    required String websiteUrl,
    String? defaultCashbackText,
    bool isFeatured = false,
    int displayOrder = 0,
    required List<String> categoryIds,
  }) async {
    final json = await _client.postJson(
      '/api/admin/stores',
      body: {
        'name': name,
        'slug': slug,
        'shortDescription': shortDescription,
        'description': description,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'websiteUrl': websiteUrl,
        'defaultCashbackText': defaultCashbackText,
        'isFeatured': isFeatured,
        'displayOrder': displayOrder,
        'categoryIds': categoryIds,
      },
    );
    return AdminStore.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminStore> update(
    String id, {
    required String name,
    required String slug,
    String? shortDescription,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    required String websiteUrl,
    String? defaultCashbackText,
    bool isFeatured = false,
    int displayOrder = 0,
    required bool isActive,
    required List<String> categoryIds,
  }) async {
    final json = await _client.putJson(
      '/api/admin/stores/$id',
      body: {
        'name': name,
        'slug': slug,
        'shortDescription': shortDescription,
        'description': description,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'websiteUrl': websiteUrl,
        'defaultCashbackText': defaultCashbackText,
        'isFeatured': isFeatured,
        'displayOrder': displayOrder,
        'isActive': isActive,
        'categoryIds': categoryIds,
      },
    );
    return AdminStore.fromJson(json as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
