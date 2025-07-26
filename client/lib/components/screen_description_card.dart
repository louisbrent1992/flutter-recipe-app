import 'package:flutter/material.dart';
import '../theme/theme.dart';

class ScreenDescriptionCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String description;

  const ScreenDescriptionCard({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(
                AppBreakpoints.isMobile(context) ? 8 : 12,
              ),
              child: Image.network(
                imageUrl!,
                width: double.infinity,
                height: AppSizing.responsiveIconSize(
                  context,
                  mobile: 160,
                  tablet: 200,
                  desktop: 240,
                ),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: AppSizing.responsiveIconSize(
                      context,
                      mobile: 160,
                      tablet: 200,
                      desktop: 240,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.restaurant,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: AppSizing.responsiveIconSize(
                        context,
                        mobile: 40,
                        tablet: 48,
                        desktop: 56,
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: AppSpacing.responsive(context)),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: AppTypography.responsiveHeadingSize(context),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: TextStyle(
              fontSize: AppTypography.responsiveFontSize(context),
            ),
          ),
          SizedBox(height: AppSpacing.responsive(context)),
        ],
      ),
    );
  }
}
