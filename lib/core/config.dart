/// App configuration. The API base URL is compile-time injected so release
/// builds pin the right host; the default targets the deployed kyco backend.
///
/// Override per environment, e.g.:
///   flutter run --dart-define=API_BASE=http://localhost:3088/api/v1   (iOS simulator → local backend)
///   flutter run --dart-define=API_BASE=http://10.0.2.2:3088/api/v1    (Android emulator → host localhost)
///   flutter build ios --dart-define=API_BASE=https://kyco.vn/api/v1   (production)
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://kyco.vn/api/v1',
  );

  /// The kyco mobile API is dark-launchable behind the api_mobile_v1_enabled
  /// flag; when OFF the backend returns 503 MAINTENANCE on every /v1 route.
  static const Duration requestTimeout = Duration(seconds: 20);
}
