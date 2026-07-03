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

  /// The side-panel search row: leading + search field + quick filters +
  /// toggle, all on ONE horizontal line so the search bar and quick filters
  /// read as a single control area (not a stacked second-row card).
  ///
  /// The field flexes to fill the left of the row; the quick-filter strip is
  /// bounded by a [Flexible] and scrolls horizontally, so it never wraps to a
  /// second line or overflows on narrower desktop widths. The trailing toggle
  /// stays pinned to the right.
  Widget _buildSidePanelSearchRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: KubusSpacing.md + KubusSpacing.xs),
        ],
        Expanded(
          flex: 5,
          child: searchField,
        ),
        if (filterChips != null) ...[
          const SizedBox(width: KubusSpacing.md + KubusSpacing.xs),
          Flexible(
            flex: 6,
            // Clip at the strip bounds: with Clip.none the overflowing chips
            // painted past the panel edge and under the trailing filter toggle,
            // reading as broken chip borders on narrower desktops.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              child: filterChips!,
            ),
          ),
        ],
        if (mapToggle != null) ...[
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          mapToggle!,
        ],
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
