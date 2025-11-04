class NotificationConfig {
  final int version;
  final List<NotificationCategoryConfig> categories;

  NotificationConfig({required this.version, required this.categories});

  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    final cats =
        (json['categories'] as List? ?? [])
            .map(
              (e) => NotificationCategoryConfig.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
    return NotificationConfig(
      version: (json['version'] ?? 1) as int,
      categories: cats,
    );
  }

  Map<String, NotificationCategoryConfig> toMapByKey() {
    final map = <String, NotificationCategoryConfig>{};
    for (final c in categories) {
      map[c.key] = c;
    }
    return map;
  }
}

class NotificationCategoryConfig {
  final String key; // e.g., dailyInspiration
  final bool enabledDefault;
  final ScheduleConfig schedule;
  final String title;
  final String body;
  final String route;
  final Map<String, String> args;

  NotificationCategoryConfig({
    required this.key,
    required this.enabledDefault,
    required this.schedule,
    required this.title,
    required this.body,
    required this.route,
    required this.args,
  });

  factory NotificationCategoryConfig.fromJson(Map<String, dynamic> json) {
    return NotificationCategoryConfig(
      key: (json['key'] ?? '').toString(),
      enabledDefault: (json['enabledDefault'] ?? true) as bool,
      schedule: ScheduleConfig.fromJson(
        (json['schedule'] as Map).cast<String, dynamic>(),
      ),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      route: (json['route'] ?? '/').toString(),
      args:
          ((json['args'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ) ??
              <String, String>{}),
    );
  }
}

class ScheduleConfig {
  final String type; // 'daily' or 'weekly'
  final int hour;
  final int minute;
  final int? weekday; // 0=Sunday..6=Saturday when weekly

  const ScheduleConfig({
    required this.type,
    required this.hour,
    required this.minute,
    this.weekday,
  });

  factory ScheduleConfig.fromJson(Map<String, dynamic> json) {
    return ScheduleConfig(
      type: (json['type'] ?? 'daily').toString(),
      hour: (json['hour'] ?? 9) as int,
      minute: (json['minute'] ?? 0) as int,
      weekday:
          json['weekday'] == null ? null : (json['weekday'] as num).toInt(),
    );
  }
}
