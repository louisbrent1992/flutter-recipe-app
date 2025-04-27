import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  bool _isDarkMode = false;
  late Box _prefs;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _initHive();
  }

  Future<void> _initHive() async {
    _prefs = await Hive.openBox('preferences');
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      _isDarkMode = _prefs.get(_themeKey, defaultValue: false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
      _isDarkMode = false;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    try {
      await _prefs.put(_themeKey, _isDarkMode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }
}
