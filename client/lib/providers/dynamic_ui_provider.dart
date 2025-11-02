import 'package:flutter/foundation.dart';
import '../models/dynamic_ui.dart';
import '../services/dynamic_ui_service.dart';

class DynamicUiProvider with ChangeNotifier {
  final DynamicUiService _service = DynamicUiService();
  DynamicUiConfig? _config;
  bool _loading = false;
  bool _modalShownThisSession = false;

  DynamicUiConfig? get config => _config;
  bool get isLoading => _loading;
  bool get modalShownThisSession => _modalShownThisSession;

  DynamicUiProvider() {
    refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final cfg = await _service.fetchConfig();
      _config = cfg;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<DynamicBannerConfig> bannersForPlacement(String placement) {
    final list = _config?.banners
            .where((b) => b.placement == placement && b.isActive)
            .toList() ??
        [];
    list.sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  void markModalShown() {
    if (!_modalShownThisSession) {
      _modalShownThisSession = true;
      notifyListeners();
    }
  }
}


