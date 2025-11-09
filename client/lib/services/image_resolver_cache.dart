import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ImageResolverCache {
  static String _key(String key) => 'resolved_image_url_$key';

  static Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key(key));
    debugPrint('[ImageResolverCache] GET $key hit=${val != null}');
    return val;
  }

  static Future<void> set(String key, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(key), url);
    debugPrint('[ImageResolverCache] SET $key');
  }

  static Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(key));
    debugPrint('[ImageResolverCache] DELETE $key');
  }

  static Future<int> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    int removed = 0;
    for (final k in keys) {
      if (k.startsWith('resolved_image_url_')) {
        await prefs.remove(k);
        removed++;
      }
    }
    debugPrint('[ImageResolverCache] CLEAR_ALL removed=$removed');
    return removed;
  }
}
