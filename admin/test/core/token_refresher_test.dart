import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/api_exception.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';

import 'fakes.dart';

RefreshTokenResponse _tokens(String access, String refresh) =>
    RefreshTokenResponse(
      accessToken: access,
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: refresh,
    );

void main() {
  late FakeTokenStorage storage;
  late FakeAuthApi api;
  late TokenRefresher refresher;
  late int expiredCount;
  late List<String> refreshedTokens;

  void build(Future<RefreshTokenResponse> Function(String) onRefresh) {
    storage = FakeTokenStorage(accessToken: 'old', refreshToken: 'r1');
    api = FakeAuthApi(onRefresh);
    expiredCount = 0;
    refreshedTokens = [];
    refresher = TokenRefresher(
      tokenStorage: storage,
      authApi: api,
      onSessionExpired: () => expiredCount++,
      onTokensRefreshed: refreshedTokens.add,
    );
  }

  AuthorizedApiClient clientFor(
    http.Client httpClient, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return AuthorizedApiClient(
      client: httpClient,
      tokenStorageService: storage,
      refresher: refresher,
      baseUrl: 'https://example.test',
      timeout: timeout,
    );
  }

  test('concurrent refresh callers share one request', () async {
    final gate = Completer<RefreshTokenResponse>();
    build((_) => gate.future);

    final results = Future.wait([
      refresher.refresh(),
      refresher.refresh(),
      refresher.refresh(),
    ]);
    await Future<void>.delayed(Duration.zero);
    gate.complete(_tokens('new', 'r2'));

    expect(await results, everyElement(RefreshResult.refreshed));
    expect(api.refreshCalls, 1);
    expect(storage.accessToken, 'new');
    expect(storage.refreshToken, 'r2');
    expect(refreshedTokens, ['new']);
    expect(expiredCount, 0);
  });

  for (final status in [400, 401, 403]) {
    test('HTTP $status on refresh logs out and clears tokens', () async {
      build((_) async => throw ApiException('no', statusCode: status));

      expect(await refresher.refresh(), RefreshResult.sessionExpired);
      expect(expiredCount, 1);
      expect(storage.clearCount, 1);
      expect(storage.accessToken, isNull);
    });
  }

  for (final error in <Object>[
    const ApiException('down'),
    const ApiException('boom', statusCode: 500),
    const ApiException('bad gateway', statusCode: 502),
    TimeoutException('slow'),
  ]) {
    test('transient failure ($error) keeps tokens and session', () async {
      build((_) async => throw error);

      expect(await refresher.refresh(), RefreshResult.unavailable);
      expect(expiredCount, 0);
      expect(storage.clearCount, 0);
      expect(storage.accessToken, 'old');
      expect(storage.refreshToken, 'r1');
    });
  }

  test('missing refresh token is a definitive logout', () async {
    build((_) async => _tokens('a', 'b'));
    storage.refreshToken = null;

    expect(await refresher.refresh(), RefreshResult.sessionExpired);
    expect(expiredCount, 1);
    expect(api.refreshCalls, 0);
  });

  test('concurrent 401s through the client trigger one refresh', () async {
    final gate = Completer<RefreshTokenResponse>();
    build((_) => gate.future);

    final seenAuth = <String>[];
    final client = clientFor(
      MockClient((request) async {
        final auth = request.headers['Authorization']!;
        seenAuth.add(auth);
        if (auth == 'Bearer old') return http.Response('{}', 401);
        return http.Response('{"ok":true}', 200);
      }),
    );

    final calls = Future.wait([
      client.getJson('/a'),
      client.getJson('/b'),
      client.getJson('/c'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    gate.complete(_tokens('new', 'r2'));

    final results = await calls;
    expect(results, everyElement({'ok': true}));
    expect(api.refreshCalls, 1);
    expect(seenAuth.where((a) => a == 'Bearer new'), hasLength(3));
  });

  test('client maps transport errors to a friendly ApiException', () async {
    build((_) async => _tokens('a', 'b'));
    final client = clientFor(
      MockClient((_) async => throw http.ClientException('socket x')),
    );

    await expectLater(
      client.getJson('/a'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains("Can't reach the server"), isNot(contains('socket'))),
        ),
      ),
    );
  });

  test('client times out instead of hanging', () async {
    build((_) async => _tokens('a', 'b'));
    final client = clientFor(
      MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(client.getJson('/a'), throwsA(isA<ApiException>()));
  });

  test('client does not log out when refresh is only unreachable', () async {
    build((_) async => throw const ApiException('down'));
    final client = clientFor(MockClient((_) async => http.Response('{}', 401)));

    await expectLater(client.getJson('/a'), throwsA(isA<ApiException>()));
    expect(expiredCount, 0);
    expect(storage.refreshToken, 'r1');
  });
}
