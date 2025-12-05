/// Environment types for the app
enum AppEnvironment {
  development, // Local development server
  staging, // Staging Cloud Run server (for testing)
  production, // Production Cloud Run server
}

/// App configuration constants
class AppConfig {
  // ============================================================
  // ENVIRONMENT CONFIGURATION
  // ============================================================

  /// Current environment - set via --dart-define=ENV=staging
  /// Defaults to production for release builds
  static const String _envString = String.fromEnvironment(
    'ENV',
    defaultValue: 'production',
  );

  /// Parsed environment enum
  static AppEnvironment get environment {
    switch (_envString.toLowerCase()) {
      case 'development':
      case 'dev':
        return AppEnvironment.development;
      case 'staging':
      case 'stg':
        return AppEnvironment.staging;
      case 'production':
      case 'prod':
      default:
        return AppEnvironment.production;
    }
  }

  /// Check if running in staging environment
  static bool get isStaging => environment == AppEnvironment.staging;

  /// Check if running in production environment
  static bool get isProduction => environment == AppEnvironment.production;

  /// Check if running in development environment
  static bool get isDevelopment => environment == AppEnvironment.development;

  // ============================================================
  // API URLS
  // ============================================================

  /// Production API URL (your main Cloud Run service)
  static const String productionApiUrl =
      'https://recipease-app-server-826154873845.us-west2.run.app/api';

  /// Staging API URL (separate Cloud Run service for testing)
  /// Update this after deploying your staging service
  static const String stagingApiUrl =
      'https://flutter-recipe-app-826154873845.us-west2.run.app/api';

  /// Get the API URL for the current environment
  /// Note: Development URL is handled dynamically in ApiClient based on platform
  static String get apiUrl {
    switch (environment) {
      case AppEnvironment.staging:
        return stagingApiUrl;
      case AppEnvironment.production:
      case AppEnvironment.development:
        return productionApiUrl;
    }
  }

  // ============================================================
  // SPLASH SCREEN CONFIGURATION
  // ============================================================

  static const int splashMinDurationMs = 4000; // 4 seconds minimum
  static const int splashTransitionDelayMs =
      500; // 0.5 second for smooth transition

  // ============================================================
  // IMPORT SCREEN CONFIGURATION
  // ============================================================

  static const int importDelayMs = 100; // Delay for provider initialization
  static const int importNavigationDelayMs =
      1000; // Delay for cold start navigation

  // ============================================================
  // DEBUG CONFIGURATION
  // ============================================================

  static const bool enableDebugLogs = true;
  static const bool enablePerformanceOverlay = false;

  // Google Custom Search is now handled server-side for security
}
