import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/google_auth_config.dart';

/// Thrown when Google sign-in can't produce a usable identity: no client ID
/// configured for this platform, or Google returned success without an ID
/// token.
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fronts SmartMoney's Google authentication so the login UI never talks to
/// the OAuth SDK directly.
///
/// This only obtains a Google identity and its ID token on the client. The
/// caller must send that token to the backend
/// (`AuthApiService.loginWithGoogle`), which verifies it server-side before
/// issuing a SmartMoney session — a client-supplied Google identity is never
/// trusted on its own.
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            clientId: kIsWeb && GoogleAuthConfig.webClientId.isNotEmpty
                ? GoogleAuthConfig.webClientId
                : null,
            scopes: const ['email'],
          );

  final GoogleSignIn _googleSignIn;

  /// Runs the interactive Google sign-in flow and returns an ID token ready
  /// to be verified by the backend. Returns `null` if the user cancelled the
  /// flow instead of throwing, so callers can treat cancellation as a no-op.
  Future<String?> signInAndGetIdToken() async {
    if (kIsWeb && GoogleAuthConfig.webClientId.isEmpty) {
      throw const GoogleAuthException("Google sign-in isn't configured yet.");
    }

    final account = await _googleSignIn.signIn();
    if (account == null) {
      return null;
    }

    final authentication = await account.authentication;
    final idToken = authentication.idToken;

    if (idToken == null) {
      throw const GoogleAuthException(
        "Google sign-in couldn't be completed. Please try again.",
      );
    }

    return idToken;
  }
}
