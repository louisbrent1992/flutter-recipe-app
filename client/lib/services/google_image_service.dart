import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_client.dart';

const _uaHeaders = {
  'User-Agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

class GoogleImageService {
  static final ApiClient _api = ApiClient();
  static const Duration _requestTimeout = Duration(seconds: 10);

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
          final usable = await _isLoadableImage(imageUrl);
          if (usable) return imageUrl;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _isLoadableImage(String? url) async {
    if (url == null || !url.startsWith('http')) return false;
    try {
      final uri = Uri.parse(url);
      final head = await http
          .head(uri, headers: _uaHeaders)
          .timeout(_requestTimeout, onTimeout: () => http.Response('', 408));
      if (head.statusCode != 200) return false;
      final ct = head.headers['content-type'] ?? '';
      return ct.startsWith('image/');
    } catch (_) {
      return false;
    }
  }
}
