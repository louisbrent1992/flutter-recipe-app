class DynamicUiConfig {
  final int version;
  final DateTime fetchedAt;
  final List<DynamicBannerConfig> banners;
  final DynamicBackgroundConfig? globalBackground;
  final String? heroImageUrl; // Home screen hero image
  final String? welcomeMessage; // Customizable welcome message (supports {username} placeholder)
  final String? heroSubtitle; // Customizable hero subtitle text
  final Map<String, bool>? sectionVisibility; // Toggle visibility of home screen sections

  DynamicUiConfig({
    required this.version,
    required this.fetchedAt,
    required this.banners,
    this.globalBackground,
    this.heroImageUrl,
    this.welcomeMessage,
    this.heroSubtitle,
    this.sectionVisibility,
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
      globalBackground:
          json['globalBackground'] != null
              ? DynamicBackgroundConfig.fromJson(
                json['globalBackground'] as Map<String, dynamic>,
              )
              : null,
      heroImageUrl: json['heroImageUrl'] as String?,
      welcomeMessage: json['welcomeMessage'] as String?,
      heroSubtitle: json['heroSubtitle'] as String?,
      sectionVisibility: json['sectionVisibility'] != null
          ? Map<String, bool>.from(
              json['sectionVisibility'] as Map,
            )
          : null,
    );
  }
  
  // Helper method to check if a section should be visible
  bool isSectionVisible(String sectionKey, {bool defaultVisibility = true}) {
    return sectionVisibility?[sectionKey] ?? defaultVisibility;
  }
  
  // Helper method to format welcome message with username
  String formatWelcomeMessage(String username) {
    if (welcomeMessage == null || welcomeMessage!.isEmpty) {
      return 'Welcome,';
    }
    return welcomeMessage!.replaceAll('{username}', username);
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
  final String? query; // Search query for discover screen (similar to notifications)
  final String? displayQuery; // Display name for query (similar to notifications)

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
    this.query,
    this.displayQuery,
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
      query: json['query'],
      displayQuery: json['displayQuery'],
    );
  }

  bool get isActive {
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }
}

class DynamicBackgroundConfig {
  final String? imageUrl;
  final List<String> colors; // hex strings
  final bool animateGradient;
  final bool kenBurns;
  final double? opacity; // 0.0 - 1.0 overlay opacity for image/gradient

  const DynamicBackgroundConfig({
    this.imageUrl,
    this.colors = const [],
    this.animateGradient = true,
    this.kenBurns = true,
    this.opacity,
  });

  factory DynamicBackgroundConfig.fromJson(Map<String, dynamic> json) {
    final rawColors = (json['colors'] as List?)?.cast<String>() ?? const [];
    return DynamicBackgroundConfig(
      imageUrl: json['imageUrl'] as String?,
      colors: rawColors,
      animateGradient: (json['animateGradient'] ?? true) as bool,
      kenBurns: (json['kenBurns'] ?? true) as bool,
      opacity:
          (json['opacity'] is num) ? (json['opacity'] as num).toDouble() : null,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasGradient => colors.length >= 2;
  bool get hasSolidColor => colors.length == 1;
}
