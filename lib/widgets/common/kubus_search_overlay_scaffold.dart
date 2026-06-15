import 'package:flutter/material.dart';

import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../map/kubus_map_glass_surface.dart';
import '../map_overlay_blocker.dart';

enum KubusSearchOverlayLayout {
  topOverlay,
  sidePanel,
}

enum KubusSearchSidePanelSurfaceMode {
  glassHost,
  hostless,
}

/// Shared scaffold for map search UI and suggestions overlay.
class KubusSearchOverlayScaffold extends StatelessWidget {
  const KubusSearchOverlayScaffold({
    super.key,
    required this.layout,
    required this.searchField,
    this.searchDropdown,
    this.leading,
    this.filterChips,
    this.mapToggle,
    this.extraContent,
    this.panelInsets = const EdgeInsets.fromLTRB(
      KubusSpacing.sm,
      KubusSpacing.sm,
      KubusSpacing.sm,
      0,
    ),
    this.maxWidth = 420,
    this.rightInset = 0,
    this.useSafeTopPadding = true,
    this.sectionGap = KubusSpacing.sm,
    this.sidePanelInnerPadding = const EdgeInsets.symmetric(
      horizontal: KubusSpacing.md + KubusSpacing.xs,
      vertical: KubusSpacing.md,
    ),
    this.sidePanelSurfaceMode = KubusSearchSidePanelSurfaceMode.glassHost,
    this.sidePanelRadius = KubusRadius.lg,
    this.sidePanelAnimated = false,
    this.positionAnimationDuration,
    this.positionAnimationCurve,
    this.topOverlayFieldWidth,
    this.sidePanelFieldWidth,
    this.sidePanelSearchExpanded = false,
    this.widthAnimationDuration,
    this.widthAnimationCurve,
  });

  final KubusSearchOverlayLayout layout;
  final Widget searchField;
  final Widget? searchDropdown;

  /// When set (top-overlay layout only), the search field animates to this
  /// resolved width and is left-aligned within the overlay column. Extra
  /// content (filters, discovery) keeps the full column width. Pass the same
  /// value to the results dropdown so both share one width contract.
  final double? topOverlayFieldWidth;

  /// When set (side-panel layout only), the search field is laid out at this
  /// resolved width inside a [Wrap] search row, animating between a comfortable
  /// idle width and an expanded focused width (growing toward the right). Pass
  /// the same value to the results dropdown so both share one width contract.
  /// When null the side panel keeps its legacy [Expanded] field layout.
  final double? sidePanelFieldWidth;

  /// Whether the side-panel search is focused / has an active query. When true
  /// the quick-filter chips collapse so the field can expand to the right.
  final bool sidePanelSearchExpanded;
  final Duration? widthAnimationDuration;
  final Curve? widthAnimationCurve;

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
  final KubusSearchSidePanelSurfaceMode sidePanelSurfaceMode;
  final double sidePanelRadius;
  final bool sidePanelAnimated;

  /// Panel motion; falls back to [AppAnimationTheme.medium] when unset.
  final Duration? positionAnimationDuration;
  final Curve? positionAnimationCurve;

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
                    child: _buildTopOverlayContent(context),
                  ),
                ),
              ),
            ),
          if (layout == KubusSearchOverlayLayout.sidePanel)
            _buildSidePanel(context, topInset),
          if (searchDropdown != null) searchDropdown!,
        ],
      ),
    );
  }

  Widget _buildTopOverlayContent(BuildContext context) {
    final field = topOverlayFieldWidth == null
        ? searchField
        : Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: widthAnimationDuration ?? context.animationTheme.medium,
              curve: widthAnimationCurve ?? context.animationTheme.defaultCurve,
              width: topOverlayFieldWidth,
              child: searchField,
            ),
          );
    final children = <Widget>[
      field,
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

  /// The side-panel search row (leading + field + quick filters + toggle).
  ///
  /// When [sidePanelFieldWidth] is set (the map assembly path) the field is
  /// laid out at the resolved width inside a [Wrap] so it can animate between a
  /// comfortable idle width and an expanded focused width, the quick filters
  /// collapse while focused, and the row reflows (filters drop below) on
  /// smaller desktops instead of overflowing. When null it keeps the legacy
  /// [Expanded] layout for any direct callers.
  Widget _buildSidePanelSearchRow(BuildContext context) {
    final fieldWidth = sidePanelFieldWidth;
    if (fieldWidth == null) {
      return Row(
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
      );
    }

    final animationTheme = context.animationTheme;
    final field = AnimatedContainer(
      duration: widthAnimationDuration ?? animationTheme.medium,
      curve: widthAnimationCurve ?? animationTheme.defaultCurve,
      width: fieldWidth,
      child: searchField,
    );
    final showChips = filterChips != null && !sidePanelSearchExpanded;

    // One coherent toolbar line: logo/title + search field + filter/settings
    // button, all vertically centered on a single baseline. The field lives in
    // an [Expanded] so it grows toward the right on focus (its resolved width is
    // clamped to the available space to avoid overflow) while the trailing
    // button stays pinned to the right. The quick-filter chips never share this
    // line — they previously forced the field to wrap below the title (the
    // "dropped second-row" header bug). Instead they sit on a deliberate second
    // row below and collapse entirely while the search is focused/expanded.
    final toolbar = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: KubusSpacing.md + KubusSpacing.xs),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: field,
          ),
        ),
        if (mapToggle != null) ...[
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          mapToggle!,
        ],
      ],
    );

    if (!showChips) return toolbar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar,
        SizedBox(height: sectionGap),
        filterChips!,
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context, double topInset) {
    final scheme = Theme.of(context).colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidePanelSearchRow(context),
        if (extraContent != null) ...[
          SizedBox(height: sectionGap),
          extraContent!,
        ],
      ],
    );

    final panelContent = switch (sidePanelSurfaceMode) {
      KubusSearchSidePanelSurfaceMode.glassHost => buildKubusMapGlassSurface(
          context: context,
          kind: KubusMapGlassSurfaceKind.panel,
          borderRadius: BorderRadius.circular(sidePanelRadius),
          padding: sidePanelInnerPadding,
          margin: EdgeInsets.only(
            left: panelInsets.left,
            right: panelInsets.right,
          ),
          tintBase: scheme.surface,
          child: content,
        ),
      KubusSearchSidePanelSurfaceMode.hostless => Container(
          margin: EdgeInsets.only(
            left: panelInsets.left,
            right: panelInsets.right,
          ),
          padding: sidePanelInnerPadding,
          child: content,
        ),
    };

    final panel = MapOverlayBlocker(
      cursor: SystemMouseCursors.basic,
      child: panelContent,
    );

    if (!sidePanelAnimated) {
      return Positioned(
        top: topInset,
        left: 0,
        right: rightInset,
        child: panel,
      );
    }

    final animationTheme = context.animationTheme;
    return AnimatedPositioned(
      duration: positionAnimationDuration ?? animationTheme.medium,
      curve: positionAnimationCurve ?? animationTheme.defaultCurve,
      top: topInset,
      left: 0,
      right: rightInset,
      child: panel,
    );
  }
}
