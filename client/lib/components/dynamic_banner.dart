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
    with TickerProviderStateMixin {
  late final AnimationController _kenBurnsController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _imageLoaded = false;
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();
    _hasImage = widget.banner.imageUrl != null &&
        widget.banner.imageUrl!.isNotEmpty;
    
    // Ken Burns animation controller (only for image banners)
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    
    // Fade-in animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    // Start fade-in animation
    _fadeController.forward();
    
    // Only start Ken Burns animation after image loads (if applicable)
    if (!_hasImage) {
      _kenBurnsController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _kenBurnsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  
  void _onImageLoaded() {
    if (mounted && !_imageLoaded) {
      setState(() {
        _imageLoaded = true;
      });
      // Start Ken Burns animation after image is loaded
      _kenBurnsController.repeat(reverse: true);
    }
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
      
      // Build arguments map, prioritizing query and displayQuery from banner config
      Map<String, dynamic> args = {};
      
      // If banner has query and displayQuery, use those (similar to notifications)
      if (widget.banner.query != null && widget.banner.query!.isNotEmpty) {
        args['query'] = widget.banner.query;
        if (widget.banner.displayQuery != null && widget.banner.displayQuery!.isNotEmpty) {
          args['displayQuery'] = widget.banner.displayQuery;
        }
      } else {
        // Fallback to query parameters from URL (for backward compatibility)
        if (uri.queryParameters.isNotEmpty) {
          args = Map<String, dynamic>.from(uri.queryParameters);
          // Convert 'tag' to 'query' for backward compatibility
          if (args.containsKey('tag') && !args.containsKey('query')) {
            args['query'] = args['tag'];
            args.remove('tag');
          }
        }
      }
      
      Navigator.pushNamed(
        context,
        routePath,
        arguments: args.isNotEmpty ? args : null,
      );
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
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
                  animation: _kenBurnsController,
                  builder: (context, _) {
                    if (_hasImage) {
                      final t = math.sin(2 * math.pi * _kenBurnsController.value);
                      final scale = 1.05 + 0.03 * t; // subtle zoom in/out
                      final dx = 12.0 * t; // small pan
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Placeholder background while image loads
                          Container(
                            decoration: BoxDecoration(
                              color: bg,
                            ),
                          ),
                          // Image with Ken Burns effect
                          Transform.translate(
                            offset: _imageLoaded ? Offset(dx, 0) : Offset.zero,
                            child: Transform.scale(
                              scale: _imageLoaded ? scale : 1.0,
                              child: Image.network(
                                widget.banner.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    // Image loaded, trigger callback to start animation
                                    if (!_imageLoaded) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _onImageLoaded();
                                      });
                                    }
                                    return child;
                                  }
                                  // Show placeholder while loading
                                  return Container(
                                    color: bg,
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  // Show gradient background on error
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [bg, fg.withValues(alpha: 0.08)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Animated gradient background
                    final v = _kenBurnsController.value;
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

              // Foreground content
              Container(
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
      ),
    );
  }
}
