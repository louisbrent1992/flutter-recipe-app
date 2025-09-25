import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

const _uaHeaders = {
  'User-Agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

class GoogleImageService {
  static const Duration _requestTimeout = Duration(seconds: 6);

  static Future<String?> fetchImageForQuery(String query) async {
    if (AppConfig.googleCseApiKey.isEmpty || AppConfig.googleCseCx.isEmpty) {
      return null;
    }

    final uri = Uri.https('customsearch.googleapis.com', '/customsearch/v1', {
      'q': query,
      'cx': AppConfig.googleCseCx,
      'key': AppConfig.googleCseApiKey,
      'searchType': 'image',
      'num': '3',
      'safe': 'active',
    });

    try {
      final res = await http.get(uri).timeout(_requestTimeout);
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? const [];

      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final img = (item['image'] as Map?)?.cast<String, dynamic>();
        final thumb = img?['thumbnailLink'] as String?;
        final link = item['link'] as String?;
        // Prefer full-resolution link first; fall back to thumbnail if needed
        for (final candidate in [link, thumb]) {
          final usable = await _isLoadableImage(candidate);
          if (usable) return candidate;
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
