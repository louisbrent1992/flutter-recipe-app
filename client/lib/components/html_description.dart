import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

class HtmlDescription extends StatelessWidget {
  final String htmlContent;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  const HtmlDescription({
    super.key,
    required this.htmlContent,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    // For truncated text, we use a different approach
    if (maxLines != null) {
      return Html(
        data: htmlContent,
        style: {
          'body': Style(
            fontSize:
                style?.fontSize != null
                    ? FontSize(style!.fontSize!)
                    : FontSize.medium,
            color: style?.color,
            fontWeight:
                style?.fontWeight == FontWeight.bold
                    ? FontWeight.bold
                    : FontWeight.normal,
            maxLines: maxLines,
            textOverflow: overflow,
          ),
          'b': Style(fontWeight: FontWeight.bold),
          'a': Style(
            color: Theme.of(context).colorScheme.primary,
            textDecoration: TextDecoration.underline,
          ),
        },
        onAnchorTap: (url, attributes, element) {
          if (url != null) {
            _launchURL(url);
          }
        },
      );
    }

    // Full text rendering
    return Html(
      data: htmlContent,
      style: {
        'body': Style(
          fontSize:
              style?.fontSize != null
                  ? FontSize(style!.fontSize!)
                  : FontSize.medium,
          color: style?.color,
          fontWeight:
              style?.fontWeight == FontWeight.bold
                  ? FontWeight.bold
                  : FontWeight.normal,
        ),
        'b': Style(fontWeight: FontWeight.bold),
        'a': Style(
          color: Theme.of(context).colorScheme.primary,
          textDecoration: TextDecoration.underline,
        ),
      },
      onAnchorTap: (url, attributes, element) {
        if (url != null) {
          _launchURL(url);
        }
      },
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }
}
