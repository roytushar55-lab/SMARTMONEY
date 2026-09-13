import '../../../core/network/authorized_api_client.dart';
import '../models/admin_category.dart';

class AdminCategoryApiService {
  AdminCategoryApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<List<AdminCategory>> list() async {
    final json = await _client.getJson('/api/admin/categories');
    return (json as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminCategory.fromJson)
        .toList();
  }

  Future<AdminCategory> create({
    required String name,
    String? slug,
    String? description,
    String? iconUrl,
    int displayOrder = 0,
  }) async {
    final json = await _client.postJson(
      '/api/admin/categories',
      body: {
        'name': name,
        'slug': slug,
        'description': description,
        'iconUrl': iconUrl,
        'displayOrder': displayOrder,
      },
    );
    return AdminCategory.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminCategory> update(
    String id, {
    required String name,
    required String slug,
    String? description,
    String? iconUrl,
    int displayOrder = 0,
    required bool isActive,
  }) async {
    final json = await _client.putJson(
      '/api/admin/categories/$id',
      body: {
        'name': name,
        'slug': slug,
        'description': description,
        'iconUrl': iconUrl,
        'displayOrder': displayOrder,
        'isActive': isActive,
      },
    );
    return AdminCategory.fromJson(json as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
