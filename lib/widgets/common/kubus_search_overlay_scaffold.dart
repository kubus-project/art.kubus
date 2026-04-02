import 'package:flutter/material.dart';

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
    this.positionAnimationDuration = const Duration(milliseconds: 240),
    this.positionAnimationCurve = Curves.easeOutCubic,
  });

  final KubusSearchOverlayLayout layout;
  final Widget searchField;
  final Widget? searchDropdown;

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
  final Duration positionAnimationDuration;
  final Curve positionAnimationCurve;

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
          if (searchDropdown != null) searchDropdown!,
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
    final scheme = Theme.of(context).colorScheme;

    final content = Column(
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
