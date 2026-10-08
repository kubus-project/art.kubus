import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Feed caption that collapses after a few lines, with `more` and `less`.
///
/// Whether a caption is long is decided by measuring the laid-out text at the
/// current width and text scale, not by counting characters. A caption that
/// fits the preview shows neither control. The full text is kept as-is and is
/// only visually clipped, and expanding it does not affect any sibling media.
class CommunityPostCaption extends StatefulWidget {
  const CommunityPostCaption({
    super.key,
    required this.text,
    required this.style,
    this.hasMedia = false,
    this.initiallyExpanded = false,
    this.onTap,
  });

  static const int mediaPreviewLines = 4;
  static const int textPreviewLines = 8;

  final String text;
  final TextStyle style;

  /// Captions over media collapse sooner, so the artwork stays in view.
  final bool hasMedia;

  /// Starts with the complete text, for surfaces that show the whole post.
  final bool initiallyExpanded;

  /// Tapping the caption body (not the more/less control).
  final VoidCallback? onTap;

  @override
  State<CommunityPostCaption> createState() => _CommunityPostCaptionState();
}

class _CommunityPostCaptionState extends State<CommunityPostCaption> {
  late bool _expanded = widget.initiallyExpanded;

  int get _previewLines => widget.hasMedia
      ? CommunityPostCaption.mediaPreviewLines
      : CommunityPostCaption.textPreviewLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final effectiveStyle =
        DefaultTextStyle.of(context).style.merge(widget.style);
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: effectiveStyle),
          maxLines: _previewLines,
          textDirection: direction,
          textScaler: textScaler,
          locale: locale,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        final collapsed = overflows && !_expanded;
        final body = Text(
          widget.text,
          style: widget.style,
          maxLines: collapsed ? _previewLines : null,
          overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.visible,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onTap != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: body,
              )
            else
              body,
            if (overflows)
              Semantics(
                button: true,
                expanded: _expanded,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: scheme.primary,
                  ),
                  child: Text(
                    _expanded
                        ? l10n.communityPostShowLess
                        : l10n.communityPostShowMore,
                    style: effectiveStyle.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
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
