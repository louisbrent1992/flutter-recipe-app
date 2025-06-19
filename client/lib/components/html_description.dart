import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class HtmlDescription extends StatefulWidget {
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
  State<HtmlDescription> createState() => _HtmlDescriptionState();
}

class _HtmlDescriptionState extends State<HtmlDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // For truncated text, we use a different approach
    if (widget.maxLines != null && !_isExpanded) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = true;
          });
        },
        child: Html(
          data: widget.htmlContent,
          style: {
            'body': Style(
              fontSize:
                  widget.style?.fontSize != null
                      ? FontSize(widget.style!.fontSize!)
                      : FontSize.medium,
              color: widget.style?.color,
              fontWeight:
                  widget.style?.fontWeight == FontWeight.bold
                      ? FontWeight.bold
                      : FontWeight.normal,
              maxLines: widget.maxLines,
              textOverflow: widget.overflow,
            ),
            'b': Style(fontWeight: FontWeight.bold),
            'a': Style(color: Theme.of(context).colorScheme.primary),
          },
        ),
      );
    }

    // Full text rendering
    return GestureDetector(
      onTap: () {
        if (widget.maxLines != null) {
          setState(() {
            _isExpanded = false;
          });
        }
      },
      child: Html(
        data: widget.htmlContent,
        style: {
          'body': Style(
            fontSize:
                widget.style?.fontSize != null
                    ? FontSize(widget.style!.fontSize!)
                    : FontSize.medium,
            color: widget.style?.color,
            fontWeight:
                widget.style?.fontWeight == FontWeight.bold
                    ? FontWeight.bold
                    : FontWeight.normal,
          ),
          'b': Style(fontWeight: FontWeight.bold),
          'a': Style(color: Theme.of(context).colorScheme.primary),
        },
      ),
    );
  }
}
