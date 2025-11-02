class DynamicUiConfig {
  final int version;
  final DateTime fetchedAt;
  final List<DynamicBannerConfig> banners;

  DynamicUiConfig({
    required this.version,
    required this.fetchedAt,
    required this.banners,
  });

  factory DynamicUiConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> bannerList = json['banners'] ?? [];
    return DynamicUiConfig(
      version: (json['version'] ?? 1) as int,
      fetchedAt: DateTime.tryParse(json['fetchedAt'] ?? '') ?? DateTime.now(),
      banners: bannerList
          .map((e) => DynamicBannerConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
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


