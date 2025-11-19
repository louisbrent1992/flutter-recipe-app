import 'dart:async';
import 'api_client.dart';
import '../utils/image_validation_utils.dart';

class GoogleImageService {
  static final ApiClient _api = ApiClient();

  static Future<String?> fetchImageForQuery(String query, {int? start}) async {
    if (query.trim().isEmpty) {
      return null;
    }

    final params = <String, String>{'query': query.trim()};
    if (start != null && start > 0) {
      params['start'] = start.toString();
    }

    try {
      final response = await _api.publicGet<Map<String, dynamic>>(
        'ai/recipes/search-image',
        queryParams: params,
      );

      if (response.success && response.data != null) {
        final imageUrl = response.data!['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Validate that the image is actually loadable
          final usable = await ImageValidationUtils.isValidImageUrl(imageUrl);
          if (usable) return imageUrl;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
