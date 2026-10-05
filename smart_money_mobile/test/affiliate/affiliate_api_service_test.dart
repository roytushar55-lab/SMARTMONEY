import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_money_mobile/core/network/api_exception.dart';
import 'package:smart_money_mobile/features/affiliate/data/services/affiliate_api_service.dart';
import 'package:smart_money_mobile/features/auth/data/services/auth_api_service.dart';
import 'package:smart_money_mobile/features/auth/data/services/token_storage_service.dart';

const String _base = 'http://test.local';
const String _storeId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const String _offerId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

const Map<String, dynamic> _clickBody = {
  'clickId': 'c1',
  'redirectToken': 'token-1',
  'redirectPath': '/r/token-1',
};

/// In-memory [TokenStorageService] double; no secure storage / prefs plugins.
class _FakeTokenStorage implements TokenStorageService {
  _FakeTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
  bool savedTokens = false;
  bool clearedTokens = false;

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
    savedTokens = true;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    clearedTokens = true;
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  group('AffiliateApiService.createClick', () {
    test('posts storeId only and parses the response', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(_clickBody),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = AffiliateApiService(
        client: client,
        tokenStorageService: _FakeTokenStorage(accessToken: 'access-1'),
        baseUrl: _base,
      );

      final click = await service.createClick(storeId: _storeId);

      expect(captured, isNotNull);
      expect(captured!.url.toString(), '$_base/api/affiliate/clicks');
      expect(captured!.method, 'POST');
      expect(captured!.headers['Authorization'], 'Bearer access-1');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['storeId'], _storeId);
      expect(body.containsKey('offerId'), isFalse);

      expect(click.clickId, 'c1');
      expect(click.redirectToken, 'token-1');
      expect(click.redirectPath, '/r/token-1');
    });

    test('includes offerId when provided', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_clickBody), 200);
      });
      final service = AffiliateApiService(
        client: client,
        tokenStorageService: _FakeTokenStorage(accessToken: 'access-1'),
        baseUrl: _base,
      );

      await service.createClick(storeId: _storeId, offerId: _offerId);

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['storeId'], _storeId);
      expect(body['offerId'], _offerId);
    });

    test('maps 404 to a not-found ApiException', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Cashback is not available for this store or offer.'}),
          404,
        );
      });
      final service = AffiliateApiService(
        client: client,
        tokenStorageService: _FakeTokenStorage(accessToken: 'access-1'),
        baseUrl: _base,
      );

      expect(
        () => service.createClick(storeId: _storeId),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNotFound, 'isNotFound', true)
              .having(
                (e) => e.message,
                'message',
                'Cashback is not available for this store or offer.',
              ),
        ),
      );
    });

    test('refreshes the token and retries once after a 401', () async {
      final storage = _FakeTokenStorage(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
      var clickCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/identity/refresh-token') {
          return http.Response(
            jsonEncode({
              'accessToken': 'access-2',
              'refreshToken': 'refresh-2',
              'accessTokenExpiresAt': '2026-01-01T00:00:00Z',
            }),
            200,
          );
        }

        clickCalls += 1;
        if (request.headers['Authorization'] == 'Bearer access-2') {
          return http.Response(jsonEncode(_clickBody), 200);
        }
        return http.Response('', 401);
      });
      final service = AffiliateApiService(
        client: client,
        tokenStorageService: storage,
        authApiService: AuthApiService(client: client, baseUrl: _base),
        baseUrl: _base,
      );

      final click = await service.createClick(storeId: _storeId);

      expect(clickCalls, 2);
      expect(storage.savedTokens, isTrue);
      expect(storage.accessToken, 'access-2');
      expect(click.clickId, 'c1');
    });

    test('throws a session-expired error when the refresh fails', () async {
      final storage = _FakeTokenStorage(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
      final client = MockClient((request) async {
        if (request.url.path == '/api/identity/refresh-token') {
          return http.Response(jsonEncode({'message': 'invalid'}), 401);
        }
        return http.Response('', 401);
      });
      final service = AffiliateApiService(
        client: client,
        tokenStorageService: storage,
        authApiService: AuthApiService(client: client, baseUrl: _base),
        baseUrl: _base,
      );

      await expectLater(
        () => service.createClick(storeId: _storeId),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isUnauthorized, 'isUnauthorized', true)
              .having(
                (e) => e.message,
                'message',
                'Your session has expired. Please sign in again.',
              ),
        ),
      );
      expect(storage.clearedTokens, isTrue);
    });

    test('throws a sign-in error without calling the network when no token is stored', () async {
      var networkCalled = false;
      final client = MockClient((request) async {
        networkCalled = true;
        return http.Response(jsonEncode(_clickBody), 200);
      });
      final service = AffiliateApiService(
        client: client,
        tokenStorageService: _FakeTokenStorage(),
        baseUrl: _base,
      );

      await expectLater(
        () => service.createClick(storeId: _storeId),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isUnauthorized, 'isUnauthorized', true)
              .having((e) => e.message, 'message', 'Sign in to earn cashback.'),
        ),
      );
      expect(networkCalled, isFalse);
    });

    test('maps a ClientException to the unable-to-reach message', () async {
      final client = MockClient((request) async {
        throw http.ClientException('connection refused');
      });
      final service = AffiliateApiService(
        client: client,
        tokenStorageService: _FakeTokenStorage(accessToken: 'access-1'),
        baseUrl: _base,
      );

      expect(
        () => service.createClick(storeId: _storeId),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            "Can't reach SmartMoney. Check your connection and try again.",
          ),
        ),
      );
    });
  });
}
