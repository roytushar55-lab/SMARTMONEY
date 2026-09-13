import 'dart:convert';

/// Reads claims out of a JWT's payload segment without verifying the
/// signature — the backend is the source of truth for validity; this is only
/// used client-side to decide which screens to show (role-gating, display
/// name), never as an authorization decision.
class JwtClaims {
  const JwtClaims._(this._claims);

  final Map<String, dynamic> _claims;

  static const _roleClaimUri =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
  static const _emailClaimUri =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress';
  static const _nameClaimUri =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';

  static JwtClaims? tryParse(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);

      if (decoded is! Map<String, dynamic>) return null;

      return JwtClaims._(decoded);
    } catch (_) {
      return null;
    }
  }

  String? get userId => _claims['sub'] as String?;

  String? get role =>
      _claims[_roleClaimUri] as String? ?? _claims['role'] as String?;

  String? get email =>
      _claims[_emailClaimUri] as String? ?? _claims['email'] as String?;

  String? get name => _claims[_nameClaimUri] as String?;

  bool get isAdminOrAbove => role == 'Admin' || role == 'SuperAdmin';

  bool get isSuperAdmin => role == 'SuperAdmin';
}
