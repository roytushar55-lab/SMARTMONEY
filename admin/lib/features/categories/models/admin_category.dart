/// Mirrors the backend's `CategoryAdminResponse`.
class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.iconUrl,
    required this.displayOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
