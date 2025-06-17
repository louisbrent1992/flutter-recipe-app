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
