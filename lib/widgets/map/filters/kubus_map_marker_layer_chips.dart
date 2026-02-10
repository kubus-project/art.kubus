import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../features/map/shared/map_screen_shared_helpers.dart';
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
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: ArtMarkerType.values.map((type) {
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
          onPressed: () => onToggle(type, !selected),
        );
      }).toList(),
    );
  }
}
