import 'package:flutter/foundation.dart';
import '../models/dynamic_ui.dart';
import '../services/dynamic_ui_service.dart';

class DynamicUiProvider with ChangeNotifier {
  final DynamicUiService _service = DynamicUiService();
  DynamicUiConfig? _config;
  bool _loading = false;

  // Default fallback config for offline mode (matches server default)
  static DynamicUiConfig get _defaultConfig => DynamicUiConfig(
        version: 1,
        fetchedAt: DateTime.now(),
        banners: [],
        globalBackground: const DynamicBackgroundConfig(
          colors: ['#FFF3E0', '#FFE0B2'], // soft seasonal gradient
          animateGradient: true,
          kenBurns: true,
          opacity: 1.0,
        ),
        welcomeMessage: 'Welcome,',
        heroSubtitle: 'What would you like to cook today?',
        sectionVisibility: {
          'yourRecipesCarousel': true,
          'discoverCarousel': true,
          'collectionsCarousel': true,
          'featuresSection': true,
        },
      );

  // Return config from server, or default fallback if offline
  DynamicUiConfig? get config => _config ?? _defaultConfig;
  bool get isLoading => _loading;

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
    } catch (e) {
      // If fetch fails (offline), use default config
      // _config remains null, so getter will return _defaultConfig
      debugPrint('⚠️ Failed to fetch dynamic UI config, using default: $e');
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
}


