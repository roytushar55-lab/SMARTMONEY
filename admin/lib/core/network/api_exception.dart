/// A user-safe error raised by the networking layer.
///
/// [message] is always safe to show in the UI (no stack traces or raw response
/// bodies). [statusCode] is kept for callers that need to branch on it.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isNotFound => statusCode == 404;

  bool get isUnauthorized => statusCode == 401;

  bool get isForbidden => statusCode == 403;

  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}
