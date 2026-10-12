import 'package:flutter_test/flutter_test.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawal_attention_counter.dart';

import 'withdrawal_test_support.dart';

void main() {
  test('starts unknown and publishes the needs-attention total', () async {
    final server = FakeWithdrawalServer(
      (_) async => jsonResponse(
        withdrawalPage([
          withdrawalRow({'needsAttention': true}),
        ], totalCount: 3),
      ),
    );
    final counter = WithdrawalAttentionCounter(service: server.service);
    addTearDown(counter.dispose);
    var notified = 0;
    counter.addListener(() => notified++);

    expect(counter.value, isNull);

    await counter.refresh();

    expect(counter.value, 3);
    expect(notified, 1);
    // One row is enough: only totalCount is read.
    expect(server.query(0), 'page=1&pageSize=1&needsAttention=true');
  });

  test('a failed refresh keeps the last known count', () async {
    var fail = false;
    final server = FakeWithdrawalServer(
      (_) async => fail
          ? jsonResponse({'message': 'Server error.'}, 500)
          : jsonResponse(withdrawalPage([], totalCount: 2)),
    );
    final counter = WithdrawalAttentionCounter(service: server.service);
    addTearDown(counter.dispose);

    await counter.refresh();
    expect(counter.value, 2);

    fail = true;
    await counter.refresh();
    expect(counter.value, 2);
  });

  test('a failure before the first load leaves it unknown', () async {
    final server = FakeWithdrawalServer(
      (_) async => jsonResponse({'message': 'Server error.'}, 500),
    );
    final counter = WithdrawalAttentionCounter(service: server.service);
    addTearDown(counter.dispose);

    await counter.refresh();

    expect(counter.value, isNull);
  });

  test('an unexpected payload is tolerated too', () async {
    final server = FakeWithdrawalServer((_) async => jsonResponse([1, 2, 3]));
    final counter = WithdrawalAttentionCounter(service: server.service);
    addTearDown(counter.dispose);

    await counter.refresh();

    expect(counter.value, isNull);
  });
}
