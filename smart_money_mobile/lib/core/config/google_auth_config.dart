/// OAuth Client ID from Google Cloud Console (APIs & Services > Credentials)
/// used to initialize Google Sign-In on Flutter Web.
///
/// Native Android/iOS builds instead read their client ID from
/// `google-services.json` / `GoogleService-Info.plist` once those are added
/// for this project, so this value only gates the web flow. Pass it at build
/// time so no client ID needs to be hardcoded in source:
///
///   flutter run -d chrome --dart-define=GOOGLE_WEB_CLIENT_ID=your-id.apps.googleusercontent.com
class GoogleAuthConfig {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
}
