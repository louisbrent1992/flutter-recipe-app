import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/dynamic_ui.dart';
import '../theme/theme.dart';

class DynamicBanner extends StatefulWidget {
  final DynamicBannerConfig banner;
  const DynamicBanner({super.key, required this.banner});

  @override
  State<DynamicBanner> createState() => _DynamicBannerState();
}

class _DynamicBannerState extends State<DynamicBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    try {
      return Color(int.parse(v, radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    final url = widget.banner.ctaUrl?.trim();
    if (url == null || url.isEmpty) return;

    String? appRouteRaw;
    if (url.startsWith('app://')) {
      appRouteRaw = url.substring(
        'app://'.length,
      ); // e.g. 'discover?tag=holiday' or '/discover?tag=holiday'
    } else if (url.startsWith('/')) {
      // Accept '/discover?tag=holiday'
      appRouteRaw = url.substring(1);
    } else if (!url.contains('://') &&
        (url.contains('?') || url.contains('/'))) {
      // Accept 'discover?tag=holiday' as app route
      appRouteRaw = url;
    }

    if (appRouteRaw != null) {
      final uri = Uri.parse(appRouteRaw);
      final routePath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
      final args = uri.queryParameters.isNotEmpty ? uri.queryParameters : null;
      Navigator.pushNamed(context, routePath, arguments: args);
      return;
    }

    // Fallback: open external link
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        _parseColor(widget.banner.backgroundColor) ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg =
        _parseColor(widget.banner.textColor) ??
        Theme.of(context).colorScheme.onSurface;

    final double radius = AppBreakpoints.isDesktop(context) ? 16 : 12;
    final bool hasImage =
        widget.banner.imageUrl != null && widget.banner.imageUrl!.isNotEmpty;

    // Responsive banner height based on screen size
    final double bannerHeight =
        AppBreakpoints.isDesktop(context)
            ? 290
            : AppBreakpoints.isTablet(context)
            ? 170
            : 96;

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppBreakpoints.isDesktop(context) ? 16 : 12,
      ),
      child: SizedBox(
        width: double.infinity,
        height: bannerHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Animated background (image Ken Burns or animated gradient)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  if (widget.banner.imageUrl != null &&
                      widget.banner.imageUrl!.isNotEmpty) {
                    final t = math.sin(2 * math.pi * _controller.value);
                    final scale = 1.05 + 0.03 * t; // subtle zoom in/out
                    final dx = 12.0 * t; // small pan
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: Transform.scale(
                        scale: scale,
                        child: Image.network(
                          widget.banner.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }

                  // Animated gradient background
                  final v = _controller.value;
                  final accent = fg.withValues(alpha: 0.08);
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [bg, accent],
                        begin: Alignment(-1 + 2 * v, -1),
                        end: Alignment(1 - 2 * v, 1),
                      ),
                    ),
                  );
                },
              ),

              // Foreground content with subtle border
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: fg.withValues(alpha: 0.15)),
                ),
                child:
                    hasImage
                        ? const SizedBox.shrink()
                        : Padding(
                          padding: EdgeInsets.all(
                            AppBreakpoints.isDesktop(context) ? 24 : 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.banner.title,
                                      style:
                                          AppBreakpoints.isDesktop(context)
                                              ? Theme.of(
                                                context,
                                              ).textTheme.titleLarge?.copyWith(
                                                color: fg,
                                                fontWeight: FontWeight.w700,
                                              )
                                              : Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                color: fg,
                                                fontWeight: FontWeight.w700,
                                              ),
                                    ),
                                    if (widget.banner.subtitle != null &&
                                        widget.banner.subtitle!.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top:
                                              AppBreakpoints.isDesktop(context)
                                                  ? 4
                                                  : 2,
                                        ),
                                        child: Text(
                                          widget.banner.subtitle!,
                                          style:
                                              AppBreakpoints.isDesktop(context)
                                                  ? Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: fg.withValues(
                                                          alpha: 0.8,
                                                        ),
                                                      )
                                                  : Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: fg.withValues(
                                                          alpha: 0.8,
                                                        ),
                                                      ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.banner.ctaText != null &&
                                  widget.banner.ctaText!.isNotEmpty)
                                TextButton(
                                  onPressed: () => _handleTap(context),
                                  style:
                                      AppBreakpoints.isDesktop(context)
                                          ? TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          )
                                          : null,
                                  child: Text(
                                    widget.banner.ctaText!,
                                    style: TextStyle(
                                      fontSize:
                                          AppBreakpoints.isDesktop(context)
                                              ? 16
                                              : 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
              ),
              // Tap layer to navigate
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _handleTap(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
