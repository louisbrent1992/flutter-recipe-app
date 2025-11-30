import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/app_config.dart';
import '../models/api_response.dart';

/// A centralized API client for making HTTP requests with standardized error handling
class ApiClient {
  static final Logger _logger = Logger();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final String port = '8080';
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool? _cachedIsPhysicalDevice;

  /// Check if running on a physical device (not emulator/simulator)
  /// This is cached after first check to avoid repeated async calls
  Future<bool> _checkIsPhysicalDevice() async {
    if (_cachedIsPhysicalDevice != null) {
      return _cachedIsPhysicalDevice!;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        _cachedIsPhysicalDevice = androidInfo.isPhysicalDevice;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Check if it's a simulator using multiple methods
        // 1. Check environment variable (most reliable for iOS simulators)
        final hasSimulatorUdid = Platform.environment.containsKey(
          'SIMULATOR_UDID',
        );
        // 2. Check device name/model for simulator indicators
        final nameContainsSimulator = iosInfo.name.toLowerCase().contains(
          'simulator',
        );
        final modelContainsSimulator = iosInfo.model.toLowerCase().contains(
          'simulator',
        );
        // 3. Check utsname.machine for simulator architectures (i386, x86_64 are simulators)
        final machine = iosInfo.utsname.machine.toLowerCase();
        final isSimulatorArch = machine == 'i386' || machine == 'x86_64';

        final isSimulator =
            hasSimulatorUdid ||
            nameContainsSimulator ||
            modelContainsSimulator ||
            isSimulatorArch;

        _cachedIsPhysicalDevice = !isSimulator;
      } else {
        // For web/desktop, assume it's a development environment
        _cachedIsPhysicalDevice = false;
      }
    } catch (e) {
      // Default to physical device if check fails (safer for production)
      _cachedIsPhysicalDevice = true;
    }

