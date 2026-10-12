import '../../../core/network/authorized_api_client.dart';
import '../models/admin_withdrawal.dart';

/// Admin withdrawal endpoints (`/api/admin/withdrawals`). Not-found, a state
/// that does not allow the action (409) and bad input (400) all surface as an
/// [ApiException] carrying the server's own plain-language message.
class AdminWithdrawalApiService {
  AdminWithdrawalApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  /// Newest first. Every filter is optional and they combine with "and": a raw
  /// [status] name, a work [queue] (`ToDecide`, `ToPay`, `InProgress`,
  /// `History`), only ones that need attention, free-text [search] (name,
  /// email, our reference, the bank reference or an amount) and a requested
  /// range where [from] is inclusive and [to] exclusive.
  Future<AdminWithdrawalPage> list({
    String? status,
    String? queue,
    bool needsAttentionOnly = false,
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
      if (needsAttentionOnly) 'needsAttention': 'true',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };

    final path = Uri(
      path: '/api/admin/withdrawals',
      queryParameters: query,
    ).toString();
    final json = await _client.getJson(path);
    return AdminWithdrawalPage.fromJson(json as Map<String, dynamic>);
  }

  /// The counts and rupee totals shown above the list.
  Future<AdminWithdrawalSummary> summary() async {
    final json = await _client.getJson('/api/admin/withdrawals/summary');
    return AdminWithdrawalSummary.fromJson(json as Map<String, dynamic>);
  }

  /// One withdrawal. While it is open the response includes the full payout
  /// destination.
  Future<AdminWithdrawal> get(String id) async {
    final json = await _client.getJson('/api/admin/withdrawals/$id');
    return AdminWithdrawal.fromJson(json as Map<String, dynamic>);
  }

  /// Clears a requested withdrawal for payout. With an automatic provider it
  /// is sent straight away; with the manual provider the admin then pays it
  /// and calls [markPaid].
  Future<WithdrawalDecision> approve(String id) => _decide(id, 'approve');

  /// Declines it. [reason] is shown to the user.
  Future<WithdrawalDecision> reject(String id, {required String reason}) =>
      _decide(id, 'reject', body: {'reason': reason});

  /// Records that the user was paid outside the system. [transactionReference]
  /// is the bank's UTR or transaction id.
  Future<WithdrawalDecision> markPaid(
    String id, {
    required String transactionReference,
  }) => _decide(
    id,
    'mark-paid',
    body: {'transactionReference': transactionReference},
  );

  /// Records that an approved payout could not be made. [reason] is shown to
  /// the user.
  Future<WithdrawalDecision> markFailed(String id, {required String reason}) =>
      _decide(id, 'mark-failed', body: {'reason': reason});

  /// Clears the needs-attention flag once an admin has dealt with it. Moves no
  /// money.
  Future<WithdrawalDecision> acknowledge(String id) =>
      _decide(id, 'acknowledge');

  Future<WithdrawalDecision> _decide(
    String id,
    String action, {
    Map<String, String>? body,
  }) async {
    final json = await _client.postJson(
      '/api/admin/withdrawals/$id/$action',
      body: body,
    );
    return WithdrawalDecision.fromJson(json as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
