import '../../../core/network/authorized_api_client.dart';
import '../models/admin_cashback.dart';

class AdminCashbackApiService {
  AdminCashbackApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  /// One page of cashbacks. Every filter is optional and they combine with
  /// "and": the raw [status], a work [queue] (`ReadyToApprove`, ...), only
  /// [overdue] ones, free-text [search] (user, email, store or an amount) and
  /// a created range where [from] is inclusive and [to] exclusive.
  Future<AdminCashbackPage> list({
    String? status,
    String? queue,
    bool overdue = false,
    String? search,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (status != null && status.isNotEmpty) 'status': status,
      if (queue != null && queue.isNotEmpty) 'queue': queue,
      if (overdue) 'overdue': 'true',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };

    final path = Uri(
      path: '/api/admin/cashbacks',
      queryParameters: query,
    ).toString();
    final json = await _client.getJson(path);
    return AdminCashbackPage.fromJson(json as Map<String, dynamic>);
  }

  /// The counts and the exposure shown above the list.
  Future<AdminCashbackSummary> summary() async {
    final json = await _client.getJson('/api/admin/cashbacks/summary');
    return AdminCashbackSummary.fromJson(json as Map<String, dynamic>);
  }

  /// The audit trail of one cashback, oldest first: what the network
  /// reported and what each admin decided, with who and why.
  Future<List<AdminCashbackEvent>> events(String cashbackId) async {
    final json = await _client.getJson(
      '/api/admin/cashbacks/$cashbackId/events',
    );
    return (json as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminCashbackEvent.fromJson)
        .toList();
  }

  /// Approves a cashback. The server refuses it unless the network says the
  /// sale is validated. A SuperAdmin may pass [override] with a [reason] to
  /// approve anyway; the reason is recorded in the cashback's audit trail.
  Future<CashbackDecision> approve(
    String cashbackId, {
    String? reason,
    bool override = false,
  }) async {
    final body = <String, Object?>{
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (override) 'override': true,
    };
    final json = await _client.postJson(
      '/api/admin/cashbacks/$cashbackId/approve',
      body: body.isEmpty ? null : body,
    );
    return CashbackDecision.fromJson(json as Map<String, dynamic>);
  }

  /// Rejects a never-confirmed cashback. The server requires a [reason] and
  /// keeps it, with the admin's name, in the cashback's audit trail.
  Future<CashbackDecision> reject(String cashbackId, String reason) async {
    final json = await _client.postJson(
      '/api/admin/cashbacks/$cashbackId/reject',
      body: {'reason': reason.trim()},
    );
    return CashbackDecision.fromJson(json as Map<String, dynamic>);
  }

  /// Reverses a confirmed cashback and takes the money back. The server
  /// requires a [reason] and keeps it in the audit trail.
  Future<CashbackDecision> reverse(String cashbackId, String reason) async {
    final json = await _client.postJson(
      '/api/admin/cashbacks/$cashbackId/reverse',
      body: {'reason': reason.trim()},
    );
    return CashbackDecision.fromJson(json as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
