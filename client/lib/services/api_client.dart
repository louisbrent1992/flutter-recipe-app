import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/api_response.dart';

/// A centralized API client for making HTTP requests with standardized error handling
class ApiClient {
  static final Logger _logger = Logger();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Base URL for API requests
  String get baseUrl {
    final String productionUrl = 'https://flutter-recipe-app.onrender.com/api';
    final String developmentUrl =
        Platform.isAndroid
            ? 'http://172.16.1.2:3001/api'
            : 'http://localhost:3001/api';

    // Use production URL in release mode, development URL otherwise
    return const bool.fromEnvironment('dart.vm.product')
        ? productionUrl
        : developmentUrl;
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
      final response = await _post(endpoint, _standardHeaders, body);
      print('response: ${response.body}');
      return _handleResponse<T>(response, fromJson: fromJson);
    } catch (e) {
      return _handleError<T>(e, 'POST $endpoint');
    }
  }

  // Private implementation of HTTP methods
  Future<http.Response> _get(
    String endpoint,
    Map<String, String> headers,
    Map<String, String>? queryParams,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/$endpoint',
    ).replace(queryParameters: queryParams);

    _logger.d('GET $uri');
    return http.get(uri, headers: headers);
  }

  Future<http.Response> _post(
    String endpoint,
    Map<String, String> headers,
    dynamic body,
  ) async {
    final uri = Uri.parse('$baseUrl/$endpoint');

    _logger.d('POST $uri with body: $body');
    return http.post(
      uri,
      headers: headers,
      body: body == null ? null : json.encode(body),
    );
  }

  Future<http.Response> _put(
    String endpoint,
    Map<String, String> headers,
    dynamic body,
  ) async {
    final uri = Uri.parse('$baseUrl/$endpoint');

    _logger.d('PUT $uri with body: $body');
    return http.put(
      uri,
      headers: headers,
      body: body == null ? null : json.encode(body),
    );
  }

  Future<http.Response> _delete(
    String endpoint,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse('$baseUrl/$endpoint');

    _logger.d('DELETE $uri');
    return http.delete(uri, headers: headers);
  }

  // Response handling
  ApiResponse<T> _handleResponse<T>(
    http.Response response, {
    T Function(Map<String, dynamic>)? fromJson,
  }) {
    _logger.d('Response status: ${response.statusCode}');

    try {
      // Parse the response body
      final dynamic jsonData = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (jsonData is Map<String, dynamic>) {
          return ApiResponse<T>.fromJson(jsonData, fromJson: fromJson);
        } else if (T == List) {
          // Handle list responses
          return ApiResponse<T>.success(jsonData as T);
        } else {
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

    if (error is SocketException) {
      return ApiResponse<T>.error('Network error: Unable to connect to server');
    } else if (error is FormatException) {
      return ApiResponse<T>.error('Data format error: ${error.message}');
    } else if (error is FirebaseAuthException) {
      return ApiResponse<T>.error(
        'Authentication error: ${error.message}',
        statusCode: 401,
      );
    } else {
      return ApiResponse<T>.error('Unexpected error: ${error.toString()}');
    }
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    return _sendRequest<T>(
      http.get(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders(headers)),
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    T Function(dynamic)? fromJson,
  }) async {
    return _sendRequest<T>(
      http.post(
        Uri.parse('$baseUrl$endpoint'),
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
    return _sendRequest<T>(
      http.put(
        Uri.parse('$baseUrl$endpoint'),
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
    return _sendRequest<T>(
      http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(headers),
      ),
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
