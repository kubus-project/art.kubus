import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/common/kubus_glass_chip.dart';
import '../../../widgets/common/kubus_search_overlay_scaffold.dart';
import '../../../widgets/search/kubus_general_search.dart';
import '../../../widgets/search/kubus_search_controller.dart';
import '../../../widgets/search/kubus_search_result.dart';

enum KubusMapFilterChipLayout {
  wrap,
  row,

  /// Horizontal strip of fixed-size button cells (used by the desktop
  /// search-row quick filters). Each chip is a real button cell: a fixed
  /// width + height with a centered icon + label, so the border wraps the
  /// whole cell instead of shrink-wrapping the icon/text. Cells reflow to a
  /// second line (via [Wrap]) on smaller widths instead of overflowing.
  rowFixed,

  /// Responsive grid of full-cell chips: one column on very narrow panels,
  /// two columns otherwise. Each chip stretches to its cell so the border
  /// wraps the whole button area (not just icon + label) and every chip reads
  /// with equal height/weight.
  grid,
}

/// Consistent height for filter/layer chips so a grid reads with equal weight
/// and keeps an accessible tap target.
const double kKubusMapFilterChipHeight = 44.0;

/// Default fixed cell width for [KubusMapFilterChipLayout.rowFixed] quick
/// filters. Wide enough to fit the longest catalog label without truncation so
/// every desktop search-row chip reads as an equal-weight button cell.
const double kKubusMapFilterRowChipMinWidth = 140.0;

@immutable
class KubusMapFilterOption {
  const KubusMapFilterOption({
    required this.key,
    required this.label,
    required this.accentColor,
    required this.icon,
  });

  final String key;
  final String label;
  final Color accentColor;

  /// Type-specific glyph so each quick filter reads distinctly at a glance
  /// instead of every chip sharing a generic "filter" icon.
  final IconData icon;
}

class KubusMapFilterCatalog {
  const KubusMapFilterCatalog._();

  static List<KubusMapFilterOption> buildOptions(
    BuildContext context, {
    Color? accentColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final primaryAccent = accentColor ?? scheme.primary;

    return <KubusMapFilterOption>[
      KubusMapFilterOption(
        key: 'all',
        label: l10n.mapFilterAllNearby,
        accentColor: primaryAccent,
        icon: Icons.public,
      ),
      KubusMapFilterOption(
        key: 'nearby',
        label: l10n.mapFilterWithin1Km,
        accentColor: primaryAccent,
        icon: Icons.near_me,
      ),
      KubusMapFilterOption(
        key: 'discovered',
        label: l10n.mapFilterDiscovered,
        accentColor: accentColor ?? roles.positiveAction,
        icon: Icons.check_circle_outline,
      ),
      KubusMapFilterOption(
        key: 'undiscovered',
        label: l10n.mapFilterUndiscovered,
        accentColor: accentColor ?? scheme.outline,
        icon: Icons.explore_outlined,
      ),
      KubusMapFilterOption(
        key: 'ar',
        label: l10n.mapFilterArEnabled,
        accentColor: accentColor ?? scheme.secondary,
        icon: Icons.view_in_ar,
      ),
      KubusMapFilterOption(
        key: 'favorites',
        label: l10n.mapFilterFavorites,
        accentColor: accentColor ?? roles.likeAction,
        icon: Icons.favorite,
      ),
    ];
  }

}

class KubusMapFilterChipStrip extends StatelessWidget {
  const KubusMapFilterChipStrip({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
    this.layout = KubusMapFilterChipLayout.wrap,
    this.spacing = KubusSpacing.sm,
    this.runSpacing = KubusSpacing.sm,
    this.borderRadius = KubusRadius.sm,
    this.enableBlur = true,
    this.keyPadding = EdgeInsets.zero,
    this.rowChipMinWidth = kKubusMapFilterRowChipMinWidth,
    this.rowChipHeight = kKubusMapFilterChipHeight,
  });

