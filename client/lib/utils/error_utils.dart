/// Centralized error type detection utilities
/// 
/// Provides consistent error classification across the app
class ErrorUtils {
  /// Check if an error message indicates a network error
  /// 
  /// Returns true for connection errors, timeouts, and network failures
  static bool isNetworkError(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) return false;

    final lowerError = errorMessage.toLowerCase();
    
    return lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout') ||
        lowerError.contains('unreachable') ||
        lowerError.contains('offline') ||
        lowerError.contains('no internet') ||
        lowerError.contains('failed to connect') ||
        lowerError.contains('socket') ||
        lowerError.contains('dns');
  }

  /// Check if an error message indicates an authentication error
  /// 
  /// Returns true for auth failures, login issues, and permission denied
  static bool isAuthError(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) return false;

    final lowerError = errorMessage.toLowerCase();
    
    return lowerError.contains('auth') ||
        lowerError.contains('login') ||
        lowerError.contains('unauthorized') ||
        lowerError.contains('forbidden') ||
        lowerError.contains('permission') ||
        lowerError.contains('denied') ||
        lowerError.contains('credential') ||
        lowerError.contains('token') ||
        lowerError.contains('session expired');
  }

  /// Check if an error message indicates a format/parsing error
  /// 
  /// Returns true for JSON errors, parsing failures, and invalid data
  static bool isFormatError(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) return false;

    final lowerError = errorMessage.toLowerCase();
    
    return lowerError.contains('format') ||
        lowerError.contains('parse') ||
        lowerError.contains('json') ||
        lowerError.contains('xml') ||
        lowerError.contains('invalid') ||
        lowerError.contains('malformed') ||
        lowerError.contains('decode') ||
        lowerError.contains('corrupt');
  }

  /// Check if an error message indicates a rate limiting error
  /// 
  /// Returns true for rate limit and quota exceeded errors
  static bool isRateLimitError(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) return false;

    final lowerError = errorMessage.toLowerCase();
    
    return lowerError.contains('rate') ||
        lowerError.contains('limit') ||
        lowerError.contains('quota') ||
        lowerError.contains('throttle') ||
        lowerError.contains('too many requests');
  }

  /// Check if an error message indicates a server error
  /// 
  /// Returns true for 500-level errors and server failures
  static bool isServerError(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) return false;

    final lowerError = errorMessage.toLowerCase();
    
    return lowerError.contains('server error') ||
        lowerError.contains('internal server') ||
        lowerError.contains('503') ||
        lowerError.contains('500') ||
        lowerError.contains('502') ||
        lowerError.contains('504') ||
        lowerError.contains('unavailable') ||
        lowerError.contains('maintenance');
  }

  /// Get a user-friendly error message based on error type
  /// 
  /// Returns a clear, actionable message for the user
  static String getUserFriendlyMessage(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }

    if (isNetworkError(errorMessage)) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }

    if (isAuthError(errorMessage)) {
      return 'Authentication failed. Please log in again.';
    }

    if (isRateLimitError(errorMessage)) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    if (isServerError(errorMessage)) {
      return 'Server is temporarily unavailable. Please try again later.';
    }

    if (isFormatError(errorMessage)) {
      return 'Invalid data format. Please contact support if this persists.';
    }

    // Return original message if no specific type detected
    return errorMessage;
  }

  /// Categorize an error into a specific type
  /// 
  /// Returns one of: 'network', 'auth', 'format', 'rate_limit', 'server', 'unknown'
  static String categorizeError(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) return 'unknown';

    if (isNetworkError(errorMessage)) return 'network';
    if (isAuthError(errorMessage)) return 'auth';
    if (isRateLimitError(errorMessage)) return 'rate_limit';
    if (isServerError(errorMessage)) return 'server';
    if (isFormatError(errorMessage)) return 'format';

    return 'unknown';
  }
}

