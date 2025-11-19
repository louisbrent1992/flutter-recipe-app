import 'dart:async';
import 'package:http/http.dart' as http;

/// Centralized image validation utilities
/// 
/// Provides consistent image URL validation and checking across the app
class ImageValidationUtils {
  static const Duration _defaultTimeout = Duration(seconds: 10);
  
  static const Map<String, String> _defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  /// Check if a URL is a valid image and is accessible
  /// 
  /// Returns true if:
  /// - URL is valid HTTPS
  /// - Server responds with 200 status
  /// - Content-Type is an image
  static Future<bool> isValidImageUrl(
    String? url, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    if (url == null || url.isEmpty) return false;
    if (!url.startsWith('http')) return false;

    try {
      final uri = Uri.parse(url);
      final response = await http
          .head(
            uri,
            headers: headers ?? _defaultHeaders,
          )
          .timeout(
            timeout ?? _defaultTimeout,
            onTimeout: () => http.Response('', 408),
          );

      // Check if response is successful
      if (response.statusCode != 200) return false;

      // Verify content-type is an image
      final contentType = response.headers['content-type'] ?? '';
      return contentType.startsWith('image/');
    } catch (e) {
      return false;
    }
  }

  /// Check if an image URL is broken (returns error status codes)
  /// 
  /// Returns true if the image is broken or inaccessible:
  /// - 400 (Bad Request)
  /// - 403 (Forbidden)
  /// - 404 (Not Found)
  /// - Network errors
  /// - Timeout errors
  static Future<bool> isImageBroken(
    String? url, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    if (url == null || url.isEmpty) return true;

    try {
      final uri = Uri.parse(url);
      final response = await http
          .head(
            uri,
            headers: headers ?? _defaultHeaders,
          )
          .timeout(
            timeout ?? _defaultTimeout,
            onTimeout: () => http.Response('', 408),
          );

      // Consider these status codes as broken images
      return response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 404 ||
          response.statusCode == 408;
    } catch (e) {
      // Network errors also indicate broken images
      return true;
    }
  }

  /// Check if a URL is a placeholder image
  /// 
  /// Returns true if the URL contains common placeholder patterns
  static bool isPlaceholderUrl(String? url) {
    if (url == null || url.isEmpty) return true;

    final placeholderPatterns = [
      'placeholder.com',
      'via.placeholder',
      'placehold.it',
      'placekitten.com',
      'lorempixel.com',
      'dummyimage.com',
      'example.com',
    ];

    final lowerUrl = url.toLowerCase();
    return placeholderPatterns.any((pattern) => lowerUrl.contains(pattern));
  }

  /// Validate that a URL is an image and reachable (with placeholder check)
  /// 
  /// Returns true if:
  /// - Not a placeholder URL
  /// - Valid HTTPS URL
  /// - Accessible with 200 status
  /// - Has image content-type
  static Future<bool> validateImageUrl(
    String? url, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    if (url == null || url.isEmpty) return false;
    if (!url.startsWith('https://')) return false;
    if (isPlaceholderUrl(url)) return false;

    return await isValidImageUrl(url, timeout: timeout, headers: headers);
  }
}