    return _cachedIsPhysicalDevice ?? true;
  }

  /// Base URL for API requests
  /// Priority:
  /// 1. If ENV=staging is set, use staging URL (for testing on physical devices)
  /// 2. If ENV=development or kDebugMode, use local development server
  /// 3. Otherwise, use production URL for physical devices
  Future<String> get baseUrl async {
    final String developmentUrl =
        Platform.isAndroid
            ? 'http://10.0.2.2:$port/api'
            : 'http://localhost:$port/api';

    // If explicitly set to staging environment, always use staging URL
    // This allows testing staging server on physical devices
    if (AppConfig.isStaging) {
      _logger.d('Using STAGING API: ${AppConfig.stagingApiUrl}');
      return AppConfig.stagingApiUrl;
    }

    // If explicitly set to development, use local server
    if (AppConfig.isDevelopment) {
      _logger.d('Using DEVELOPMENT API: $developmentUrl');
      return developmentUrl;
    }

    // In debug mode (IDE run), use development URL for emulators
    if (kDebugMode) {
      _logger.d('Using DEBUG/LOCAL API: $developmentUrl');
      return developmentUrl;
    }

    // In release mode, use production URL for physical devices, development for emulators
    final bool isPhysical = await _checkIsPhysicalDevice();
    final url = isPhysical ? AppConfig.productionApiUrl : developmentUrl;
    _logger.d('Using ${isPhysical ? "PRODUCTION" : "DEVELOPMENT"} API: $url');
    return url;
  }

  /// Get headers with Firebase authentication token
  Future<Map<String, String>> get _authHeaders async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Standard headers without authentication
  Map<String, String> get _standardHeaders => {
    'Content-Type': 'application/json',
  };

  /// Make an authenticated GET request
  Future<ApiResponse<T>> authenticatedGet<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final headers = await _authHeaders;
      final response = await _get(endpoint, headers, queryParams);
      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      return _handleError<T>(e, 'GET $endpoint');
    }
  }

  /// Make an authenticated POST request
  Future<ApiResponse<T>> authenticatedPost<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final headers = await _authHeaders;
      final response = await _post(endpoint, headers, body);

      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      return _handleError<T>(e, 'POST $endpoint');
    }
  }

  /// Make an authenticated PUT request
  Future<ApiResponse<T>> authenticatedPut<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final headers = await _authHeaders;
      final response = await _put(endpoint, headers, body);
      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      return _handleError<T>(e, 'PUT $endpoint');
    }
  }

  /// Make an authenticated PATCH request
  Future<ApiResponse<T>> authenticatedPatch<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final headers = await _authHeaders;
      final response = await _patch(endpoint, headers, body);
      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      return _handleError<T>(e, 'PATCH $endpoint');
    }
  }

  /// Make an authenticated DELETE request
  Future<ApiResponse<T>> authenticatedDelete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final headers = await _authHeaders;
      final response = await _delete(endpoint, headers);
      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      return _handleError<T>(e, 'DELETE $endpoint');
    }
  }

  /// Make a public GET request (no authentication)
  Future<ApiResponse<T>> publicGet<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _get(endpoint, _standardHeaders, queryParams);
      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      return _handleError<T>(e, 'GET $endpoint');
    }
  }

  /// Make a public POST request (no authentication)
  Future<ApiResponse<T>> publicPost<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final url = await baseUrl;
      debugPrint('🔴 [ApiClient] publicPost to: $url/$endpoint');
      debugPrint('🔴 [ApiClient] Body: $body');
      final response = await _post(endpoint, _standardHeaders, body);
      debugPrint('🔴 [ApiClient] Response status: ${response.statusCode}');
      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      debugPrint('🔴 [ApiClient] Error in publicPost: $e');
      return _handleError<T>(e, 'POST $endpoint');
    }
  }

  // Private implementation of HTTP methods
  Future<http.Response> _get(
    String endpoint,
    Map<String, String> headers,
    Map<String, String>? queryParams,
  ) async {
    final url = await baseUrl;
    final uri = Uri.parse(
      '$url/$endpoint',
    ).replace(queryParameters: queryParams);

    // debug logging removed

    // Add timeout to requests with longer timeout for recipe imports
    final isRecipeImport =
        uri.path.contains('/ai/recipes/import') ||
        uri.path.contains('/generatedRecipes/import');
    final timeoutDuration =
        isRecipeImport
            ? const Duration(seconds: 45) // 45 seconds for recipe imports
            : const Duration(seconds: 30); // 30 seconds for other requests

    final response = await http
        .get(uri, headers: headers)
        .timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException('Request timed out', timeoutDuration);
          },
        );

    return response;
  }

  Future<http.Response> _post(
    String endpoint,
    Map<String, String> headers,
    dynamic body,
  ) async {
    final url = await baseUrl;
    final uri = Uri.parse('$url/$endpoint');

    // Add timeout to requests with longer timeout for AI recipe operations
    final isAIRecipeOperation =
        uri.path.contains('/ai/recipes/import') ||
        uri.path.contains('/ai/recipes/generate') ||
        uri.path.contains('/generatedRecipes/import') ||
        uri.path.contains('/generatedRecipes/generate');
    final timeoutDuration =
        isAIRecipeOperation
            ? const Duration(seconds: 120) // 2 minutes for AI recipe operations
            : const Duration(seconds: 30); // 30 seconds for other requests

    final response = await http
        .post(
          uri,
          headers: headers,
          body: body == null ? null : json.encode(body),
        )
        .timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException('Request timed out', timeoutDuration);
          },
        );

    return response;
  }

  Future<http.Response> _put(
    String endpoint,
    Map<String, String> headers,
    dynamic body,
  ) async {
    final url = await baseUrl;
    final uri = Uri.parse('$url/$endpoint');

    // debug logging removed

    // Add timeout to requests with longer timeout for AI recipe operations
    final isAIRecipeOperation =
        uri.path.contains('/ai/recipes/import') ||
        uri.path.contains('/ai/recipes/generate') ||
        uri.path.contains('/generatedRecipes/import') ||
        uri.path.contains('/generatedRecipes/generate');
    final timeoutDuration =
        isAIRecipeOperation
            ? const Duration(seconds: 120) // 2 minutes for AI recipe operations
            : const Duration(seconds: 30); // 30 seconds for other requests

    final response = await http
        .put(
          uri,
          headers: headers,
          body: body == null ? null : json.encode(body),
        )
        .timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException('Request timed out', timeoutDuration);
          },
        );

    return response;
  }

  Future<http.Response> _patch(
    String endpoint,
    Map<String, String> headers,
    dynamic body,
  ) async {
    final url = await baseUrl;
    final uri = Uri.parse('$url/$endpoint');

    // debug logging removed

    // Add timeout to requests with longer timeout for AI recipe operations
    final isAIRecipeOperation =
        uri.path.contains('/ai/recipes/import') ||
        uri.path.contains('/ai/recipes/generate') ||
        uri.path.contains('/generatedRecipes/import') ||
        uri.path.contains('/generatedRecipes/generate');
    final timeoutDuration =
        isAIRecipeOperation
            ? const Duration(seconds: 120) // 2 minutes for AI recipe operations
            : const Duration(seconds: 30); // 30 seconds for other requests

    final response = await http
        .patch(
          uri,
          headers: headers,
          body: body == null ? null : json.encode(body),
        )
        .timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException('Request timed out', timeoutDuration);
          },
        );

    return response;
  }

  Future<http.Response> _delete(
    String endpoint,
    Map<String, String> headers,
  ) async {
    final url = await baseUrl;
    final uri = Uri.parse('$url/$endpoint');

    // debug logging removed

    // Add timeout to requests with longer timeout for AI recipe operations
    final isAIRecipeOperation =
        uri.path.contains('/ai/recipes/import') ||
        uri.path.contains('/ai/recipes/generate') ||
        uri.path.contains('/generatedRecipes/import') ||
        uri.path.contains('/generatedRecipes/generate');
    final timeoutDuration =
        isAIRecipeOperation
            ? const Duration(seconds: 120) // 2 minutes for AI recipe operations
            : const Duration(seconds: 30); // 30 seconds for other requests

    final response = await http
        .delete(uri, headers: headers)
        .timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException('Request timed out', timeoutDuration);
          },
        );

    return response;
  }

  // Response handling
  ApiResponse<T> _handleResponse<T>(
    http.Response response, {
    T Function(Map<String, dynamic>)? fromJson,
  }) {
    try {
      // Parse the response body
      final dynamic jsonData = json.decode(response.body);
      debugPrint('🔵 [ApiClient] _handleResponse: statusCode=${response.statusCode}');
      debugPrint('🔵 [ApiClient] _handleResponse: jsonData type=${jsonData.runtimeType}');
      debugPrint('🔵 [ApiClient] _handleResponse: T=$T');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (jsonData is Map<String, dynamic>) {
          debugPrint('🔵 [ApiClient] _handleResponse: Using fromJson path');
          return ApiResponse<T>.fromJson(jsonData, fromJson: fromJson);
        } else if (jsonData is List) {
          // Handle list responses (works for List<dynamic> and other list types)
          debugPrint('🔵 [ApiClient] _handleResponse: Using list path, list length=${jsonData.length}');
          return ApiResponse<T>.success(jsonData as T);
        } else {
          debugPrint('🔵 [ApiClient] _handleResponse: Using else path');
          return ApiResponse<T>.success(jsonData as T);
        }
      } else {
        // Handle error responses
        final errorMessage =
            jsonData is Map<String, dynamic> && jsonData.containsKey('message')
                ? jsonData['message']
                : 'Request failed with status: ${response.statusCode}';

        return ApiResponse<T>.error(
          errorMessage,
          statusCode: response.statusCode,
          metadata: jsonData is Map<String, dynamic> ? jsonData : null,
        );
      }
    } catch (e) {
      // Handle JSON parsing errors
      return ApiResponse<T>.error(
        'Failed to parse response: ${e.toString()}',
        statusCode: response.statusCode,
      );
    }
  }

  // Error handling
  ApiResponse<T> _handleError<T>(dynamic error, String operation) {
    _logger.e('Error during $operation: $error');

    // Detect offline/network errors
    if (error is SocketException) {
      return ApiResponse<T>.error(
        'No internet connection. Please check your network and try again.',
        statusCode: 0, // Use 0 to indicate offline
      );
    } else if (error is HttpException) {
      // HTTP exceptions can indicate network issues
      return ApiResponse<T>.error(
        'Network error: ${error.message}',
        statusCode: 0,
      );
    } else if (error is FormatException) {
      return ApiResponse<T>.error('Data format error: ${error.message}');
    } else if (error is FirebaseAuthException) {
      return ApiResponse<T>.error(
        'Authentication error: ${error.message}',
        statusCode: 401,
      );
    } else if (error is TimeoutException) {
      // Timeout could be due to slow network or offline
      final message = error.message?.toLowerCase() ?? '';
      if (message.contains('timeout') || message.contains('timed out')) {
        return ApiResponse<T>.error(
          'Request timeout: This may be due to a slow connection or being offline.',
          statusCode: 0, // Treat timeout as potential offline
        );
      }
      return ApiResponse<T>.error('Request took too long. Please try again.');
    } else if (error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection') ||
        error.toString().toLowerCase().contains('offline')) {
      // Catch other network-related errors
      return ApiResponse<T>.error(
        'Connection issue. Please check your internet and try again.',
        statusCode: 0,
      );
    } else {
      return ApiResponse<T>.error('Something went wrong. Please try again.');
    }
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    final url = await baseUrl;
    return _sendRequest<T>(
      http.get(Uri.parse('$url$endpoint'), headers: _getHeaders(headers)),
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    T Function(dynamic)? fromJson,
  }) async {
    final url = await baseUrl;
    return _sendRequest<T>(
      http.post(
        Uri.parse('$url$endpoint'),
        headers: _getHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    T Function(dynamic)? fromJson,
  }) async {
    final url = await baseUrl;
    return _sendRequest<T>(
      http.put(
        Uri.parse('$url$endpoint'),
        headers: _getHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    final url = await baseUrl;
    return _sendRequest<T>(
      http.delete(Uri.parse('$url$endpoint'), headers: _getHeaders(headers)),
      fromJson: fromJson,
    );
  }

  Map<String, String> _getHeaders(Map<String, String>? additionalHeaders) {
    final headers = {'Content-Type': 'application/json'};

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  Future<ApiResponse<T>> _sendRequest<T>(
    Future<http.Response> request, {
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await request;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic responseBody =
            response.body.isNotEmpty ? jsonDecode(response.body) : null;

        final transformedData =
            fromJson != null && responseBody != null
                ? fromJson(responseBody)
                : responseBody as T;

        return ApiResponse<T>.success(transformedData);
      } else {
        return ApiResponse<T>.error(_getErrorMessage(response));
      }
    } on SocketException {
      return ApiResponse<T>.error('No internet connection');
    } on FormatException {
      return ApiResponse<T>.error('Invalid response format');
    } catch (e) {
      return ApiResponse<T>.error(e.toString());
    }
  }

  String _getErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ?? body['error'] ?? 'Unknown error occurred';
    } catch (_) {
      return 'Error ${response.statusCode}: ${response.reasonPhrase}';
    }
  }
}
