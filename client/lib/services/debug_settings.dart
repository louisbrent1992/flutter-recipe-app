import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage debug-only features
/// This service only functions in debug mode and provides a toggle
/// to enable/disable debug features during development
class DebugSettings {
  static const String _debugEnabledKey = 'debug_features_enabled';
  
  // Singleton pattern
  static final DebugSettings _instance = DebugSettings._internal();
  factory DebugSettings() => _instance;
  DebugSettings._internal();

  bool _isDebugEnabled = false;
  SharedPreferences? _prefs;

  /// Initialize the debug settings
  Future<void> init() async {
    if (!kDebugMode) return; // Only initialize in debug mode
    
    _prefs = await SharedPreferences.getInstance();
    _isDebugEnabled = _prefs?.getBool(_debugEnabledKey) ?? false;
  }

  /// Check if debug features are enabled
  /// Returns false in production builds regardless of stored setting
  bool get isDebugEnabled {
    if (!kDebugMode) return false; // Always false in production
    return _isDebugEnabled;
  }

  /// Enable or disable debug features
  /// Only works in debug mode
  Future<void> setDebugEnabled(bool enabled) async {
    if (!kDebugMode) return; // Cannot change in production
    
    _isDebugEnabled = enabled;
    await _prefs?.setBool(_debugEnabledKey, enabled);
  }

  /// Check if a specific debug feature should be shown/enabled
  /// Combines kDebugMode check with the user's debug toggle setting
  bool shouldShowDebugFeature() {
    return kDebugMode && _isDebugEnabled;
  }
}

