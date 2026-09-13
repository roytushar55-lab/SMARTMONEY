import 'admin_cashback_rate_override.dart';

/// Network-wide global cashback settings for one affiliate network. `null`
/// when the network has no override of the platform defaults yet.
class AdminNetworkCashbackGlobal {
  const AdminNetworkCashbackGlobal({
    required this.userSharePercent,
    required this.confirmationWindowDays,
  });

  final double userSharePercent;
  final int confirmationWindowDays;

  factory AdminNetworkCashbackGlobal.fromJson(Map<String, dynamic> json) {
    return AdminNetworkCashbackGlobal(
      userSharePercent: (json['userSharePercent'] as num?)?.toDouble() ?? 0,
      confirmationWindowDays:
          (json['confirmationWindowDays'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Mirrors the backend's network cashback-settings detail response: the
/// network's global policy (if set) plus its store/category overrides.
class AdminNetworkCashbackDetail {
  const AdminNetworkCashbackDetail({
    required this.networkId,
    required this.networkName,
    required this.global,
    required this.overrides,
  });

  final String networkId;
  final String networkName;
  final AdminNetworkCashbackGlobal? global;
  final List<AdminCashbackRateOverride> overrides;

  factory AdminNetworkCashbackDetail.fromJson(
    Map<String, dynamic> json, {
    String networkName = '',
  }) {
    final globalJson = json['global'] ?? json['networkSettings'];
    return AdminNetworkCashbackDetail(
      networkId: '${json['networkId'] ?? json['affiliateNetworkId']}',
      networkName: json['networkName'] as String? ?? networkName,
      global: globalJson == null
          ? null
          : AdminNetworkCashbackGlobal.fromJson(
              globalJson as Map<String, dynamic>,
            ),
      overrides: (json['overrides'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminCashbackRateOverride.fromJson)
          .toList(),
    );
  }
}