  final List<KubusMapFilterOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final KubusMapFilterChipLayout layout;
  final double spacing;
  final double runSpacing;
  final double borderRadius;
  final bool enableBlur;
  final EdgeInsetsGeometry keyPadding;

  /// Fixed cell width for [KubusMapFilterChipLayout.rowFixed] chips.
  final double rowChipMinWidth;

  /// Fixed cell height for [KubusMapFilterChipLayout.rowFixed] chips.
  final double rowChipHeight;

  @override
  Widget build(BuildContext context) {
    if (layout == KubusMapFilterChipLayout.grid) {
      return _buildGrid(context);
    }
    if (layout == KubusMapFilterChipLayout.rowFixed) {
      return _buildRowFixed(context);
    }

    final chips = <Widget>[
      for (final option in options)
        Padding(
          padding: keyPadding,
          child: KubusGlassChip(
            label: option.label,
            icon: option.icon,
            active: selectedKey == option.key,
            accentColor: option.accentColor,
            borderRadius: borderRadius,
            enableBlur: enableBlur,
            onPressed: () => onSelected(option.key),
          ),
        ),
    ];

    if (layout == KubusMapFilterChipLayout.row) {
      final rowChildren = <Widget>[];
      for (var i = 0; i < chips.length; i++) {
        if (i > 0) {
          rowChildren.add(SizedBox(width: spacing));
        }
        rowChildren.add(chips[i]);
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: rowChildren,
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: chips,
    );
  }

  /// Fixed-size button cells laid out in a [Wrap]. Each cell is a real button:
  /// a fixed width + height with a centered icon + label so the border wraps
  /// the whole cell (not just the icon/text), and the active state colours the
  /// whole cell. The [Wrap] reflows cells onto a second line on smaller widths
  /// instead of overflowing the search row.
  Widget _buildRowFixed(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: <Widget>[
        for (final option in options)
          SizedBox(
            width: rowChipMinWidth,
            height: rowChipHeight,
            child: KubusGlassChip(
              label: option.label,
              icon: option.icon,
              active: selectedKey == option.key,
              accentColor: option.accentColor,
              borderRadius: borderRadius,
              enableBlur: enableBlur,
              fullWidth: true,
              minHeight: rowChipHeight,
              onPressed: () => onSelected(option.key),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded width (e.g. inside an unconstrained Positioned/Row) cannot
        // host Expanded cells; fall back to an intrinsic wrap of chips.
        if (!constraints.maxWidth.isFinite) {
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: <Widget>[
              for (final option in options)
                KubusGlassChip(
                  label: option.label,
                  icon: option.icon,
                  active: selectedKey == option.key,
                  accentColor: option.accentColor,
                  borderRadius: borderRadius,
                  enableBlur: enableBlur,
                  minHeight: kKubusMapFilterChipHeight,
                  onPressed: () => onSelected(option.key),
                ),
            ],
          );
        }
        // One column on very narrow panels, two columns when there is room, so
        // the borders always wrap the whole cell instead of shrink-wrapping.
        final columns = constraints.maxWidth < 320 ? 1 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < options.length; i += columns) {
          final rowChildren = <Widget>[];
          for (var c = 0; c < columns; c++) {
            final index = i + c;
            if (c > 0) rowChildren.add(SizedBox(width: spacing));
            if (index >= options.length) {
              // Pad the trailing partial row so existing cells keep their width.
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
              continue;
            }
            final option = options[index];
            rowChildren.add(
              Expanded(
                child: KubusGlassChip(
                  label: option.label,
                  icon: option.icon,
                  active: selectedKey == option.key,
                  accentColor: option.accentColor,
                  borderRadius: borderRadius,
                  enableBlur: enableBlur,
                  fullWidth: true,
                  minHeight: kKubusMapFilterChipHeight,
                  onPressed: () => onSelected(option.key),
                ),
              ),
            );
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
          rows.add(Row(children: rowChildren));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class KubusMapSearchOverlayAssembly extends StatelessWidget {
  const KubusMapSearchOverlayAssembly({
    super.key,
    required this.controller,
    required this.layout,
    required this.searchField,
    required this.minCharsHint,
    required this.noResultsText,
    required this.onResultTap,
    this.accentColor,
    this.onDismiss,
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
  });

  final KubusSearchController controller;
  final KubusSearchOverlayLayout layout;
  final Widget searchField;
  final String minCharsHint;
  final String noResultsText;
  final ValueChanged<KubusSearchResult> onResultTap;
  final Color? accentColor;
  final VoidCallback? onDismiss;
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final trimmed = state.query.trim();
        final shouldShow = state.isOverlayVisible &&
            (state.isFetching ||
                state.results.isNotEmpty ||
                trimmed.length >= controller.config.minChars);

        // Resolved width contract: one measured width is handed to both the
        // field (via the scaffold) and the results dropdown so the dropdown
        // never grows independently to the right.
        //
        // - top overlay (mobile): the field is ALWAYS the full available safe
        //   width. No idle/focused distinction and no focus-expansion
        //   animation; the filter button stays pinned in the trailing slot.
        // - side panel (desktop): the field is comfortable when idle and
        //   expands toward the right when focused / a query is active.
        double? resolvedFieldWidth;
        bool sidePanelExpanded = false;
        if (layout == KubusSearchOverlayLayout.topOverlay) {
          final screenWidth = MediaQuery.of(context).size.width;
          final available = (screenWidth - panelInsets.left - panelInsets.right)
              .clamp(0.0, maxWidth)
              .toDouble();
          resolvedFieldWidth = available;
        } else {
          final screenWidth = MediaQuery.of(context).size.width;
          // The side panel spans left:0 → right:rightInset, with the glass
          // surface margins (panelInsets) and inner horizontal padding inside.
          final outer =
              (screenWidth - rightInset).clamp(0.0, double.infinity).toDouble();
          final content = (outer -
                  panelInsets.left -
                  panelInsets.right -
                  sidePanelInnerPadding.horizontal)
              .clamp(0.0, double.infinity)
              .toDouble();
          sidePanelExpanded = controller.hasFocusedField || trimmed.isNotEmpty;
          final idleWidth = (content * 0.42)
              .clamp(220.0, 460.0)
              .clamp(0.0, content)
              .toDouble();
          final focusedWidth = (content * 0.72)
              .clamp(idleWidth, 760.0)
              .clamp(0.0, content)
              .toDouble();
          resolvedFieldWidth = sidePanelExpanded ? focusedWidth : idleWidth;
        }

        final isTopOverlay = layout == KubusSearchOverlayLayout.topOverlay;
        return KubusSearchOverlayScaffold(
          layout: layout,
          searchField: searchField,
          topOverlayFieldWidth: isTopOverlay ? resolvedFieldWidth : null,
          sidePanelFieldWidth: isTopOverlay ? null : resolvedFieldWidth,
          sidePanelSearchExpanded: sidePanelExpanded,
          searchDropdown: KubusSearchResultsOverlay(
            controller: controller,
            accentColor: accentColor,
            minCharsHint: minCharsHint,
            noResultsText: noResultsText,
            enabled: shouldShow,
            onDismiss: onDismiss ?? controller.dismissOverlay,
            onResultTap: onResultTap,
            maxWidth: maxWidth,
            width: resolvedFieldWidth,
            // This assembly always floats over the live map, so route the
            // results dropdown through the map-aware glass language too.
            useMapGlassSurface: true,
          ),
          leading: leading,
          filterChips: filterChips,
          mapToggle: mapToggle,
          extraContent: extraContent,
          panelInsets: panelInsets,
          maxWidth: maxWidth,
          rightInset: rightInset,
          useSafeTopPadding: useSafeTopPadding,
          sectionGap: sectionGap,
          sidePanelInnerPadding: sidePanelInnerPadding,
          sidePanelSurfaceMode: sidePanelSurfaceMode,
          sidePanelRadius: sidePanelRadius,
          sidePanelAnimated: sidePanelAnimated,
          positionAnimationDuration: positionAnimationDuration,
          positionAnimationCurve: positionAnimationCurve,
        );
      },
    );
  }
}
