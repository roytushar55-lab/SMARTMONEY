import 'package:flutter_test/flutter_test.dart';
import 'package:smartmoney_admin/core/auth/admin_session.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/api_exception.dart';

import 'fakes.dart';

void main() {
  final now = DateTime.utc(2030, 1, 1, 12);
  final future = now.add(const Duration(hours: 1));
  final past = now.subtract(const Duration(hours: 1));

  late FakeTokenStorage storage;
  late FakeAuthApi api;
  late TokenRefresher refresher;
  late AdminSession session;

  void build({
    required String? access,
    String? refresh = 'r1',
    Future<RefreshTokenResponse> Function(String)? onRefresh,
  }) {
    storage = FakeTokenStorage(accessToken: access, refreshToken: refresh);
    api = FakeAuthApi(
      onRefresh ?? (_) async => throw const ApiException('x', statusCode: 401),
    );
    refresher = TokenRefresher(tokenStorage: storage, authApi: api);
    session = AdminSession(
      tokenStorage: storage,
      authApi: api,
      refresher: refresher,
      now: () => now,
    );
  }

  RefreshTokenResponse tokens(String role) => RefreshTokenResponse(
    accessToken: fakeJwt(role: role, expiresAt: future),
    accessTokenExpiresAt: future,
    refreshToken: 'r2',
  );

  test('restores a fresh admin token', () async {
    build(access: fakeJwt(role: 'Admin', expiresAt: future));
    await session.restore();
    expect(session.claims.value?.role, 'Admin');
    expect(api.refreshCalls, 0);
  });

  test('rejects and clears a non-admin token', () async {
    build(access: fakeJwt(role: 'Customer', expiresAt: future));
    await session.restore();
    expect(session.claims.value, isNull);
    expect(storage.accessToken, isNull);
  });

  test('rejects a token with no role', () async {
    build(access: fakeJwt(expiresAt: future));
    await session.restore();
    expect(session.claims.value, isNull);
    expect(storage.accessToken, isNull);
  });

  test('rejects garbage tokens', () async {
    build(access: 'not-a-jwt');
    await session.restore();
    expect(session.claims.value, isNull);
    expect(storage.accessToken, isNull);
  });

  test('expired token with rejected refresh requires login', () async {
    build(access: fakeJwt(role: 'Admin', expiresAt: past));
    await session.restore();
    expect(session.claims.value, isNull);
    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });

  test('expired token without refresh token requires login', () async {
    build(access: fakeJwt(role: 'Admin', expiresAt: past), refresh: null);
    await session.restore();
    expect(session.claims.value, isNull);
    expect(storage.accessToken, isNull);
  });

  test('expired token is restored through a successful refresh', () async {
    build(
      access: fakeJwt(role: 'Admin', expiresAt: past),
      onRefresh: (_) async => tokens('SuperAdmin'),
    );
    await session.restore();
    expect(session.claims.value?.isSuperAdmin, isTrue);
    expect(api.refreshCalls, 1);
  });

  test('refresh that returns a non-admin token logs the admin out', () async {
    build(
      access: fakeJwt(role: 'Admin', expiresAt: past),
      onRefresh: (_) async => tokens('Customer'),
    );
    await session.restore();
    expect(session.claims.value, isNull);
    expect(storage.accessToken, isNull);
  });

  test('transient refresh failure on restore keeps stored tokens', () async {
    build(
      access: fakeJwt(role: 'Admin', expiresAt: past),
      onRefresh: (_) async => throw const ApiException('down'),
    );
    await session.restore();
    expect(session.claims.value, isNull);
    expect(storage.refreshToken, 'r1');
  });

  test('claims are re-read after refresh so a demotion applies', () async {
    var role = 'SuperAdmin';
    build(
      access: fakeJwt(role: 'SuperAdmin', expiresAt: future),
      onRefresh: (_) async => tokens(role),
    );
    await session.restore();
    expect(session.claims.value?.isSuperAdmin, isTrue);

    role = 'Admin';
    expect(await refresher.refresh(), RefreshResult.refreshed);
    expect(session.claims.value?.role, 'Admin');
    expect(session.claims.value?.isSuperAdmin, isFalse);
  });

  test('definitive refresh failure resets the session claims', () async {
    build(
      access: fakeJwt(role: 'Admin', expiresAt: future),
      onRefresh: (_) async => throw const ApiException('no', statusCode: 401),
    );
    await session.restore();
    expect(session.claims.value, isNotNull);

    expect(await refresher.refresh(), RefreshResult.sessionExpired);
    expect(session.claims.value, isNull);
  });
}
