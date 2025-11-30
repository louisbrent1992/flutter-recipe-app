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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<Alignment> _beginAlign;
  late final Animation<Alignment> _endAlign;

  @override
  void initState() {
    super.initState();
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicUiProvider>(
      builder: (context, dyn, _) {
        final DynamicBackgroundConfig? bg = dyn.config?.globalBackground;
        if (bg == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final double overlayOpacity = (bg.opacity ?? 1.0).clamp(0.0, 1.0);

        return Positioned.fill(
          child: IgnorePointer(
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
                else if (bg.hasGradient)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      var colors =
                          bg.colors
                              .map(_parseColor)
                              .whereType<Color>()
                              .toList();
                      if (colors.length < 2) return const SizedBox.shrink();
                      
                      // Darken colors for dark mode
                      if (isDarkMode) {
                        colors = colors.map((c) => _darkenColor(c, 0.6)).toList();
                      }
                      
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
          ),
        );
      },
    );
  }
  
  /// Darken a color by a given factor (0.0 = black, 1.0 = original)
  Color _darkenColor(Color color, double factor) {
    return Color.fromARGB(
      (color.a * 255.0).round() & 0xff,
      ((color.r * 255.0).round() * factor).round() & 0xff,
      ((color.g * 255.0).round() * factor).round() & 0xff,
      ((color.b * 255.0).round() * factor).round() & 0xff,
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
