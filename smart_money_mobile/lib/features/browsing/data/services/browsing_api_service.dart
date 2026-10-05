import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_guard.dart';
import '../models/category.dart';
import '../models/offer_details.dart';
import '../models/offer_list_item.dart';
import '../models/search_result.dart';
import '../models/store_details.dart';
import '../models/store_list_item.dart';

/// Talks to the PUBLIC browsing endpoints (no JWT required).
///
/// Mirrors the existing [AuthApiService] pattern: a plain [http.Client], a
/// [baseUrl] with the same default as the other services, non-2xx responses
/// surfaced as exceptions. All failures are normalized to [ApiException] with
/// a user-safe message so screens never render raw exception text.
class BrowsingApiService {
  BrowsingApiService({
    http.Client? client,
    this.baseUrl = ApiConfig.baseUrl,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _timeout = timeout ?? kApiTimeout;

  final http.Client _client;
  final String baseUrl;
  final Duration _timeout;

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
  };

  // GET /api/categories
  Future<List<Category>> getCategories() async {
    final body = await _getJson(Uri.parse('$baseUrl/api/categories'));
    return _mapList(body, Category.fromJson);
  }

  // GET /api/categories/{slug}/stores
  Future<List<StoreListItem>> getStoresByCategory(String categorySlug) async {
    final uri = Uri.parse(
      '$baseUrl/api/categories/${Uri.encodeComponent(categorySlug)}/stores',
    );
    final body = await _getJson(uri);
    return _mapList(body, StoreListItem.fromJson);
  }

  // GET /api/stores
  Future<List<StoreListItem>> getStores() async {
    final body = await _getJson(Uri.parse('$baseUrl/api/stores'));
    return _mapList(body, StoreListItem.fromJson);
  }

  // GET /api/stores/{slug}
  Future<StoreDetails> getStoreDetails(String storeSlug) async {
    final uri = Uri.parse(
      '$baseUrl/api/stores/${Uri.encodeComponent(storeSlug)}',
    );
    final body = await _getJson(uri, notFoundMessage: 'Store not found.');
    return StoreDetails.fromJson(_asMap(body));
  }

  // GET /api/stores/{slug}/offers
  Future<List<OfferListItem>> getStoreOffers(String storeSlug) async {
    final uri = Uri.parse(
      '$baseUrl/api/stores/${Uri.encodeComponent(storeSlug)}/offers',
    );
    final body = await _getJson(uri);
    return _mapList(body, OfferListItem.fromJson);
  }

  // GET /api/offers
  Future<List<OfferListItem>> getOffers() async {
    final body = await _getJson(Uri.parse('$baseUrl/api/offers'));
    return _mapList(body, OfferListItem.fromJson);
  }

  // GET /api/offers/{slug}
  Future<OfferDetails> getOfferDetails(String offerSlug) async {
    final uri = Uri.parse(
      '$baseUrl/api/offers/${Uri.encodeComponent(offerSlug)}',
    );
    final body = await _getJson(uri, notFoundMessage: 'Offer not found.');
    return OfferDetails.fromJson(_asMap(body));
  }

  // GET /api/search?q={query}
  //
  // The backend returns 400 for an empty/whitespace query, so we never send the
  // request in that case and simply return an empty result set.
  Future<SearchResult> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const SearchResult(stores: [], offers: []);
    }

    final uri = Uri.parse(
      '$baseUrl/api/search',
    ).replace(queryParameters: {'q': trimmed});
    final body = await _getJson(uri);
    return SearchResult.fromJson(_asMap(body));
  }

  Future<dynamic> _getJson(Uri uri, {String? notFoundMessage}) async {
    final http.Response response = await guardNetwork(
      () => _client.get(uri, headers: _jsonHeaders),
      timeout: _timeout,
    );

    final status = response.statusCode;

    if (status == 404 && notFoundMessage != null) {
      throw ApiException(notFoundMessage, statusCode: 404);
    }

    if (status < 200 || status >= 300) {
      throw ApiException(
        'The server responded with an error. Please try again shortly.',
        statusCode: status,
      );
    }

    if (response.body.isEmpty) {
      throw const ApiException('The server returned an empty response.');
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException(
        'Received an unexpected response from the server.',
      );
    }
  }

  List<T> _mapList<T>(dynamic body, T Function(Map<String, dynamic>) fromJson) {
    if (body is! List) {
      throw const ApiException(
        'Received an unexpected response from the server.',
      );
    }
    return body.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is! Map<String, dynamic>) {
      throw const ApiException(
        'Received an unexpected response from the server.',
      );
    }
    return body;
  }

  void dispose() {
    _client.close();
  }
}
