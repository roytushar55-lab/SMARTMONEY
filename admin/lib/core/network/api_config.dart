/// Central place for the backend base URL, shared by every API service.
///
/// Override per build with `--dart-define=API_BASE_URL=https://api.example.com`
/// (e.g. `flutter build web --dart-define=API_BASE_URL=...`). Without it the
/// local dev API is used.
///
/// Must stay on HTTPS in local dev: the API's UseHttpsRedirection responds to
/// plain-HTTP calls with a cross-origin 307, and browsers drop the
/// Authorization header when following it, breaking authorized endpoints.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7056',
  );
}
