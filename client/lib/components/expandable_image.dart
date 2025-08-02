import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/theme.dart';

class ExpandableImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ExpandableImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showExpandedImage(context),
      child: ClipRRect(
        borderRadius:
            borderRadius ??
            BorderRadius.circular(AppBreakpoints.isMobile(context) ? 8 : 12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          placeholder:
              (context, url) =>
                  placeholder ??
                  const Center(child: CircularProgressIndicator()),
          errorWidget:
              (context, url, error) =>
                  errorWidget ??
                  Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  ),
        ),
      ),
    );
  }

  void _showExpandedImage(BuildContext context) {
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
  Offset _focalPoint = Offset.zero;
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
        onTap: () => Navigator.of(context).pop(),
        onDoubleTap: _resetZoom,
        onScaleStart: (details) {
          _focalPoint = details.focalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            _scale = details.scale.clamp(0.5, 3.0);
            _offset = details.focalPoint - _focalPoint;
          });
        },
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Close button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
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
                ),
              ),
              // Zoom reset button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: GestureDetector(
                  onTap: _resetZoom,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.zoom_out,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              // Image
              Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.translate(
                        offset: _offset,
                        child: Transform.scale(
                          scale: _scale,
                          child: InteractiveViewer(
                            boundaryMargin: const EdgeInsets.all(20),
                            minScale: 0.5,
                            maxScale: 3.0,
                            child: CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.contain,

                              placeholder:
                                  (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    child: const Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
