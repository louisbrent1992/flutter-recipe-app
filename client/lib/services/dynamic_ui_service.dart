import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/dynamic_ui.dart';
import 'api_client.dart';

class DynamicUiService {
  final ApiClient _api = ApiClient();

  Future<DynamicUiConfig?> fetchConfig() async {
    try {
      final res = await _api.publicGet<Map<String, dynamic>>(
        'ui/config',
        fromJson: (map) => map,
      );
      if (res.success && res.data != null) {
        // The ApiClient already unwraps { data: ... } into res.data
        final Map<String, dynamic> obj = res.data!;
        return DynamicUiConfig.fromJson(obj);
      }
      return null;
    } catch (e) {
      debugPrint('DynamicUiService.fetchConfig error: $e');
      return null;
    }
  }
}
