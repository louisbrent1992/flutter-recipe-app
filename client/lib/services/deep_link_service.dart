import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeepLinkService {
  static const String _scheme = 'recipease';

  /// Handle incoming deep links from share extension
  static Future<void> handleDeepLink(String? link) async {
    if (link == null || !link.startsWith('$_scheme://')) {
      return;
    }

    try {
      final uri = Uri.parse(link);

      if (uri.host == 'share') {
        await _handleShareContent(uri);
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  /// Parse and handle shared content
  static Future<void> _handleShareContent(Uri uri) async {
    final content = uri.queryParameters['content'];
    final truncated = uri.queryParameters['truncated'] == 'true';

    if (content == null) {
      return;
    }

    final decodedContent = Uri.decodeComponent(content);
    final items = decodedContent.split('\n');

    // Parse different content types
    final urls = <String>[];
    final texts = <String>[];
    final images = <String>[];

    for (final item in items) {
      if (item.startsWith('URL: ')) {
        urls.add(item.substring(5));
      } else if (item.startsWith('TEXT: ')) {
        texts.add(item.substring(6));
      } else if (item.startsWith('IMAGE: ')) {
        images.add(item.substring(7));
      }
    }

    // Navigate to appropriate screen based on content
    await _navigateToContentScreen(
      urls: urls,
      texts: texts,
      images: images,
      truncated: truncated,
    );
  }

  /// Navigate to the appropriate screen based on shared content
  static Future<void> _navigateToContentScreen({
    required List<String> urls,
    required List<String> texts,
    required List<String> images,
    required bool truncated,
  }) async {
    // You can customize this navigation logic based on your app's structure
    if (images.isNotEmpty) {
      // Navigate to image processing screen
      _navigateToImageProcessing(images.first);
    } else if (urls.isNotEmpty) {
      // Navigate to URL processing screen
      _navigateToUrlProcessing(urls.first);
    } else if (texts.isNotEmpty) {
      // Navigate to text processing screen
      _navigateToTextProcessing(texts.join('\n'));
    }

    // Show notification if content was truncated
    if (truncated) {
      _showTruncatedNotification();
    }
  }

  /// Navigate to image processing screen
  static void _navigateToImageProcessing(String imageData) {
    // TODO: Implement navigation to image processing screen
    // Example: Navigator.pushNamed(context, '/image-processing', arguments: imageData);
    debugPrint(
      'Navigate to image processing with data: ${imageData.substring(0, 50)}...',
    );
  }

  /// Navigate to URL processing screen
  static void _navigateToUrlProcessing(String url) {
    // TODO: Implement navigation to URL processing screen
    // Example: Navigator.pushNamed(context, '/url-processing', arguments: url);
    debugPrint('Navigate to URL processing: $url');
  }

  /// Navigate to text processing screen
  static void _navigateToTextProcessing(String text) {
    // TODO: Implement navigation to text processing screen
    // Example: Navigator.pushNamed(context, '/text-processing', arguments: text);
    debugPrint('Navigate to text processing: ${text.substring(0, 50)}...');
  }

  /// Show notification that content was truncated
  static void _showTruncatedNotification() {
    // TODO: Implement notification system
    debugPrint('Content was truncated due to size limits');
  }

  /// Check if the app can handle a specific URL scheme
  static Future<bool> canHandleUrl(String url) async {
    return await canLaunchUrl(Uri.parse(url));
  }

  /// Launch a URL externally
  static Future<bool> launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    return await launchUrl(uri);
  }
}
