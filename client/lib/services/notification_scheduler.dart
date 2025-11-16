import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_config.dart';

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
  static Map<String, NotificationCategoryConfig>? _configByKey;

  static void init(FlutterLocalNotificationsPlugin plugin) {
    _plugin = plugin;
  }

  // Provide dynamic config from server (call before scheduling)
  static void applyConfig(NotificationConfig config) {
    _configByKey = config.toMapByKey();
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

    // If server config is available, use it
    final key = _enumKey(category);
    final cfg = _configByKey?[key];
    if (cfg != null) {
      final sch = cfg.schedule;
      if (sch.type == 'weekly' && sch.weekday != null) {
        await _scheduleWeekly(
          id: id,
          weekday: _weekdayToDart(sch.weekday!),
          hour: sch.hour,
          minute: sch.minute,
          title: cfg.title,
          body: cfg.body,
          route: cfg.route,
          args: cfg.args,
        );
      } else {
        await _scheduleDaily(
          id: id,
          hour: sch.hour,
          minute: sch.minute,
          title: cfg.title,
          body: cfg.body,
          route: cfg.route,
          args: cfg.args,
        );
      }
      return;
    }

    // Fallback to baked-in defaults if server config missing
    switch (category) {
      case AppNotificationCategory.dailyInspiration:
        await _scheduleDaily(
          id: id,
          hour: 14,
          minute: 0,
          title: "Today's Picks 🍽️",
          body: "Handpicked recipes we think you'll love.",
          route: '/randomRecipe',
          args: {},
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
          args: {
            'tag': 'meal prep, batch cooking, prep ahead, prep for the week',
          },
        );
        break;
      case AppNotificationCategory.seasonal:
        await _scheduleWeekly(
          id: id,
          weekday: DateTime.friday,
          hour: 12,
          minute: 0,
          title: 'Holliday Favorites 🎄',
          body: 'New festive recipes just dropped.',
          route: '/discover',
          args: {
            'tag':
                'holliday, fall, thanksgiving, turkey, christmas, winter, pumpkin, cranberry, cinnamon',
          },
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
          args: {'tag': 'easy, 20 minutes, quick, minimal cleanup'},
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
          args: {'tag': 'budget, under \$10, frugal, cheap, affordable'},
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
    await scheduleCategory(
      AppNotificationCategory.dailyInspiration,
      dailyInspiration,
    );
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
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
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
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  static String _enumKey(AppNotificationCategory cat) {
    switch (cat) {
      case AppNotificationCategory.dailyInspiration:
        return 'dailyInspiration';
      case AppNotificationCategory.mealPrep:
        return 'mealPrep';
      case AppNotificationCategory.seasonal:
        return 'seasonal';
      case AppNotificationCategory.quickMeals:
        return 'quickMeals';
      case AppNotificationCategory.budget:
        return 'budget';
      case AppNotificationCategory.keto:
        return 'keto';
    }
  }

  // Convert 0..6 (Sun..Sat) to Dart's DateTime weekday constants
  static int _weekdayToDart(int zeroBased) {
    switch (zeroBased) {
      case 0:
        return DateTime.sunday;
      case 1:
        return DateTime.monday;
      case 2:
        return DateTime.tuesday;
      case 3:
        return DateTime.wednesday;
      case 4:
        return DateTime.thursday;
      case 5:
        return DateTime.friday;
      case 6:
      default:
        return DateTime.saturday;
    }
  }

  // Test method to immediately trigger a notification (for debugging)
  // Returns the route and args so caller can navigate directly if needed
  static Future<Map<String, dynamic>?> triggerTestNotification(
    AppNotificationCategory category,
  ) async {
    final id = _categoryToId[category]!;
    final key = _enumKey(category);
    final cfg = _configByKey?[key];

    String title;
    String body;
    String route;
    Map<String, String> args;

    if (cfg != null) {
      title = cfg.title;
      body = cfg.body;
      route = cfg.route;
      args = cfg.args;
    } else {
      // Use fallback defaults
      switch (category) {
        case AppNotificationCategory.dailyInspiration:
          title = "Today's Picks 🍽️";
          body = "Handpicked recipes we think you'll love.";
          route = '/randomRecipe';
          args = {};
          break;
        case AppNotificationCategory.mealPrep:
          title = 'Meal Prep Sunday 🍱';
          body = 'Plan your week with batch-friendly recipes.';
          route = '/discover';
          args = {
            'tag':
                'meal prep, batch cooking, prep ahead, make ahead, meal planning, weekly prep, batch recipes, freezer friendly',
          };
          break;
        case AppNotificationCategory.seasonal:
          title = 'Holliday Favorites 🎄';
          body = 'New festive recipes just dropped.';
          route = '/discover';
          args = {
            'tag':
                'fall, autumn, thanksgiving, turkey, seasonal, christmas, pumpkin, holliday, holiday',
          };
          break;
        case AppNotificationCategory.quickMeals:
          title = '20-Minute Dinners ⏱️';
          body = 'Fast, tasty, and minimal cleanup.';
          route = '/discover';
          args = {
            'tag':
                'easy, quick, fast, 20 minutes, 15 minutes, 30 minutes, minimal, simple, speedy, fast dinner',
          };
          break;
        case AppNotificationCategory.budget:
          title = 'Save on Groceries 💸';
          body = 'Delicious meals under \$10.';
          route = '/discover';
          args = {
            'tag':
                'budget, budget friendly, under \$10, under \$5, frugal, cheap, affordable, inexpensive, economical, cost effective',
          };
          break;
        case AppNotificationCategory.keto:
          title = 'Keto Spotlight 🥑';
          body = 'Popular low-carb recipes this week.';
          route = '/discover';
          args = {
            'tag':
                'keto, low-carb, ketogenic, keto-friendly, keto-diet, keto-recipes, low carb, lowcarb, no carb, zero carb',
          };
          break;
      }
    }

    final payload = jsonEncode({'route': route, 'args': args});
    await _plugin?.show(id, title, body, _details(), payload: payload);

    // Return route info for direct navigation
    return {'route': route, 'args': args};
  }
}
