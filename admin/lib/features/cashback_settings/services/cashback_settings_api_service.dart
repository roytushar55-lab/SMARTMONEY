import '../../../core/network/authorized_api_client.dart';
import '../../affiliate/models/admin_affiliate_network.dart';
import '../models/admin_cashback_rate_override.dart';
import '../models/admin_network_cashback_settings.dart';
import '../models/cashback_settings.dart';

class CashbackSettingsApiService {
  CashbackSettingsApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<AdminCashbackSettings> get() async {
    final json = await _client.getJson('/api/admin/cashback-settings');
    return AdminCashbackSettings.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminCashbackSettings> update({
    required double userSharePercent,
    required int confirmationWindowDays,
  }) async {
    final json = await _client.putJson(
      '/api/admin/cashback-settings',
      body: {
        'userSharePercent': userSharePercent,
        'confirmationWindowDays': confirmationWindowDays,
      },
    );
    return AdminCashbackSettings.fromJson(json as Map<String, dynamic>);
  }

  // -- Hierarchical (per-network) cashback settings --------------------

  Future<List<AdminAffiliateNetwork>> listNetworks() async {
    final json = await _client.getJson(
      '/api/admin/cashback-settings/networks',
    );
    return (json as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminAffiliateNetwork.fromJson)
        .toList();
  }

  Future<AdminNetworkCashbackDetail> getNetworkSettings(
    String networkId,
  ) async {
    final json = await _client.getJson(
      '/api/admin/cashback-settings/networks/$networkId',
    );
    return AdminNetworkCashbackDetail.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminNetworkCashbackGlobal> updateNetworkGlobal(
    String networkId, {
    required double userSharePercent,
    required int confirmationWindowDays,
  }) async {
    final json = await _client.putJson(
      '/api/admin/cashback-settings/networks/$networkId',
      body: {
        'userSharePercent': userSharePercent,
        'confirmationWindowDays': confirmationWindowDays,
      },
    );
    return AdminNetworkCashbackGlobal.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminCashbackRateOverride> createOverride(
    String networkId, {
    required String storeId,
    String? categoryId,
    required double userSharePercent,
    required int confirmationWindowDays,
  }) async {
    final json = await _client.postJson(
      '/api/admin/cashback-settings/networks/$networkId/overrides',
      body: {
        'storeId': storeId,
        'categoryId': categoryId,
        'userSharePercent': userSharePercent,
        'confirmationWindowDays': confirmationWindowDays,
      },
    );
    return AdminCashbackRateOverride.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminCashbackRateOverride> updateOverride(
    String networkId,
    String overrideId, {
    required double userSharePercent,
    required int confirmationWindowDays,
  }) async {
    final json = await _client.putJson(
      '/api/admin/cashback-settings/networks/$networkId/overrides/$overrideId',
      body: {
        'userSharePercent': userSharePercent,
        'confirmationWindowDays': confirmationWindowDays,
      },
    );
    return AdminCashbackRateOverride.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteOverride(String networkId, String overrideId) async {
    await _client.deleteJson(
      '/api/admin/cashback-settings/networks/$networkId/overrides/$overrideId',
    );
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
