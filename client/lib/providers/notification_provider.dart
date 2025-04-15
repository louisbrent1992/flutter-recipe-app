import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider with ChangeNotifier {
  final Box _prefs;
  bool _dailyRecipeReminder = true;
  bool _weeklyDigest = true;
  bool _newRecipesNotification = true;

  NotificationProvider(this._prefs) {
    _loadPreferences();
  }

  bool get dailyRecipeReminder => _dailyRecipeReminder;
  bool get weeklyDigest => _weeklyDigest;
  bool get newRecipesNotification => _newRecipesNotification;

  Future<void> _loadPreferences() async {
    _dailyRecipeReminder = _prefs.get(
      'dailyRecipeReminder',
      defaultValue: true,
    );
    _weeklyDigest = _prefs.get('weeklyDigest', defaultValue: true);
    _newRecipesNotification = _prefs.get(
      'newRecipesNotification',
      defaultValue: true,
    );
    notifyListeners();
  }

  Future<void> setDailyRecipeReminder(bool value) async {
    _dailyRecipeReminder = value;
    await _prefs.put('dailyRecipeReminder', value);
    notifyListeners();
  }

  Future<void> setWeeklyDigest(bool value) async {
    _weeklyDigest = value;
    await _prefs.put('weeklyDigest', value);
    notifyListeners();
  }

  Future<void> setNewRecipesNotification(bool value) async {
    _newRecipesNotification = value;
    await _prefs.put('newRecipesNotification', value);
    notifyListeners();
  }
}
