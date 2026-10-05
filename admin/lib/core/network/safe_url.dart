import 'package:flutter/foundation.dart';

/// Accepts a URL returned by the API (or typed into a form) only when it is
/// safe to store or load as an image: absolute `https`, or plain `http` for
/// localhost in debug builds. Returns the trimmed URL, or null if rejected.
String? safeMediaUrl(String? value, {bool? allowLocalHttp}) {
  if (value == null) return null;

  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return trimmed;

  final allowHttp = allowLocalHttp ?? kDebugMode;
  final isLocal =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '[::1]';
  if (scheme == 'http' && allowHttp && isLocal) return trimmed;

  return null;
}
