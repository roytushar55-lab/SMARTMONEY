import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/core/network/api_exception.dart';
import 'package:smart_money_mobile/core/network/token_refresher.dart';
import 'package:smart_money_mobile/features/auth/data/models/refresh_token_response.dart';
import 'package:smart_money_mobile/features/auth/data/services/token_storage_service.dart';

/// In-memory [TokenStorageService] double; no secure storage / prefs plugins.
class _FakeTokenStorage implements TokenStorageService {
  _FakeTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<DateTime?> getAccessTokenExpiresAt() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
  }) async {
    saveCount++;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    clearCount++;
    accessToken = null;
    refreshToken = null;
  }
}

RefreshTokenResponse _response() => RefreshTokenResponse(
  accessToken: 'access-2',
  accessTokenExpiresAt: DateTime.utc(2030),
  refreshToken: 'refresh-2',
);

void main() {
  test('concurrent callers trigger exactly one refresh request', () async {
    final storage = _FakeTokenStorage(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    final gate = Completer<RefreshTokenResponse>();
    var calls = 0;

    Future<RefreshTokenResponse> request(String token) {
      calls++;
      expect(token, 'refresh-1');
      return gate.future;
    }

    final results = Future.wait([
      for (var i = 0; i < 5; i++)
        TokenRefresher.refreshWith(
          tokenStorage: storage,
          requestRefresh: request,
        ),
    ]);

    await Future<void>.delayed(Duration.zero);
    gate.complete(_response());

    expect(await results, everyElement(RefreshOutcome.refreshed));
    expect(calls, 1);
    expect(storage.saveCount, 1);
    expect(storage.accessToken, 'access-2');

    // A later refresh starts a new request once the first has finished.
    await TokenRefresher.refreshWith(
      tokenStorage: storage,
      requestRefresh: (_) async {
        calls++;
        return _response();
      },
    );
    expect(calls, 2);
  });

  for (final status in [400, 401, 403]) {
    test('HTTP $status clears tokens and reports rejection', () async {
      final storage = _FakeTokenStorage(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      final outcome = await TokenRefresher.refreshWith(
        tokenStorage: storage,
        requestRefresh: (_) async =>
            throw ApiException('nope', statusCode: status),
      );

      expect(outcome, RefreshOutcome.rejected);
      expect(storage.clearCount, 1);
      expect(storage.refreshToken, isNull);
    });
  }

  test('network error, timeout and 5xx keep tokens', () async {
    final failures = <Object>[
      const ApiException("Can't reach SmartMoney."),
      const ApiException('boom', statusCode: 500),
      const ApiException('bad gateway', statusCode: 502),
      TimeoutException('slow'),
      const FormatException('garbled'),
    ];

    for (final failure in failures) {
      final storage = _FakeTokenStorage(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      final outcome = await TokenRefresher.refreshWith(
        tokenStorage: storage,
        requestRefresh: (_) async => throw failure,
      );

      expect(outcome, RefreshOutcome.transientFailure, reason: '$failure');
      expect(storage.clearCount, 0);
      expect(storage.refreshToken, 'refresh-1');
    }
  });

  test('missing refresh token is a rejection without a request', () async {
    final storage = _FakeTokenStorage();
    var calls = 0;

    final outcome = await TokenRefresher.refreshWith(
      tokenStorage: storage,
      requestRefresh: (_) async {
        calls++;
        return _response();
      },
    );

    expect(outcome, RefreshOutcome.rejected);
    expect(calls, 0);
  });
}
