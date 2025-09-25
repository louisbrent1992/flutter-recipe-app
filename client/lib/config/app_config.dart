/// App configuration constants
class AppConfig {
  // Splash screen configuration
  static const int splashMinDurationMs = 2000; // 2 seconds minimum
  static const int splashTransitionDelayMs =
      500; // 0.5 seconds for smooth transition

  // Import screen configuration
  static const int importDelayMs = 100; // Delay for provider initialization
  static const int importNavigationDelayMs =
      1000; // Delay for cold start navigation

  // Other app configuration
  static const bool enableDebugLogs = true;
  static const bool enablePerformanceOverlay = false;

  // Google Custom Search (Images) configuration
  // NOTE: Add your keys in a secure way for production. These are placeholders.
  static const String googleCseApiKey =
      'AIzaSyCIZh9rF7Mr6RW-GfnCfATJHSdZegbyfHM';
  static const String googleCseCx = '14c8c38a3d190407c';
}
