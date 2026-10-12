import 'package:flutter_test/flutter_test.dart';
import 'package:smartmoney_admin/features/withdrawals/models/admin_withdrawal.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawal_actions.dart';

import 'withdrawal_test_support.dart';

WithdrawalActions _actions([Map<String, dynamic>? overrides]) =>
    WithdrawalActions.of(AdminWithdrawal.fromJson(withdrawalRow(overrides)));

/// A payout the provider has been asked to pay, and has not given up on.
const _withProvider = {
  'submittedAt': '2026-10-11T12:31:01Z',
  'submissionAttempts': 1,
  'providerName': 'Fake',
};

void main() {
  group('a new request', () {
    final a = _actions();

    test('can be approved, declined or marked paid straight away', () {
      expect(a.approve, isTrue);
      expect(a.decline, isTrue);
      expect(a.markPaid, isTrue);
    });

    test('cannot be marked failed (nothing was attempted) or acknowledged', () {
      expect(a.markFailed, isFalse);
      expect(a.acknowledge, isFalse);
      expect(a.providerOwns, isFalse);
    });
  });

  group('approved, nobody has tried to send it (the manual flow)', () {
    final a = _actions({'status': 'Approved'});

    test('can be paid, failed or declined, but not approved again', () {
      expect(a.approve, isFalse);
      expect(a.markPaid, isTrue);
      expect(a.markFailed, isTrue);
      expect(a.decline, isTrue);
      expect(a.providerOwns, isFalse);
    });
  });

  group('the provider owns it', () {
    test('an approved payout the provider is retrying is hands off', () {
      final a = _actions({'status': 'Approved', ..._withProvider});

      expect(a.providerOwns, isTrue);
      expect(a.decline, isFalse);
      expect(a.markPaid, isFalse);
      expect(a.markFailed, isFalse);
      expect(a.approve, isFalse);
      expect(a.any, isFalse);
    });

    test(
      'a timed-out first attempt counts: it may have reached the provider',
      () {
        final a = _actions({
          'status': 'Approved',
          'submissionAttempts': 1,
          'submittedAt': null,
        });

        expect(a.providerOwns, isTrue);
        expect(a.decline, isFalse);
      },
    );

    test('a started send with no recorded attempt count still counts', () {
      final a = _actions({
        'status': 'Approved',
        'submittedAt': '2026-10-11T12:31:01Z',
        'submissionAttempts': 0,
      });

      expect(a.providerOwns, isTrue);
    });

    test('a payout in flight is hands off', () {
      final a = _actions({'status': 'Processing', ..._withProvider});

      expect(a.providerOwns, isTrue);
      expect(a.any, isFalse);
    });

    test('a Processing withdrawal can never be declined', () {
      final a = _actions({
        'status': 'Processing',
        ..._withProvider,
        'needsAttention': true,
      });

      expect(a.decline, isFalse);
    });
  });

  group('a person may step in once it needs attention', () {
    test('an approved payout whose retries ran out', () {
      final a = _actions({
        'status': 'Approved',
        ..._withProvider,
        'submissionAttempts': 5,
        'needsAttention': true,
      });

      expect(a.providerOwns, isFalse);
      expect(a.decline, isTrue);
      expect(a.markPaid, isTrue);
      expect(a.markFailed, isTrue);
      expect(a.acknowledge, isTrue);
      expect(a.approve, isFalse);
    });

    test('a payout in flight that the provider does not recognise', () {
      final a = _actions({
        'status': 'Processing',
        ..._withProvider,
        'needsAttention': true,
      });

      expect(a.providerOwns, isFalse);
      expect(a.markPaid, isTrue);
      expect(a.markFailed, isTrue);
      expect(a.acknowledge, isTrue);
    });

    test(
      'a request flagged before anything was sent keeps its own actions',
      () {
        final a = _actions({'needsAttention': true});

        expect(a.approve, isTrue);
        expect(a.acknowledge, isTrue);
      },
    );
  });

  group('finished withdrawals', () {
    for (final status in ['Completed', 'Failed', 'Rejected', 'Cancelled']) {
      test('$status offers nothing, and is never "owned" by the provider', () {
        final a = _actions({
          'status': status,
          ..._withProvider,
          'settledAt': '2026-10-11T12:40:00Z',
        });

        expect(a.any, isFalse, reason: status);
        expect(a.providerOwns, isFalse, reason: status);
      });
    }

    test('only a flag can be acknowledged on a finished one', () {
      final a = _actions({
        'status': 'Failed',
        'needsAttention': true,
        'settledAt': '2026-10-11T12:40:00Z',
      });

      expect(a.acknowledge, isTrue);
      expect(a.decline, isFalse);
      expect(a.markPaid, isFalse);
      expect(a.markFailed, isFalse);
      expect(a.approve, isFalse);
    });
  });

  test('an unknown status offers nothing', () {
    expect(_actions({'status': 'SomethingNew'}).any, isFalse);
  });
}
