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
}

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

  @override
  Widget build(BuildContext context) {
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

        return KubusSearchOverlayScaffold(
          layout: layout,
          searchField: searchField,
          searchDropdown: KubusSearchResultsOverlay(
            controller: controller,
            accentColor: accentColor,
            minCharsHint: minCharsHint,
            noResultsText: noResultsText,
            enabled: shouldShow,
            onDismiss: onDismiss ?? controller.dismissOverlay,
            onResultTap: onResultTap,
            maxWidth: maxWidth,
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
