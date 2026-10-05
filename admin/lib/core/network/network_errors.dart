import 'dart:async';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Default timeout applied to every HTTP call.
const Duration apiTimeout = Duration(seconds: 20);

const String networkErrorMessage =
    "Can't reach the server. Check your connection and try again.";
const String timeoutErrorMessage =
    'The server took too long to respond. Please try again.';
const String badResponseMessage =
    'The server sent an unexpected response. Please try again.';

/// Runs [action] with [apiTimeout], converting transport-level failures into
/// a user-safe [ApiException] (no raw exception text ever reaches the UI).
Future<T> guardNetwork<T>(
  Future<T> Function() action, {
  Duration timeout = apiTimeout,
}) async {
  try {
    return await action().timeout(timeout);
  } on ApiException {
    rethrow;
  } on TimeoutException {
    throw const ApiException(timeoutErrorMessage);
  } on http.ClientException {
    throw const ApiException(networkErrorMessage);
  } on FormatException {
    throw const ApiException(badResponseMessage);
  } catch (_) {
    throw const ApiException(networkErrorMessage);
  }
}

/// Text that is safe to show for any caught error.
String safeErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
