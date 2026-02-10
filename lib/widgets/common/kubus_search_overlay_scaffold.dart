import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/map_search_suggestion.dart';
import '../glass_components.dart';
import '../map_overlay_blocker.dart';
import '../search/kubus_search_bar.dart';

enum KubusSearchOverlayLayout {
  topOverlay,
  sidePanel,
}

/// Shared scaffold for map search UI and suggestions overlay.
class KubusSearchOverlayScaffold extends StatelessWidget {
  const KubusSearchOverlayScaffold({
    super.key,
    required this.layout,
    required this.searchField,
    required this.searchFieldLink,
    required this.showSuggestions,
    required this.query,
    required this.isFetching,
    required this.suggestions,
    required this.accentColor,
    required this.minCharsHint,
    required this.noResultsText,
    required this.onDismissSuggestions,
    required this.onSuggestionTap,
    this.leading,
    this.filterChips,
    this.mapToggle,
    this.extraContent,
    this.panelInsets = const EdgeInsets.fromLTRB(12, 10, 12, 0),
    this.maxWidth = 420,
    this.rightInset = 0,
    this.useSafeTopPadding = true,
    this.sectionGap = 10,
    this.sidePanelInnerPadding = const EdgeInsets.symmetric(
      horizontal: KubusSpacing.md + KubusSpacing.xs,
      vertical: KubusSpacing.md,
    ),
    this.sidePanelRadius = KubusRadius.lg,
    this.sidePanelAnimated = false,
    this.positionAnimationDuration = const Duration(milliseconds: 240),
    this.positionAnimationCurve = Curves.easeOutCubic,
    this.suggestionsOffset = const Offset(0, 52),
    this.suggestionsMaxWidth = 520,
    this.suggestionsMaxHeight = 360,
  });

  final KubusSearchOverlayLayout layout;
  final Widget searchField;
  final LayerLink searchFieldLink;
  final bool showSuggestions;
  final String query;
  final bool isFetching;
  final List<MapSearchSuggestion> suggestions;
  final Color accentColor;
  final String minCharsHint;
  final String noResultsText;
  final VoidCallback onDismissSuggestions;
  final ValueChanged<MapSearchSuggestion> onSuggestionTap;

  final Widget? leading;
  final Widget? filterChips;
  final Widget? mapToggle;
  final Widget? extraContent;

  final EdgeInsets panelInsets;
  final double maxWidth;
  final double rightInset;
  final bool useSafeTopPadding;
  final double sectionGap;

  final EdgeInsets sidePanelInnerPadding;
  final double sidePanelRadius;
  final bool sidePanelAnimated;
  final Duration positionAnimationDuration;
  final Curve positionAnimationCurve;

  final Offset suggestionsOffset;
  final double suggestionsMaxWidth;
  final double suggestionsMaxHeight;

  @override
  Widget build(BuildContext context) {
    final topInset = panelInsets.top +
        (useSafeTopPadding ? MediaQuery.of(context).padding.top : 0);

    return Positioned.fill(
      child: Stack(
        children: [
          if (layout == KubusSearchOverlayLayout.topOverlay)
            Positioned(
              top: topInset,
              left: panelInsets.left,
              right: panelInsets.right,
              child: MapOverlayBlocker(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _buildTopOverlayContent(),
                  ),
                ),
              ),
            ),
          if (layout == KubusSearchOverlayLayout.sidePanel)
            _buildSidePanel(context, topInset),
          if (showSuggestions)
            KubusSearchSuggestionsOverlay(
              link: searchFieldLink,
              query: query,
              isFetching: isFetching,
              suggestions: suggestions,
              accentColor: accentColor,
              minCharsHint: minCharsHint,
              noResultsText: noResultsText,
              onDismiss: onDismissSuggestions,
              onSuggestionTap: onSuggestionTap,
              offset: suggestionsOffset,
              maxWidth: suggestionsMaxWidth,
              maxHeight: suggestionsMaxHeight,
            ),
        ],
      ),
    );
  }

  Widget _buildTopOverlayContent() {
    final children = <Widget>[
      searchField,
      if (filterChips != null) ...[
        SizedBox(height: sectionGap),
        filterChips!,
      ],
      if (mapToggle != null) ...[
        SizedBox(height: sectionGap),
        mapToggle!,
      ],
      if (extraContent != null) ...[
        SizedBox(height: sectionGap),
        extraContent!,
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildSidePanel(BuildContext context, double topInset) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final panel = MapOverlayBlocker(
      cursor: SystemMouseCursors.basic,
      child: Padding(
        padding: EdgeInsets.only(
          left: panelInsets.left,
          right: panelInsets.right,
        ),
        child: LiquidGlassPanel(
          padding: sidePanelInnerPadding,
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(sidePanelRadius),
          blurSigma: KubusGlassEffects.blurSigmaLight,
          backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.20 : 0.14),
          showBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    SizedBox(width: KubusSpacing.xl + KubusSpacing.sm),
                  ],
                  Expanded(child: searchField),
                  if (filterChips != null) ...[
                    SizedBox(width: KubusSpacing.md + KubusSpacing.xs),
                    filterChips!,
                  ],
                  if (mapToggle != null) ...[
                    SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                    mapToggle!,
                  ],
                ],
              ),
              if (extraContent != null) ...[
                SizedBox(height: sectionGap),
                extraContent!,
              ],
            ],
          ),
        ),
      ),
    );

    if (!sidePanelAnimated) {
      return Positioned(
        top: topInset,
        left: 0,
        right: rightInset,
        child: panel,
      );
    }

    return AnimatedPositioned(
      duration: positionAnimationDuration,
      curve: positionAnimationCurve,
      top: topInset,
      left: 0,
      right: rightInset,
      child: panel,
    );
  }
}
