/// Central place for the backend base URL, shared by every API service.
///
/// Must stay on HTTPS in local dev: the API's UseHttpsRedirection responds to
/// plain-HTTP calls with a cross-origin 307, and browsers drop the
/// Authorization header when following it, breaking authorized endpoints.
///
/// Override per environment (required for release builds):
/// `flutter build apk --dart-define=API_BASE_URL=https://api.example.com`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7056',
  );
}
