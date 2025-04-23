/// Represents a standard API response with consistent error handling
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic>? metadata;

  /// Creates a successful API response with data
  ApiResponse.success(this.data, {this.message, this.metadata})
    : success = true,
      statusCode = 200;

  /// Creates an error API response
  ApiResponse.error(this.message, {this.statusCode = 500, this.metadata})
    : success = false,
      data = null;

  /// Creates an API response from a JSON response
  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(Map<String, dynamic>)? fromJson,
  }) {
    final hasError = json.containsKey('error') && json['error'] == true;

    if (hasError) {
      return ApiResponse<T>.error(
        json['message'] ?? 'Unknown error',
        statusCode: json['statusCode'] ?? 500,
        metadata: json,
      );
    } else {
      // For successful responses, check if we need to transform data
      final responseData = json.containsKey('data') ? json['data'] : json;

      // If response data is a Map and fromJson is provided, transform it
      final transformedData =
          responseData is Map<String, dynamic> && fromJson != null
              ? fromJson(responseData)
              : responseData as T?;

      return ApiResponse<T>.success(
        transformedData,
        message: json['message'],
        metadata: json['metadata'],
      );
    }
  }

  /// Utility method to check if there was a network error
  bool get isNetworkError =>
      message?.toLowerCase().contains('network') == true ||
      message?.toLowerCase().contains('connection') == true ||
      statusCode == null;

  /// User-friendly error message for display
  String get userFriendlyMessage {
    if (isNetworkError) {
      return 'Network error. Please check your internet connection.';
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'Authentication error. Please login again.';
    }

    if (statusCode == 404) {
      return 'Resource not found.';
    }

    return message ?? 'An unexpected error occurred.';
  }
}
