import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dynamic_ui.dart';
import '../providers/dynamic_ui_provider.dart';

class DynamicGlobalBackground extends StatefulWidget {
  const DynamicGlobalBackground({super.key});

  @override
  State<DynamicGlobalBackground> createState() =>
      _DynamicGlobalBackgroundState();
}

class _DynamicGlobalBackgroundState extends State<DynamicGlobalBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<Alignment> _beginAlign;
  late final Animation<Alignment> _endAlign;
  bool _wasAnimatingBeforeKeyboard = false;
  
  // Dark blue gradient colors for dark mode animation
  static const List<Color> _darkModeGradientColors = [
    Color(0xFF1E2A44), // Deep dark blue
    Color(0xFF2D3A5C), // Slightly lighter dark blue
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(
      begin: 1.05,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _beginAlign = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _endAlign = AlignmentTween(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Detect keyboard visibility by checking bottom view insets
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    
    if (bottomInset > 0) {
      // Keyboard is visible - pause animation to prevent stuttering
      if (_controller.isAnimating) {
        _wasAnimatingBeforeKeyboard = true;
        _controller.stop();
      }
    } else {
      // Keyboard is hidden - resume animation if it was running before
      if (_wasAnimatingBeforeKeyboard && !_controller.isAnimating) {
        _controller.repeat(reverse: true);
        _wasAnimatingBeforeKeyboard = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // DEBUG: Return static gradient to test if animation causes stuttering after login/logout
    const bool useStaticBackground = true;
    
    if (useStaticBackground) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final colors = isDarkMode 
          ? _darkModeGradientColors 
          : const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)];
      
      return IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
      );
    }
    
    return Consumer<DynamicUiProvider>(
      builder: (context, dyn, _) {
        final DynamicBackgroundConfig? bg = dyn.config?.globalBackground;
        if (bg == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final double overlayOpacity = (bg.opacity ?? 1.0).clamp(0.0, 1.0);

        // Note: This widget should be placed inside a Positioned.fill or SizedBox.expand
        // when used in a Stack to ensure it fills the available space
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bg.hasImage)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final double scale = bg.kenBurns ? _scaleAnim.value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Image.network(
                        bg.imageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        color: isDarkMode ? Colors.black.withValues(alpha: 0.3) : null,
                        colorBlendMode: isDarkMode ? BlendMode.darken : null,
                      ),
                    );
                  },
                )
              else if (bg.hasGradient || isDarkMode)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    // Use dark blue gradient colors for dark mode
                    final List<Color> colors = isDarkMode
                        ? _darkModeGradientColors
                        : bg.colors
                            .map(_parseColor)
                            .whereType<Color>()
                            .toList();
                    
                    if (colors.length < 2) return const SizedBox.shrink();
                    
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin:
                              bg.animateGradient
                                  ? _beginAlign.value
                                  : Alignment.topLeft,
                          end:
                              bg.animateGradient
                                  ? _endAlign.value
                                  : Alignment.bottomRight,
                          colors: colors,
                        ),
                      ),
                    );
                  },
                )
              else if (bg.hasSolidColor)
                Container(
                  color: _parseColor(
                    bg.colors.first,
                  )?.withValues(alpha: overlayOpacity),
                ),

              if (bg.hasImage && overlayOpacity < 1.0)
                Container(
                  color: Colors.black.withValues(alpha: 1.0 - overlayOpacity),
                ),
                
              // Additional darkening overlay for dark mode images
              if (bg.hasImage && isDarkMode)
                Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
            ],
          ),
        );
      },
    );
  }

  Color? _parseColor(String hex) {
    String cleaned = hex.replaceAll('#', '').toUpperCase();
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    if (cleaned.length != 8) return null;
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(value);
  }
}
