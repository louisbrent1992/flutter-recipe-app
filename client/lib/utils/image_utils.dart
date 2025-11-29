import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageUtils {
  /// Default profile icon - uses local asset for faster loading
  static const String defaultProfileIconUrl = 'assets/images/chefs_hat.png';

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
  static String? getFallbackImageUrl(String? originalUrl) {
    // Return null instead of placeholder - let the UI handle empty images
    return null;
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

    // Use high-quality Unsplash images for different cuisine types
    switch (cuisine) {
      case 'italian':
        return 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=800&q=80';
      case 'chinese':
        return 'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=800&q=80';
      case 'mexican':
        return 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800&q=80';
      case 'indian':
        return 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&q=80';
      case 'japanese':
        return 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800&q=80';
      case 'french':
        return 'https://images.unsplash.com/photo-1606787366850-de6330128bfc?w=800&q=80';
      case 'mediterranean':
        return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80';
      default:
        return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80';
    }
  }

  /// Builds a profile image widget that handles both network URLs and local assets
  static Widget buildProfileImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    final url = imageUrl ?? defaultProfileIconUrl;
    
    if (isAssetPath(url)) {
      return Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? 
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.person, color: Colors.grey),
          ),
      );
    } else {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.person, color: Colors.grey),
          ),
      );
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
