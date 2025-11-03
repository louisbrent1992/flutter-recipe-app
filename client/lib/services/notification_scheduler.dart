import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

enum AppNotificationCategory {
  dailyInspiration,
  mealPrep,
  seasonal,
  quickMeals,
  budget,
  keto,
}

class NotificationScheduler {
  static FlutterLocalNotificationsPlugin? _plugin;

  static void init(FlutterLocalNotificationsPlugin plugin) {
    _plugin = plugin;
  }

  static Future<void> cancelAllCategorySchedules() async {
    for (final id in _categoryToId.values) {
      await _plugin?.cancel(id);
    }
  }

  static const Map<AppNotificationCategory, int> _categoryToId = {
    AppNotificationCategory.dailyInspiration: 1001,
    AppNotificationCategory.mealPrep: 1002,
    AppNotificationCategory.seasonal: 1003,
    AppNotificationCategory.quickMeals: 1004,
    AppNotificationCategory.budget: 1005,
    AppNotificationCategory.keto: 1006,
  };

  static NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'recipease_general',
        'General',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  static Future<void> scheduleCategory(
    AppNotificationCategory category,
    bool enabled,
  ) async {
    final id = _categoryToId[category]!;
    // Always cancel first to avoid duplicates
    await _plugin?.cancel(id);
    if (!enabled) return;

    switch (category) {
      case AppNotificationCategory.dailyInspiration:
        await _scheduleDaily(
          id: id,
          hour: 9,
          minute: 0,
          title: 'Today’s Pick 🍽️',
          body: 'A handpicked recipe we think you’ll love.',
          route: '/discover',
          args: {'tag': 'today'},
        );
        break;
      case AppNotificationCategory.mealPrep:
        await _scheduleWeekly(
          id: id,
          weekday: DateTime.sunday,
          hour: 17,
          minute: 0,
          title: 'Meal Prep Sunday 🍱',
          body: 'Plan your week with batch-friendly recipes.',
          route: '/discover',
          args: {'tag': 'meal_prep'},
        );
        break;
      case AppNotificationCategory.seasonal:
        await _scheduleWeekly(
          id: id,
          weekday: DateTime.friday,
          hour: 12,
          minute: 0,
          title: 'Holiday Favorites 🎄',
          body: 'New festive recipes just dropped.',
          route: '/discover',
          args: {'tag': 'holiday'},
        );
        break;
      case AppNotificationCategory.quickMeals:
        await _scheduleWeekly(
          id: id,
          weekday: DateTime.tuesday,
          hour: 18,
          minute: 0,
          title: '20-Minute Dinners ⏱️',
          body: 'Fast, tasty, and minimal cleanup.',
          route: '/discover',
          args: {'tag': 'quick'},
        );
        break;
      case AppNotificationCategory.budget:
        await _scheduleWeekly(
          id: id,
          weekday: DateTime.wednesday,
          hour: 18,
          minute: 0,
          title: 'Save on Groceries 💸',
          body: 'Delicious meals under \$10.',
          route: '/discover',
          args: {'tag': 'budget'},
        );
        break;
      case AppNotificationCategory.keto:
        await _scheduleWeekly(
          id: id,
          weekday: DateTime.monday,
          hour: 12,
          minute: 0,
          title: 'Keto Spotlight 🥑',
          body: 'Popular low-carb recipes this week.',
          route: '/discover',
          args: {'tag': 'keto'},
        );
        break;
    }
  }

  static Future<void> scheduleAll({
    required bool dailyInspiration,
    required bool mealPrep,
    required bool seasonal,
    required bool quickMeals,
    required bool budget,
    required bool keto,
  }) async {
    await scheduleCategory(AppNotificationCategory.dailyInspiration, dailyInspiration);
    await scheduleCategory(AppNotificationCategory.mealPrep, mealPrep);
    await scheduleCategory(AppNotificationCategory.seasonal, seasonal);
    await scheduleCategory(AppNotificationCategory.quickMeals, quickMeals);
    await scheduleCategory(AppNotificationCategory.budget, budget);
    await scheduleCategory(AppNotificationCategory.keto, keto);
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String route,
    Map<String, String>? args,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final payload = jsonEncode({'route': route, 'args': args ?? {}});
    await _plugin?.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  static Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String route,
    Map<String, String>? args,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final payload = jsonEncode({'route': route, 'args': args ?? {}});
    await _plugin?.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }
}


