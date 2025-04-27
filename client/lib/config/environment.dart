enum Environment { development, production }

class EnvironmentConfig {
  static Environment _environment = Environment.development;

  static void setEnvironment(Environment env) {
    _environment = env;
  }

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isProduction => _environment == Environment.production;

  static String get firebaseProjectId {
    if (isDevelopment) {
      return 'your-dev-project-id';
    } else {
      return 'your-prod-project-id';
    }
  }
}
