import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../features/map/shared/map_screen_shared_helpers.dart';
import '../../../features/map/shared/map_search_filter_assembly.dart';
import '../../common/kubus_glass_chip.dart';

/// Shared builder for the "Layers" marker type chips.
///
/// This is used by both mobile and desktop map screens.
///
/// Intentionally:
/// - no provider reads
/// - no navigation side-effects
/// - screen owns state mutations + any map-style refresh logic
class KubusMapMarkerLayerChips extends StatelessWidget {
  final AppLocalizations l10n;
  final Map<ArtMarkerType, bool> visibility;

  /// Called when a chip is tapped.
  ///
  /// [nextSelected] is the new value after toggling.
  final void Function(ArtMarkerType type, bool nextSelected) onToggle;

  final double spacing;
  final double runSpacing;

  const KubusMapMarkerLayerChips({
    super.key,
    required this.l10n,
    required this.visibility,
    required this.onToggle,
    this.spacing = KubusSpacing.sm,
    this.runSpacing = KubusSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);

    final types = ArtMarkerType.values;

    Widget chipFor(ArtMarkerType type, {bool fullWidth = true}) {
      final selected = visibility[type] ?? true;
      final accent = AppColorUtils.markerSubjectColor(
        markerType: type.name,
        metadata: null,
        scheme: scheme,
        roles: roles,
      );
      return KubusGlassChip(
        label: KubusMapMarkerHelpers.markerTypeLabel(l10n, type),
        icon: KubusMapMarkerHelpers.resolveArtMarkerIcon(type),
        active: selected,
        accentColor: accent,
        borderRadius: KubusRadius.md,
        fullWidth: fullWidth,
        minHeight: kKubusMapFilterChipHeight,
        onPressed: () => onToggle(type, !selected),
      );
    }

    // Full-cell grid so the chip border wraps the whole button, matching the
    // quick-filter chips in the same panel.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded width (e.g. inside an unconstrained Positioned/Row) cannot
        // host Expanded cells; fall back to an intrinsic wrap of chips.
        if (!constraints.maxWidth.isFinite) {
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: <Widget>[
              for (final type in types) chipFor(type, fullWidth: false),
            ],
          );
        }
        final columns = constraints.maxWidth < 320 ? 1 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < types.length; i += columns) {
          final rowChildren = <Widget>[];
          for (var c = 0; c < columns; c++) {
            final index = i + c;
            if (c > 0) rowChildren.add(SizedBox(width: spacing));
            if (index >= types.length) {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
              continue;
            }
            rowChildren.add(Expanded(child: chipFor(types[index])));
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
