import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../services/google_image_service.dart';
import '../services/image_resolver_cache.dart';
import '../utils/image_utils.dart';
import '../theme/theme.dart';

const _imageUAHeaders = {
  'User-Agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

/// Displays a recipe image from [primaryImageUrl]. If the URL responds with
/// HTTP 403/404, attempts to fetch a Google Images result using [recipeTitle].
class SmartRecipeImage extends StatefulWidget {
  final String recipeTitle;
  final String? primaryImageUrl;
  final String? fallbackStaticUrl;
  final String? cacheKey; // e.g., recipe.id when not user-owned
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final void Function(String url)? onResolvedUrl;
  final VoidCallback? onRefreshStart;
  final void Function(String? newUrl)? onRefreshed;
  final bool showRefreshButton; // Control visibility of refresh button

  const SmartRecipeImage({
    super.key,
    required this.recipeTitle,
    this.primaryImageUrl,
    this.fallbackStaticUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.onResolvedUrl,
    this.onRefreshStart,
    this.onRefreshed,
    this.showRefreshButton = false, // Default to not showing refresh button
  });

  @override
  State<SmartRecipeImage> createState() => _SmartRecipeImageState();
}

class _SmartRecipeImageState extends State<SmartRecipeImage>
    with SingleTickerProviderStateMixin {
  String? _resolvedUrl;
  bool _checkedPrimary = false;
  late final AnimationController _spinController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bootstrapFromCacheThenResolve();
  }

  Future<void> _bootstrapFromCacheThenResolve() async {
    if (widget.cacheKey != null) {
      final cached = await ImageResolverCache.get(widget.cacheKey!);
      if (mounted && cached != null && cached.isNotEmpty) {
        setState(() => _resolvedUrl = cached);
      }
    }
    await _resolveImageUrl();
  }

  Future<void> _resolveImageUrl() async {
    final primary = widget.primaryImageUrl;

    // If primary looks invalid or not network, skip HEAD and use fallback or null
    if (primary == null || !ImageUtils.isValidImageUrl(primary)) {
      await _tryGoogleFallback();
      return;
    }

    try {
      final uri = Uri.parse(primary);
      final response = await http
          .head(uri, headers: _imageUAHeaders)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => http.Response('', 408),
          );

      _checkedPrimary = true;

      if (response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 404) {
        await _tryGoogleFallback();
        return;
      }

      if (mounted) {
        setState(() => _resolvedUrl = primary);
        widget.onResolvedUrl?.call(primary);
        if (widget.cacheKey != null) {
          unawaited(ImageResolverCache.set(widget.cacheKey!, primary));
        }
      }
    } catch (_) {
      await _tryGoogleFallback();
    }
  }

  Future<void> _tryGoogleFallback() async {
    final googleUrl = await GoogleImageService.fetchImageForQuery(
      '${widget.recipeTitle} recipe',
    );

    final resolved = googleUrl ?? widget.fallbackStaticUrl;
    if (mounted) {
      setState(() {
        _resolvedUrl = resolved;
      });
      if (resolved != null && resolved.isNotEmpty) {
        widget.onResolvedUrl?.call(resolved);
        if (widget.cacheKey != null) {
          unawaited(ImageResolverCache.set(widget.cacheKey!, resolved));
        }
        widget.onRefreshed?.call(resolved);
      }
    }
  }

  Future<void> _forceRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _spinController.repeat();
    widget.onRefreshStart?.call();
    // Try a different result set by advancing the start index
    final alt = await GoogleImageService.fetchImageForQuery(
      '${widget.recipeTitle} recipe',
      start: 4,
    );
    final resolved = alt ?? widget.fallbackStaticUrl;
    if (!mounted) return;
    setState(() {
      _resolvedUrl = resolved;
    });
    if (resolved != null && resolved.isNotEmpty) {
      widget.onResolvedUrl?.call(resolved);
      if (widget.cacheKey != null) {
        unawaited(ImageResolverCache.set(widget.cacheKey!, resolved));
      }
    }
    widget.onRefreshed?.call(resolved);
    _spinController.stop();
    _spinController.reset();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.placeholder ?? const Center(child: CircularProgressIndicator());
    final error =
        widget.errorWidget ??
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.restaurant,
            size: AppSizing.responsiveIconSize(
              context,
              mobile: 40,
              tablet: 48,
              desktop: 56,
            ),
            color: Theme.of(context).colorScheme.primary,
          ),
        );

    final url =
        _resolvedUrl ?? widget.primaryImageUrl ?? widget.fallbackStaticUrl;

    if (url == null || url.isEmpty) {
      return error;
    }

    return GestureDetector(
      onTap: () => _showExpandedImage(context, url),
      child: ClipRRect(
        borderRadius:
            widget.borderRadius ??
            BorderRadius.circular(AppBreakpoints.isMobile(context) ? 8 : 12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              memCacheWidth:
                  (widget.width != null) ? widget.width!.toInt() : null,
              memCacheHeight:
                  (widget.height != null) ? widget.height!.toInt() : null,
              fadeInDuration: const Duration(milliseconds: 150),
              fadeOutDuration: const Duration(milliseconds: 100),
              placeholder: (context, u) => placeholder,
              errorWidget: (context, u, err) {
                if (!_checkedPrimary && u == widget.primaryImageUrl) {
                  scheduleMicrotask(() => _tryGoogleFallback());
                }
                return error;
              },
            ),
            if (widget.showRefreshButton)
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  message: 'Find a different image',
                  child: GestureDetector(
                    onTap: _isRefreshing ? null : _forceRefresh,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: RotationTransition(
                        turns: _spinController,
                        child: Icon(
                          Icons.image_search,
                          size: AppSizing.responsiveIconSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showExpandedImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ExpandedImageView(imageUrl: imageUrl, animation: animation);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _ExpandedImageView extends StatefulWidget {
  final String imageUrl;
  final Animation<double> animation;

  const _ExpandedImageView({required this.imageUrl, required this.animation});

  @override
  State<_ExpandedImageView> createState() => _ExpandedImageViewState();
}

class _ExpandedImageViewState extends State<_ExpandedImageView>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        onDoubleTap: _resetZoom,
        child: Container(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gesture detector for pinch-to-zoom
              GestureDetector(
                onScaleStart: (details) {
                  setState(() {});
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = (_scale * details.scale).clamp(1.0, 4.0);
                    _offset += details.focalPointDelta;
                  });
                },
                onScaleEnd: (details) {
                  if (_scale < 1.1) {
                    _resetZoom();
                  }
                },
                child: Center(
                  child: Transform.translate(
                    offset: _offset,
                    child: Transform.scale(
                      scale: _scale,
                      alignment: Alignment.center,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.contain,
                          placeholder:
                              (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          errorWidget:
                              (context, url, error) => const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Instructions
              if (_scale > 1.1)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Double tap to reset zoom',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
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
