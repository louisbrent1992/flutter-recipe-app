import 'package:shared_preferences/shared_preferences.dart';

class ImageResolverCache {
  static String _key(String key) => 'resolved_image_url_$key';

  static Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(key));
  }

  static Future<void> set(String key, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(key), url);
  }
}
