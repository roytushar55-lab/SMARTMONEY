import '../../../core/network/authorized_api_client.dart';
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

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
