import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageUtils {
  /// Determines if the given path is a network URL
  static bool isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Determines if the given path is an asset path
  static bool isAssetPath(String path) {
    return path.startsWith('assets/') || path.startsWith('images/');
  }

  /// Determines if the given path is a local file
  static bool isLocalFile(String path) {
    return path.startsWith('file://') ||
        (!path.startsWith('http') &&
            !path.startsWith('assets/') &&
            !path.startsWith('images/'));
  }

  /// Get a fallback image URL when the original image fails to load
  static String getFallbackImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Recipe+Image';
    }

    // If the original URL is already a placeholder, return it
    if (originalUrl.contains('placeholder.com') ||
        originalUrl.contains('via.placeholder.com')) {
      return originalUrl;
    }

    // Return a placeholder image
    return 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Recipe+Image';
  }

  /// Check if an image URL is valid
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    // Check if it's a valid URL
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Get a default recipe image based on cuisine type
  static String getDefaultRecipeImage(String cuisineType) {
    final cuisine = cuisineType.toLowerCase();

    switch (cuisine) {
      case 'italian':
        return 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Italian+Recipe';
      case 'chinese':
        return 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Chinese+Recipe';
      case 'mexican':
        return 'https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Mexican+Recipe';
      case 'indian':
        return 'https://via.placeholder.com/400x300/96CEB4/FFFFFF?text=Indian+Recipe';
      case 'japanese':
        return 'https://via.placeholder.com/400x300/FFEAA7/000000?text=Japanese+Recipe';
      case 'french':
        return 'https://via.placeholder.com/400x300/DDA0DD/FFFFFF?text=French+Recipe';
      case 'mediterranean':
        return 'https://via.placeholder.com/400x300/98D8C8/FFFFFF?text=Mediterranean+Recipe';
      default:
        return 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Recipe+Image';
    }
  }

  /// Builds the appropriate image widget based on the imageUrl
  static Widget buildRecipeImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // Default error widget
    Widget defaultError =
        errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.restaurant, color: Colors.grey, size: 40),
        );

    // Default placeholder
    Widget defaultPlaceholder =
        placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        );

    if (isNetworkUrl(imageUrl)) {
      // Network image
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => defaultPlaceholder,
        errorWidget: (context, url, error) => defaultError,
      );
    } else if (isAssetPath(imageUrl)) {
      // Asset image
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => defaultError,
      );
    } else {
      // Invalid or unrecognized format - show error widget
      return defaultError;
    }
  }
}
