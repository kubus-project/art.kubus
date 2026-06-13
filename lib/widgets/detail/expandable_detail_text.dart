import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'detail_shell_tokens.dart';

/// Editorial body text for detail screens that clamps long descriptions and
/// lets the reader expand them in place.
///
/// Collapsed text fades out over its last line (an alpha fade on the glyphs
/// themselves, so it works on any LiquidGlass background) and a localized
/// "Show more" / "Show less" toggle switches between states. Text that fits
/// within [collapsedMaxLines] renders as plain text without a toggle.
class ExpandableDetailText extends StatefulWidget {
  const ExpandableDetailText({
    super.key,
    required this.text,
    this.collapsedMaxLines = 8,
    this.style,
  });

  final String text;
  final int collapsedMaxLines;
  final TextStyle? style;

  @override
  State<ExpandableDetailText> createState() => _ExpandableDetailTextState();
}

class _ExpandableDetailTextState extends State<ExpandableDetailText> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final style = widget.style ?? DetailTypography.body(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: widget.collapsedMaxLines,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        if (!overflows) {
          return Text(widget.text, style: style);
        }

        Widget body = Text(
          widget.text,
          style: style,
          maxLines: _expanded ? null : widget.collapsedMaxLines,
          overflow: _expanded ? null : TextOverflow.clip,
        );

        if (!_expanded) {
          // Alpha-fade the final line of the clamped text so the cut feels
          // soft without painting an opaque layer over the glass surface.
          body = ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [
                0.0,
                ((bounds.height - 28) / bounds.height).clamp(0.0, 1.0),
                1.0
              ],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: body,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: body,
            ),
            const SizedBox(height: DetailSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _toggle,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DetailSpacing.sm,
                    vertical: DetailSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.primary,
                ),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _expanded ? l10n.detailShowLess : l10n.detailShowMore,
                  style: DetailTypography.button(context).copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
