import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/core/network/api_exception.dart';
import 'package:smart_money_mobile/features/withdrawals/data/models/withdrawal_page.dart';
import 'package:smart_money_mobile/features/withdrawals/data/services/withdrawal_api_service.dart';

import 'withdrawal_test_support.dart';

void main() {
  group('preview', () {
    test('asks for the amount and reads the quote', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(previewJson(amount: 500, userFee: 5.9)),
      );

      final preview = await server.service.preview(500);

      expect(server.seen.single.url.path, '/api/withdrawals/preview');
      expect(server.seen.single.url.query, 'amount=500');
      expect(preview.amount, 500);
      expect(preview.userFee, 5.9);
      expect(preview.netAmount, 494.1);
      expect(preview.canWithdraw, isTrue);
      expect(preview.message, isNull);
      expect(preview.minimumAmount, 250);
      expect(preview.availableBalance, 800);
    });

    test('keeps the paise and drops a trailing .00', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(previewJson(amount: 250.5)),
      );

      await server.service.preview(250.5);
      await server.service.preview(0);
      await server.service.preview(1000);

      expect(server.seen[0].url.query, 'amount=250.5');
      expect(server.seen[1].url.query, 'amount=0');
      expect(server.seen[2].url.query, 'amount=1000');
    });

    test('a refusal is an answer, not an error', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(
          previewJson(
            amount: 100,
            canWithdraw: false,
            message: 'The minimum withdrawal is ₹250.',
          ),
        ),
      );

      final preview = await server.service.preview(100);

      expect(preview.canWithdraw, isFalse);
      expect(preview.message, 'The minimum withdrawal is ₹250.');
    });
  });

  group('request', () {
    test('sends every field and reads the new withdrawal', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(withdrawalJson(amount: 500), 201),
      );

      final withdrawal = await server.service.request(
        amount: 500,
        method: PayoutMethod.upi,
        beneficiaryName: 'Withdraw Test User',
        upiId: 'testuser@okhdfc',
        password: 'secret',
      );

      final request = server.seen.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/withdrawals');
      expect(jsonDecode(request.body), {
        'amount': 500,
        'method': 'Upi',
        'beneficiaryName': 'Withdraw Test User',
        'upiId': 'testuser@okhdfc',
        'bankAccountNumber': null,
        'ifscCode': null,
        'password': 'secret',
      });
      expect(withdrawal.id, '11111111-1111-1111-1111-111111111111');
      expect(withdrawal.reference, 'WD20261011K7QM2XA9PD');
      expect(withdrawal.status, 'Requested');
      expect(withdrawal.canCancel, isTrue);
      expect(withdrawal.destination, 'te****@okhdfc');
      expect(withdrawal.settledAt, isNull);
    });

    test('a bank transfer sends the account and IFSC instead', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(withdrawalJson(), 201),
      );

      await server.service.request(
        amount: 500,
        method: PayoutMethod.bankTransfer,
        beneficiaryName: 'Withdraw Test User',
        bankAccountNumber: '123456789012',
        ifscCode: 'HDFC0001234',
        password: 'secret',
      );

      final body = jsonDecode(server.seen.single.body) as Map<String, dynamic>;
      expect(body['method'], 'BankTransfer');
      expect(body['upiId'], isNull);
      expect(body['bankAccountNumber'], '123456789012');
      expect(body['ifscCode'], 'HDFC0001234');
    });

    test("a refusal carries the server's own words and status", () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse({'message': 'Incorrect password.'}, 400),
      );

      expect(
        () => server.service.request(
          amount: 500,
          method: PayoutMethod.upi,
          beneficiaryName: 'Withdraw Test User',
          upiId: 'testuser@okhdfc',
          password: 'wrong',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Incorrect password.')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('a conflict is a 409 with its message (request)', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse({
          'message': 'You already have a withdrawal in progress.',
        }, 409),
      );

      expect(
        () => server.service.request(
          amount: 500,
          method: PayoutMethod.upi,
          beneficiaryName: 'Withdraw Test User',
          upiId: 'testuser@okhdfc',
          password: 'secret',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                'You already have a withdrawal in progress.',
              ),
        ),
      );
    });
  });

  group('history', () {
    test('list asks for a page and reads it', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(
          pageJson(
            [
              withdrawalJson(id: 'a'),
              withdrawalJson(id: 'b', status: 'Completed'),
            ],
            totalCount: 45,
            page: 2,
          ),
        ),
      );

      final page = await server.service.list(page: 2);

      expect(server.seen.single.url.path, '/api/withdrawals');
      expect(server.seen.single.url.query, 'page=2&pageSize=20');
      expect(page.items.map((w) => w.id), ['a', 'b']);
      expect(page.totalCount, 45);
      expect(page.page, 2);
      expect(page.hasNextPage, isTrue);
    });

    test('the last page has no next page', () {
      final page = WithdrawalPage.fromJson(
        pageJson([withdrawalJson()], totalCount: 21, page: 2),
      );

      expect(page.hasNextPage, isFalse);
    });

    test('get reads one withdrawal', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(
          withdrawalJson(id: 'a', status: 'Failed', failureReason: 'Bounced.'),
        ),
      );

      final withdrawal = await server.service.get('a');

      expect(server.seen.single.url.path, '/api/withdrawals/a');
      expect(withdrawal.status, 'Failed');
      expect(withdrawal.failureReason, 'Bounced.');
      expect(withdrawal.canCancel, isFalse);
    });

    test('cancel posts and reads the balances after', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse(decisionJson(available: 1300)),
      );

      final decision = await server.service.cancel('a');

      expect(server.seen.single.method, 'POST');
      expect(server.seen.single.url.path, '/api/withdrawals/a/cancel');
      expect(decision.status, 'Cancelled');
      expect(decision.availableBalance, 1300);
      expect(decision.heldBalance, 0);
    });

    test('cancelling too late is a 409 with the server message', () async {
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse({
          'message':
              'A withdrawal can only be cancelled before it is approved.',
        }, 409),
      );

      expect(
        () => server.service.cancel('a'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                'A withdrawal can only be cancelled before it is approved.',
              ),
        ),
      );
    });
  });
}
