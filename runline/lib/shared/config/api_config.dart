/// Shared build-time settings for route and facility requests.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const token = String.fromEnvironment('API_TOKEN');
}
