/// Central place for the backend base URL, shared by every API service.
///
/// Must stay on HTTPS in local dev: the API's UseHttpsRedirection responds to
/// plain-HTTP calls with a cross-origin 307, and browsers drop the
/// Authorization header when following it, breaking authorized endpoints.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'https://localhost:7056';
}
