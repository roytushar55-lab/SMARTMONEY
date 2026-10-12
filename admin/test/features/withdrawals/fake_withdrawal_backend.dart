import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'withdrawal_test_support.dart';

const upiDestination = {
  'method': 'Upi',
  'beneficiaryName': 'Withdraw Test User',
  'upiId': 'testuser@okhdfc',
  'bankAccountNumber': null,
  'ifscCode': null,
};

/// A small stand-in for the admin withdrawals API that keeps state, so an
/// action really changes what the next list or detail request returns.
class FakeWithdrawalBackend {
  FakeWithdrawalBackend(Iterable<Map<String, dynamic>> initial)
    : rows = {for (final row in initial) row['id'] as String: Map.of(row)} {
    server = FakeWithdrawalServer(_handle);
  }

  final Map<String, Map<String, dynamic>> rows;
  late final FakeWithdrawalServer server;

  /// The status an approve leaves the withdrawal in. `Approved` is the manual
  /// provider; the others mimic an automatic provider answering at once.
  String approveOutcome = 'Approved';

  /// Forces the answer to one action (`approve`, `reject`, `mark-paid`,
  /// `mark-failed`, `acknowledge`), for example a 409.
  final Map<String, http.Response> forced = {};

  /// While set, actions wait for it before answering.
  Completer<void>? holdActions;

  /// While set, GET detail answers with this instead of the row.
  http.Response? detailFailure;

  List<http.Request> get posts =>
      server.seen.where((r) => r.method == 'POST').toList();

  int get listRequests => server.seen
      .where((r) => r.method == 'GET' && r.url.path == '/api/admin/withdrawals')
      .length;

  int get detailRequests => server.seen
      .where(
        (r) =>
            r.method == 'GET' &&
            r.url.path.startsWith('/api/admin/withdrawals/') &&
            !r.url.path.endsWith('/summary'),
      )
      .length;

  Future<http.Response> _handle(http.Request request) async {
    final segments =
        request.url.pathSegments; // api, admin, withdrawals, id?, action?

    if (segments.length == 3) return _list(request);
    if (segments.length == 4 && segments[3] == 'summary') return _summary();

    final id = segments[3];

    if (request.method == 'GET') {
      if (detailFailure != null) return detailFailure!;
      final row = rows[id];
      return row == null
          ? jsonResponse({'message': 'Withdrawal not found.'}, 404)
          : jsonResponse(row);
    }

    final action = segments[4];
    if (holdActions != null) await holdActions!.future;
    if (forced[action] != null) return forced[action]!;

    final row = rows[id];
    if (row == null) {
      return jsonResponse({'message': 'Withdrawal not found.'}, 404);
    }

    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final now = DateTime.now().toUtc().toIso8601String();

    switch (action) {
      case 'approve':
        row['status'] = approveOutcome;
        row['approvedAt'] = now;
        row['reviewedByUserId'] = 'admin-1';
        if (approveOutcome == 'Completed' || approveOutcome == 'Failed') {
          row['settledAt'] = now;
          row['destination'] = null;
        }
      case 'reject':
        row['status'] = 'Rejected';
        row['failureReason'] = body['reason'];
        row['reviewedByUserId'] = 'admin-1';
        _settle(row, now);
      case 'mark-paid':
        if (row['status'] == 'Requested') {
          row['approvedAt'] = now;
          row['reviewedByUserId'] = 'admin-1';
        }
        row['status'] = 'Completed';
        row['providerReference'] = body['transactionReference'];
        _settle(row, now);
      case 'mark-failed':
        row['status'] = 'Failed';
        row['failureReason'] = body['reason'];
        _settle(row, now);
      case 'acknowledge':
        row['needsAttention'] = false;
    }

    return jsonResponse({
      'withdrawalId': id,
      'reference': row['reference'],
      'status': row['status'],
      'availableBalance': 1000,
      'heldBalance': 0,
    });
  }

  void _settle(Map<String, dynamic> row, String now) {
    row['settledAt'] = now;
    row['destination'] = null;
    row['needsAttention'] = false;
  }

  static const _queueOf = {
    'Requested': 'ToDecide',
    'Approved': 'ToPay',
    'Processing': 'InProgress',
  };

  // Settled statuses are not in the map: they are History.
  static String queueOf(Object? status) => _queueOf[status] ?? 'History';

  http.Response _summary() {
    int inQueue(String queue) =>
        rows.values.where((r) => queueOf(r['status']) == queue).length;
    num amount(String queue) => rows.values
        .where((r) => queueOf(r['status']) == queue)
        .fold<num>(0, (sum, r) => sum + (r['netAmount'] as num));

    return jsonResponse({
      'toDecide': inQueue('ToDecide'),
      'toDecideAmount': amount('ToDecide'),
      'toPay': inQueue('ToPay'),
      'toPayAmount': amount('ToPay'),
      'inProgress': inQueue('InProgress'),
      'history': inQueue('History'),
      'needsAttention': rows.values
          .where((r) => r['needsAttention'] == true)
          .length,
      'paidLast30Days': rows.values
          .where((r) => r['status'] == 'Completed')
          .length,
      'paidLast30DaysAmount': 0,
    });
  }

  http.Response _list(http.Request request) {
    final status = request.url.queryParameters['status'];
    final queue = request.url.queryParameters['queue'];
    final attentionOnly =
        request.url.queryParameters['needsAttention'] == 'true';

    final items = rows.values
        .where((r) => status == null || r['status'] == status)
        .where((r) => queue == null || queueOf(r['status']) == queue)
        .where((r) => !attentionOnly || r['needsAttention'] == true)
        // The list never carries bank details.
        .map((r) => {...r, 'destination': null})
        .toList();

    return jsonResponse(withdrawalPage(items));
  }
}
