class DynamicUiConfig {
  final int version;
  final DateTime fetchedAt;
  final List<DynamicBannerConfig> banners;
  final List<QuickActionConfig> quickActions;
  final PromoModalConfig? modal;

  DynamicUiConfig({
    required this.version,
    required this.fetchedAt,
    required this.banners,
    required this.quickActions,
    required this.modal,
  });

  factory DynamicUiConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> bannerList = json['banners'] ?? [];
    return DynamicUiConfig(
      version: (json['version'] ?? 1) as int,
      fetchedAt: DateTime.tryParse(json['fetchedAt'] ?? '') ?? DateTime.now(),
      banners:
          bannerList
              .map(
                (e) => DynamicBannerConfig.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
      quickActions:
          (json['quickActions'] as List<dynamic>? ?? [])
              .map((e) => QuickActionConfig.fromJson(e as Map<String, dynamic>))
              .toList(),
      modal:
          json['modal'] == null
              ? null
              : PromoModalConfig.fromJson(
                json['modal'] as Map<String, dynamic>,
              ),
    );
  }
}

class DynamicBannerConfig {
  final String id;
  final String placement; // e.g., home_top, shop_top
  final String title;
  final String? subtitle;
  final String? ctaText;
  final String? ctaUrl; // can be http(s):// or app://route
  final String? imageUrl;
  final String? backgroundColor; // hex string #RRGGBB or #AARRGGBB
  final String? textColor; // hex
  final int priority;
  final DateTime? startAt;
  final DateTime? endAt;

  DynamicBannerConfig({
    required this.id,
    required this.placement,
    required this.title,
    this.subtitle,
    this.ctaText,
    this.ctaUrl,
    this.imageUrl,
    this.backgroundColor,
    this.textColor,
    this.priority = 0,
    this.startAt,
    this.endAt,
  });

  factory DynamicBannerConfig.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v as String);
      } catch (_) {
        return null;
      }
    }

    return DynamicBannerConfig(
      id: json['id'] ?? '',
      placement: json['placement'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      ctaText: json['ctaText'],
      ctaUrl: json['ctaUrl'],
      imageUrl: json['imageUrl'],
      backgroundColor: json['backgroundColor'],
      textColor: json['textColor'],
      priority: (json['priority'] ?? 0) as int,
      startAt: parseDate(json['startAt']),
      endAt: parseDate(json['endAt']),
    );
  }

  bool get isActive {
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }
}

class QuickActionConfig {
  final String icon; // material icon name
  final String text;
  final String url; // app:// or http(s)://

  QuickActionConfig({
    required this.icon,
    required this.text,
    required this.url,
  });

  factory QuickActionConfig.fromJson(Map<String, dynamic> json) {
    return QuickActionConfig(
      icon: json['icon'] ?? 'bolt',
      text: json['text'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class PromoModalConfig {
  final String id;
  final String title;
  final String body;
  final String? ctaText;
  final String? ctaUrl;
  final bool dismissible;
  final DateTime? startAt;
  final DateTime? endAt;

  PromoModalConfig({
    required this.id,
    required this.title,
    required this.body,
    this.ctaText,
    this.ctaUrl,
    this.dismissible = true,
    this.startAt,
    this.endAt,
  });

  factory PromoModalConfig.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v as String);
      } catch (_) {
        return null;
      }
    }

    return PromoModalConfig(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      ctaText: json['ctaText'],
      ctaUrl: json['ctaUrl'],
      dismissible: json['dismissible'] ?? true,
      startAt: parseDate(json['startAt']),
      endAt: parseDate(json['endAt']),
    );
  }

  bool get isActive {
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }
}
