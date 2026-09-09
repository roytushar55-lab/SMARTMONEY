/// Mirrors the backend's `OfferAdminResponse`.
class AdminOffer {
  const AdminOffer({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.title,
    required this.slug,
    required this.offerType,
    required this.shortDescription,
    required this.description,
    required this.termsAndConditions,
    required this.imageUrl,
    required this.cashbackType,
    required this.cashbackValue,
    required this.cashbackText,
    required this.couponCode,
    required this.destinationUrl,
    required this.startAt,
    required this.endAt,
    required this.isFeatured,
    required this.priority,
    required this.isActive,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String title;
  final String slug;
  final String offerType;
  final String? shortDescription;
  final String? description;
  final String? termsAndConditions;
  final String? imageUrl;
  final String cashbackType;
  final double? cashbackValue;
  final String? cashbackText;
  final String? couponCode;
  final String destinationUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isFeatured;
  final int priority;
  final bool isActive;

  factory AdminOffer.fromJson(Map<String, dynamic> json) {
    return AdminOffer(
      id: '${json['id']}',
      storeId: '${json['storeId']}',
      storeName: json['storeName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      offerType: json['offerType'] as String? ?? '',
      shortDescription: json['shortDescription'] as String?,
      description: json['description'] as String?,
      termsAndConditions: json['termsAndConditions'] as String?,
      imageUrl: json['imageUrl'] as String?,
      cashbackType: json['cashbackType'] as String? ?? 'None',
      cashbackValue: (json['cashbackValue'] as num?)?.toDouble(),
      cashbackText: json['cashbackText'] as String?,
      couponCode: json['couponCode'] as String?,
      destinationUrl: json['destinationUrl'] as String? ?? '',
      startAt: json['startAt'] == null
          ? null
          : DateTime.tryParse('${json['startAt']}'),
      endAt: json['endAt'] == null
          ? null
          : DateTime.tryParse('${json['endAt']}'),
      isFeatured: json['isFeatured'] as bool? ?? false,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

const List<String> kOfferTypes = ['Cashback', 'Coupon', 'Deal'];
const List<String> kCashbackTypes = [
  'Percentage',
  'FlatAmount',
  'Variable',
  'None',
];
