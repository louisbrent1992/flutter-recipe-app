import 'package:flutter/foundation.dart';
import '../models/notification_config.dart';
import 'api_client.dart';

class NotificationConfigService {
  final ApiClient _api = ApiClient();

  Future<NotificationConfig?> fetchConfig() async {
    try {
      final res = await _api.publicGet<Map<String, dynamic>>(
        'ui/notifications',
        fromJson: (map) => map,
      );
      if (res.success && res.data != null) {
        return NotificationConfig.fromJson(res.data!);
      }
      return null;
    } catch (e) {
      debugPrint('NotificationConfigService.fetchConfig error: $e');
      return null;
    }
  }
}


