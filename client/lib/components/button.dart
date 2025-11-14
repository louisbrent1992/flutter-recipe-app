import 'package:flutter/material.dart';
import '../theme/theme.dart';

class Button extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool showShadow;
  final IconData icon;
  final String? tooltip;
  final String? position;

  const Button({
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 40, // Can be overridden, but defaults will be responsive in build
    this.iconSize = 24, // Can be overridden, but defaults will be responsive in build
    this.showShadow = true,
    this.icon = Icons.home_rounded,
    this.tooltip,
    this.position,
  });

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
      if (isHovered) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final iconColor = widget.iconColor ?? theme.colorScheme.onPrimary;

    // Make sizes responsive - scale based on screen size
    final responsiveSize = AppBreakpoints.isDesktop(context)
        ? widget.size * 1.25
        : AppBreakpoints.isTablet(context)
            ? widget.size * 1.1
            : widget.size;
    
    final responsiveIconSize = AppBreakpoints.isDesktop(context)
        ? widget.iconSize * 1.25
        : AppBreakpoints.isTablet(context)
            ? widget.iconSize * 1.1
            : widget.iconSize;

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: EdgeInsets.all(AppSpacing.responsive(context)),
              clipBehavior: Clip.antiAlias,
              width: responsiveSize,
              height: responsiveSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                boxShadow:
                    widget.showShadow
                        ? [
                          BoxShadow(
                            color: backgroundColor.withValues(
                              alpha: _isHovered ? 0.3 : 0.2,
                            ),
                            blurRadius:
                                _isHovered
                                    ? AppElevation.responsive(
                                      context,
                                      mobile: 6,
                                      tablet: 8,
                                      desktop: 10,
                                    )
                                    : AppElevation.responsive(
                                      context,
                                      mobile: 3,
                                      tablet: 5,
                                      desktop: 7,
                                    ),
                            offset: Offset(
                              0,
                              _isHovered
                                  ? AppBreakpoints.isMobile(context)
                                      ? 2
                                      : 3
                                  : AppBreakpoints.isMobile(context)
                                  ? 1
                                  : 2,
                            ),
                          ),
                        ]
                        : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  child: Center(
                    child: IconButton(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppBreakpoints.isDesktop(context)
                                  ? 12
                                  : AppBreakpoints.isTablet(context)
                                      ? 10
                                      : 8,
                            ),
                          ),
                        ),
                      ),
                      icon: Icon(
                        widget.icon,
                        color: iconColor,
                        size: responsiveIconSize,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: responsiveSize,
                        minHeight: responsiveSize,
                      ),
                      onPressed: widget.onPressed,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
