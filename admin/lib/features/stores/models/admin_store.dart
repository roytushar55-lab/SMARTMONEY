/// Mirrors the backend's `StoreAdminResponse`.
class AdminStore {
  const AdminStore({
    required this.id,
    required this.name,
    required this.slug,
    required this.shortDescription,
    required this.description,
    required this.logoUrl,
    required this.bannerUrl,
    required this.websiteUrl,
    required this.defaultCashbackText,
    required this.isFeatured,
    required this.displayOrder,
    required this.isActive,
    required this.categoryIds,
  });

  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String websiteUrl;
  final String? defaultCashbackText;
  final bool isFeatured;
  final int displayOrder;
  final bool isActive;
  final List<String> categoryIds;

  factory AdminStore.fromJson(Map<String, dynamic> json) {
    return AdminStore(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      shortDescription: json['shortDescription'] as String?,
      description: json['description'] as String?,
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      websiteUrl: json['websiteUrl'] as String? ?? '',
      defaultCashbackText: json['defaultCashbackText'] as String?,
      isFeatured: json['isFeatured'] as bool? ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      categoryIds: (json['categoryIds'] as List? ?? [])
          .map((id) => '$id')
          .toList(),
    );
  }
}
