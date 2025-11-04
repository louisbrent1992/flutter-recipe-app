import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:recipease/services/notification_scheduler.dart';

class NotificationProvider with ChangeNotifier {
  final Box _prefs;
  bool _dailyRecipeReminder = true;
  bool _weeklyDigest = true;
  bool _newRecipesNotification = true;

  // Category-based notifications (user-togglable)
  bool _catDailyInspiration = true;
  bool _catMealPrep = true;
  bool _catSeasonal = true;
  bool _catQuickMeals = true;
  bool _catBudget = true;
  bool _catKeto = false;

  NotificationProvider(this._prefs) {
    _loadPreferences();
  }

  bool get dailyRecipeReminder => _dailyRecipeReminder;
  bool get weeklyDigest => _weeklyDigest;
  bool get newRecipesNotification => _newRecipesNotification;

  bool get catDailyInspiration => _catDailyInspiration;
  bool get catMealPrep => _catMealPrep;
  bool get catSeasonal => _catSeasonal;
  bool get catQuickMeals => _catQuickMeals;
  bool get catBudget => _catBudget;
  bool get catKeto => _catKeto;

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

    // Categories
    _catDailyInspiration = _prefs.get(
      'catDailyInspiration',
      defaultValue: true,
    );
    _catMealPrep = _prefs.get('catMealPrep', defaultValue: true);
    _catSeasonal = _prefs.get('catSeasonal', defaultValue: true);
    _catQuickMeals = _prefs.get('catQuickMeals', defaultValue: true);
    _catBudget = _prefs.get('catBudget', defaultValue: true);
    _catKeto = _prefs.get('catKeto', defaultValue: false);
    notifyListeners();

    // Ensure schedules reflect current prefs
    await NotificationScheduler.scheduleAll(
      dailyInspiration: _catDailyInspiration,
      mealPrep: _catMealPrep,
      seasonal: _catSeasonal,
      quickMeals: _catQuickMeals,
      budget: _catBudget,
      keto: _catKeto,
    );
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

  // Category setters (persist + schedule)
  Future<void> setCatDailyInspiration(bool value) async {
    _catDailyInspiration = value;
    await _prefs.put('catDailyInspiration', value);
    notifyListeners();
    await NotificationScheduler.scheduleCategory(
      AppNotificationCategory.dailyInspiration,
      value,
    );
  }

  Future<void> setCatMealPrep(bool value) async {
    _catMealPrep = value;
    await _prefs.put('catMealPrep', value);
    notifyListeners();
    await NotificationScheduler.scheduleCategory(
      AppNotificationCategory.mealPrep,
      value,
    );
  }

  Future<void> setCatSeasonal(bool value) async {
    _catSeasonal = value;
    await _prefs.put('catSeasonal', value);
    notifyListeners();
    await NotificationScheduler.scheduleCategory(
      AppNotificationCategory.seasonal,
      value,
    );
  }

  Future<void> setCatQuickMeals(bool value) async {
    _catQuickMeals = value;
    await _prefs.put('catQuickMeals', value);
    notifyListeners();
    await NotificationScheduler.scheduleCategory(
      AppNotificationCategory.quickMeals,
      value,
    );
  }

  Future<void> setCatBudget(bool value) async {
    _catBudget = value;
    await _prefs.put('catBudget', value);
    notifyListeners();
    await NotificationScheduler.scheduleCategory(
      AppNotificationCategory.budget,
      value,
    );
  }

  Future<void> setCatKeto(bool value) async {
    _catKeto = value;
    await _prefs.put('catKeto', value);
    notifyListeners();
    await NotificationScheduler.scheduleCategory(
      AppNotificationCategory.keto,
      value,
    );
  }
}
