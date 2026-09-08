/// Mirrors the backend's `AffiliateNetworkAdminResponse`.
class AdminAffiliateNetwork {
  const AdminAffiliateNetwork({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
  });

  final String id;
  final String name;
  final String code;
  final bool isActive;

  factory AdminAffiliateNetwork.fromJson(Map<String, dynamic> json) {
    return AdminAffiliateNetwork(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

/// Mirrors the backend's `StoreAffiliateMappingAdminResponse`.
class AdminStoreAffiliateMapping {
  const AdminStoreAffiliateMapping({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.affiliateNetworkId,
    required this.affiliateNetworkName,
    required this.externalMerchantId,
    required this.externalMerchantName,
    required this.merchantUrl,
    required this.isActive,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String affiliateNetworkId;
  final String affiliateNetworkName;
  final String externalMerchantId;
  final String? externalMerchantName;
  final String? merchantUrl;
  final bool isActive;

  factory AdminStoreAffiliateMapping.fromJson(Map<String, dynamic> json) {
    return AdminStoreAffiliateMapping(
      id: '${json['id']}',
      storeId: '${json['storeId']}',
      storeName: json['storeName'] as String? ?? '',
      affiliateNetworkId: '${json['affiliateNetworkId']}',
      affiliateNetworkName: json['affiliateNetworkName'] as String? ?? '',
      externalMerchantId: json['externalMerchantId'] as String? ?? '',
      externalMerchantName: json['externalMerchantName'] as String?,
      merchantUrl: json['merchantUrl'] as String?,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
