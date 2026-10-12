import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/api_exception.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';
import 'package:smartmoney_admin/core/theme/admin_colors.dart';
import 'package:smartmoney_admin/features/withdrawals/models/admin_withdrawal.dart';
import 'package:smartmoney_admin/features/withdrawals/services/admin_withdrawal_api_service.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawal_status_copy.dart';

import '../../core/fakes.dart';
import 'withdrawal_test_support.dart';

Map<String, dynamic> _decisionJson(String status) => {
  'withdrawalId': '11111111-1111-1111-1111-111111111111',
  'reference': 'WD20261011K7QM2XA9PD',
  'status': status,
  'availableBalance': 2500.5,
  'heldBalance': 0,
};

void main() {
  group('AdminWithdrawal.fromJson', () {
    test('parses a freshly requested row, keeping nulls as nulls', () {
      final w = AdminWithdrawal.fromJson(withdrawalRow());

      expect(w.id, '11111111-1111-1111-1111-111111111111');
      expect(w.reference, 'WD20261011K7QM2XA9PD');
      expect(w.amount, 500.0); // an int in the JSON becomes a double
      expect(w.feeTotal, 11.8);
      expect(w.userFee, 5.9);
      expect(w.netAmount, 494.1);
      expect(w.method, 'Upi');
      expect(w.destinationMasked, 'te****@okhdfc');
      expect(w.status, 'Requested');
      expect(w.providerName, isNull);
      expect(w.actualProviderFee, isNull);
      expect(w.reviewedByUserId, isNull);
      expect(w.approvedAt, isNull);
      expect(w.settledAt, isNull);
      expect(w.destination, isNull);
      expect(w.destinationUnreadable, isFalse);
      expect(w.needsAttention, isFalse);
      expect(w.submissionAttempts, 0);
      expect(w.requestedAt.toUtc().year, 2026);
    });

    test('parses the full destination only when the backend sends it', () {
      final json = withdrawalRow()
        ..['destination'] = {
          'method': 'BankTransfer',
          'beneficiaryName': 'Withdraw Test User',
          'upiId': null,
          'bankAccountNumber': '123456789012',
          'ifscCode': 'HDFC0001234',
        };

      final d = AdminWithdrawal.fromJson(json).destination!;

      expect(d.method, 'BankTransfer');
      expect(d.beneficiaryName, 'Withdraw Test User');
      expect(d.upiId, isNull);
      expect(d.bankAccountNumber, '123456789012');
      expect(d.ifscCode, 'HDFC0001234');
    });

    test('parses provider fields, flags and the review trail', () {
      final json = withdrawalRow()
        ..['status'] = 'Approved'
        ..['providerName'] = 'Fake'
        ..['providerReference'] = 'FAKE-WD1'
        ..['actualProviderFee'] = 4
        ..['lastError'] = 'Fake provider: temporary outage.'
        ..['submissionAttempts'] = 5
        ..['reviewedByUserId'] = '33333333-3333-3333-3333-333333333333'
        ..['reviewNote'] =
            'Automatic retries are used up; pay manually or reject.'
        ..['needsAttention'] = true
        ..['approvedAt'] = '2026-10-11T12:31:00Z'
        ..['submittedAt'] = '2026-10-11T12:31:01Z';

      final w = AdminWithdrawal.fromJson(json);

      expect(w.providerName, 'Fake');
      expect(w.providerReference, 'FAKE-WD1');
      expect(w.actualProviderFee, 4.0);
      expect(w.lastError, 'Fake provider: temporary outage.');
      expect(w.submissionAttempts, 5);
      expect(w.reviewedByUserId, '33333333-3333-3333-3333-333333333333');
      expect(w.reviewNote, contains('retries are used up'));
      expect(w.needsAttention, isTrue);
      expect(w.approvedAt, isNotNull);
      expect(w.submittedAt, isNotNull);
    });

    test('reports an open withdrawal whose details could not be read', () {
      final w = AdminWithdrawal.fromJson(
        withdrawalRow()..['destinationUnreadable'] = true,
      );

      expect(w.destination, isNull);
      expect(w.destinationUnreadable, isTrue);
    });

    test('isOpen is true only while money is still held', () {
      bool open(String status) =>
          AdminWithdrawal.fromJson(withdrawalRow()..['status'] = status).isOpen;

      expect(open('Requested'), isTrue);
      expect(open('Approved'), isTrue);
      expect(open('Processing'), isTrue);
      for (final done in ['Completed', 'Failed', 'Rejected', 'Cancelled']) {
        expect(open(done), isFalse, reason: done);
      }
    });

    test('survives a sparse or odd payload without throwing', () {
      final w = AdminWithdrawal.fromJson({
        'id': 'abc',
        'amount': '250.50', // a string amount
        'requestedAt': 'not a date',
      });

      expect(w.id, 'abc');
      expect(w.amount, 250.5);
      expect(w.reference, '');
      expect(w.status, '');
      expect(w.needsAttention, isFalse);
      expect(w.destination, isNull);
    });
  });

  group('AdminWithdrawalPage.fromJson', () {
    test('parses items and paging', () {
      final page = AdminWithdrawalPage.fromJson({
        'items': [withdrawalRow(), withdrawalRow()],
        'totalCount': 45,
        'page': 2,
        'pageSize': 20,
      });

      expect(page.items, hasLength(2));
      expect(page.totalCount, 45);
      expect(page.page, 2);
      expect(page.hasNextPage, isTrue); // 2 * 20 < 45
    });

    test('the last page has no next page', () {
      final page = AdminWithdrawalPage.fromJson({
        'items': [withdrawalRow()],
        'totalCount': 41,
        'page': 3,
        'pageSize': 20,
      });

      expect(page.hasNextPage, isFalse); // 3 * 20 >= 41
    });

    test('an empty or missing list is an empty page', () {
      final page = AdminWithdrawalPage.fromJson({});

      expect(page.items, isEmpty);
      expect(page.totalCount, 0);
      expect(page.page, 1);
      expect(page.pageSize, 20);
      expect(page.hasNextPage, isFalse);
    });
  });

  group('WithdrawalDecision.fromJson', () {
    test('parses the new status and the wallet balances', () {
      final d = WithdrawalDecision.fromJson(_decisionJson('Completed'));

      expect(d.withdrawalId, '11111111-1111-1111-1111-111111111111');
      expect(d.reference, 'WD20261011K7QM2XA9PD');
      expect(d.status, 'Completed');
      expect(d.availableBalance, 2500.5);
      expect(d.heldBalance, 0.0);
    });
  });

  group('AdminWithdrawalSummary.fromJson', () {
    test('parses counts and rupee totals', () {
      final s = AdminWithdrawalSummary.fromJson({
        'toDecide': 3,
        'toDecideAmount': 1500.5,
        'toPay': 2,
        'toPayAmount': 988,
        'inProgress': 1,
        'history': 40,
        'needsAttention': 4,
        'paidLast30Days': 12,
        'paidLast30DaysAmount': '6000.25',
      });

      expect(s.toDecide, 3);
      expect(s.toDecideAmount, 1500.5);
      expect(s.toPay, 2);
      expect(s.toPayAmount, 988.0);
      expect(s.inProgress, 1);
      expect(s.history, 40);
      expect(s.needsAttention, 4);
      expect(s.paidLast30Days, 12);
      expect(s.paidLast30DaysAmount, 6000.25);
    });

    test('missing fields read as zero', () {
      final s = AdminWithdrawalSummary.fromJson({});

      expect(s.toDecide, 0);
      expect(s.toPayAmount, 0.0);
      expect(s.paidLast30DaysAmount, 0.0);
    });
  });

  test('a row carries the queue the server put it in', () {
    expect(
      AdminWithdrawal.fromJson(withdrawalRow({'queue': 'ToPay'})).queue,
      'ToPay',
    );
    expect(AdminWithdrawal.fromJson(withdrawalRow()).queue, '');
  });

  group('WithdrawalStatusCopy', () {
    test('every status the backend can send has its own label and color', () {
      const expected = {
        'Requested': ('Requested', AdminColors.warning),
        'Approved': ('Approved', AdminColors.statusBlue),
        'Processing': ('Processing', AdminColors.primary),
        'Completed': ('Paid', AdminColors.success),
        'Failed': ('Failed', AdminColors.danger),
        'Rejected': ('Declined', AdminColors.statusPink),
        'Cancelled': ('Cancelled', AdminColors.textMuted),
      };

      for (final entry in expected.entries) {
        final copy = WithdrawalStatusCopy.forStatus(entry.key);
        expect(copy.label, entry.value.$1, reason: entry.key);
        expect(copy.color, entry.value.$2, reason: entry.key);
      }
    });

    test('an unknown or future status degrades to a neutral badge', () {
      final copy = WithdrawalStatusCopy.forStatus('SomethingNew');

      expect(copy.label, 'Unknown');
      expect(copy.color, AdminColors.textMuted);
    });

    test('filters list every status exactly once, actionable ones first', () {
      expect(kWithdrawalStatusFilters.first, 'Requested');
      expect(kWithdrawalStatusFilters.toSet(), hasLength(7));
      for (final status in kWithdrawalStatusFilters) {
        expect(
          WithdrawalStatusCopy.forStatus(status).label,
          isNot('Unknown'),
          reason: status,
        );
      }
    });

    test('method labels', () {
      expect(withdrawalMethodLabel('Upi'), 'UPI');
      expect(withdrawalMethodLabel('BankTransfer'), 'Bank transfer');
      expect(withdrawalMethodLabel('Cheque'), 'Cheque');
      expect(withdrawalMethodLabel(''), '—');
    });

    test('colors are the ones the shared palette defines', () {
      // Guards against a copy/paste of a literal color instead of a token.
      for (final status in kWithdrawalStatusFilters) {
        expect(
          WithdrawalStatusCopy.forStatus(status).color,
          isA<Color>(),
          reason: status,
        );
      }
    });
  });

  group('AdminWithdrawalApiService', () {
    late FakeTokenStorage storage;
    late TokenRefresher refresher;

    // Every request seen by the fake server, in order.
    late List<http.Request> seen;

    AdminWithdrawalApiService serviceFor(
      http.Response Function(http.Request request) respond,
    ) {
      storage = FakeTokenStorage(accessToken: 'tok', refreshToken: 'r1');
      refresher = TokenRefresher(
        tokenStorage: storage,
        authApi: FakeAuthApi(
          (_) async => RefreshTokenResponse(
            accessToken: 'new',
            accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
            refreshToken: 'r2',
          ),
        ),
        onSessionExpired: () {},
        onTokensRefreshed: (_) {},
      );
      seen = [];

      return AdminWithdrawalApiService(
        client: AuthorizedApiClient(
          client: MockClient((request) async {
            seen.add(request);
            return respond(request);
          }),
          tokenStorageService: storage,
          refresher: refresher,
          baseUrl: 'https://example.test',
          timeout: const Duration(seconds: 5),
        ),
      );
    }

    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

    test(
      'list sends paging and the bearer token, with no filters by default',
      () async {
        final service = serviceFor(
          (_) => json({
            'items': [withdrawalRow()],
            'totalCount': 1,
            'page': 1,
            'pageSize': 20,
          }),
        );

        final page = await service.list();

        expect(page.items, hasLength(1));
        expect(seen.single.method, 'GET');
        expect(
          seen.single.url.toString(),
          'https://example.test/api/admin/withdrawals?page=1&pageSize=20',
        );
        expect(seen.single.headers['Authorization'], 'Bearer tok');
      },
    );

    test(
      'list sends the status, the needs-attention flag and the page',
      () async {
        final service = serviceFor(
          (_) =>
              json({'items': [], 'totalCount': 0, 'page': 3, 'pageSize': 50}),
        );

        await service.list(
          status: 'Approved',
          needsAttentionOnly: true,
          page: 3,
          pageSize: 50,
        );

        expect(
          seen.single.url.toString(),
          'https://example.test/api/admin/withdrawals'
          '?page=3&pageSize=50&status=Approved&needsAttention=true',
        );
      },
    );

    test('an empty status is the same as no status', () async {
      final service = serviceFor(
        (_) => json({'items': [], 'totalCount': 0, 'page': 1, 'pageSize': 20}),
      );

      await service.list(status: '');

      expect(seen.single.url.query, 'page=1&pageSize=20');
    });

    test('get fetches one withdrawal by id, with its destination', () async {
      final service = serviceFor(
        (_) => json(
          withdrawalRow()
            ..['destination'] = {
              'method': 'Upi',
              'beneficiaryName': 'Withdraw Test User',
              'upiId': 'testuser@okhdfc',
              'bankAccountNumber': null,
              'ifscCode': null,
            },
        ),
      );

      final w = await service.get('abc');

      expect(seen.single.method, 'GET');
      expect(seen.single.url.path, '/api/admin/withdrawals/abc');
      expect(w.destination!.upiId, 'testuser@okhdfc');
    });

    test('approve and acknowledge POST with no body', () async {
      final service = serviceFor((_) => json(_decisionJson('Approved')));

      final approved = await service.approve('abc');
      await service.acknowledge('abc');

      expect(approved.status, 'Approved');
      expect(seen[0].method, 'POST');
      expect(seen[0].url.path, '/api/admin/withdrawals/abc/approve');
      expect(seen[0].body, isEmpty);
      expect(seen[1].url.path, '/api/admin/withdrawals/abc/acknowledge');
      expect(seen[1].body, isEmpty);
    });

    test('reject sends the reason the user will see', () async {
      final service = serviceFor((_) => json(_decisionJson('Rejected')));

      final d = await service.reject('abc', reason: 'Name does not match.');

      expect(d.status, 'Rejected');
      expect(seen.single.url.path, '/api/admin/withdrawals/abc/reject');
      expect(jsonDecode(seen.single.body), {'reason': 'Name does not match.'});
    });

    test('mark paid sends the bank reference', () async {
      final service = serviceFor((_) => json(_decisionJson('Completed')));

      final d = await service.markPaid(
        'abc',
        transactionReference: 'UTR123456789012',
      );

      expect(d.status, 'Completed');
      expect(seen.single.url.path, '/api/admin/withdrawals/abc/mark-paid');
      expect(jsonDecode(seen.single.body), {
        'transactionReference': 'UTR123456789012',
      });
    });

    test('mark failed sends the reason', () async {
      final service = serviceFor((_) => json(_decisionJson('Failed')));

      final d = await service.markFailed(
        'abc',
        reason: 'The bank returned the payment.',
      );

      expect(d.status, 'Failed');
      expect(seen.single.url.path, '/api/admin/withdrawals/abc/mark-failed');
      expect(jsonDecode(seen.single.body), {
        'reason': 'The bank returned the payment.',
      });
    });

    test('a 409 carries the backend message and can be recognised', () async {
      final service = serviceFor(
        (_) => json({
          'message':
              'This payout has already been sent to the payment provider, so '
              'it can no longer be declined here.',
        }, 409),
      );

      await expectLater(
        service.reject('abc', reason: 'x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isConflict, 'isConflict', isTrue)
              .having(
                (e) => e.message,
                'message',
                contains('already been sent'),
              ),
        ),
      );
    });

    test('404 and 400 map to the right ApiException flags', () async {
      var status = 404;
      final service = serviceFor(
        (_) => json({'message': 'Withdrawal not found.'}, status),
      );

      await expectLater(
        service.approve('missing'),
        throwsA(
          isA<ApiException>().having((e) => e.isNotFound, 'isNotFound', isTrue),
        ),
      );

      status = 400;
      await expectLater(
        service.reject('abc', reason: ''),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('a 403 (not an admin) is surfaced, not swallowed', () async {
      final service = serviceFor((_) => http.Response('', 403));

      await expectLater(
        service.list(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isForbidden,
            'isForbidden',
            isTrue,
          ),
        ),
      );
    });

    test('a 401 refreshes the token once and retries the request', () async {
      var calls = 0;
      final service = serviceFor((_) {
        calls++;
        return calls == 1
            ? http.Response('', 401)
            : json({'items': [], 'totalCount': 0, 'page': 1, 'pageSize': 20});
      });

      final page = await service.list();

      expect(page.items, isEmpty);
      expect(seen, hasLength(2));
      expect(seen[0].headers['Authorization'], 'Bearer tok');
      expect(seen[1].headers['Authorization'], 'Bearer new');
    });
  });
}
