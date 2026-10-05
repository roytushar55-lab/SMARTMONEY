import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Default timeout applied to every HTTP call made by the API services.
const Duration kApiTimeout = Duration(seconds: 20);

/// User-safe message for any failure to reach the backend.
const String kNetworkErrorMessage =
    "Can't reach SmartMoney. Check your connection and try again.";

/// Runs [action] with a timeout and converts transport-level failures
/// (timeout, socket, client errors) into an [ApiException] with a friendly
/// message. [ApiException]s thrown by [action] pass through unchanged.
Future<T> guardNetwork<T>(
  Future<T> Function() action, {
  Duration timeout = kApiTimeout,
}) async {
  try {
    return await action().timeout(timeout);
  } on ApiException {
    rethrow;
  } on TimeoutException {
    throw const ApiException(kNetworkErrorMessage);
  } on SocketException {
    throw const ApiException(kNetworkErrorMessage);
  } on http.ClientException {
    throw const ApiException(kNetworkErrorMessage);
  }
}
