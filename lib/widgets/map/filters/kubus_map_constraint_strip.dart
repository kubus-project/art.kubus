import 'package:flutter/material.dart';

import '../../../features/map/filters/map_constraints.dart';
import '../../../features/map/filters/map_filter_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_map_tokens.dart';
import '../../common/kubus_glass_chip.dart';
import '../../search/kubus_search_controller.dart';

/// Localised text of one map constraint. Shared by the strip and its tests so
/// the words a visitor reads are asserted in one place.
String kubusMapConstraintLabel(
  AppLocalizations l10n,
  KubusMapConstraint constraint,
) {
  switch (constraint.kind) {
    case KubusMapConstraintKind.viewport:
      return l10n.mapFilterScopeCurrentViewport;
    case KubusMapConstraintKind.radius:
      final km = _formatKm(constraint.radiusKm ?? 0);
      return constraint.locationPending
          ? l10n.mapConstraintRadiusNoLocation(km)
          : l10n.mapConstraintRadius(km);
    case KubusMapConstraintKind.query:
      return l10n.mapConstraintQuery(constraint.query ?? '');
    case KubusMapConstraintKind.discovery:
      return constraint.discoveryStatus == KubusMapDiscoveryStatus.discovered
          ? l10n.mapFilterDiscovered
          : l10n.mapFilterUndiscovered;
    case KubusMapConstraintKind.arOnly:
      return l10n.mapFilterArEnabled;
    case KubusMapConstraintKind.favoritesOnly:
      return l10n.mapFilterFavorites;
    case KubusMapConstraintKind.hiddenLayers:
      return l10n.mapConstraintHiddenLayers(constraint.hiddenLayers.length);
  }
}

String _formatKm(double km) =>
    km == km.roundToDouble() ? km.round().toString() : km.toStringAsFixed(1);

IconData _iconFor(KubusMapConstraintKind kind) {
  switch (kind) {
    case KubusMapConstraintKind.viewport:
      return Icons.crop_free;
    case KubusMapConstraintKind.radius:
      return Icons.near_me_outlined;
    case KubusMapConstraintKind.query:
      return Icons.search;
    case KubusMapConstraintKind.discovery:
      return Icons.explore_outlined;
    case KubusMapConstraintKind.arOnly:
      return Icons.view_in_ar;
    case KubusMapConstraintKind.favoritesOnly:
      return Icons.favorite_border;
    case KubusMapConstraintKind.hiddenLayers:
      return Icons.layers_outlined;
  }
}

/// The list of what is currently narrowing the map, each with its own clear.
///
/// Rendered only while something restricts the result (the resolver returns an
/// empty list for the plain browsing state), so it never repeats what the
/// search field and the map already show. Every restriction except the
/// baseline map area removes itself on tap; "Reset all" removes them together.
/// The strip owns no state: the screen applies each callback to its own
/// filter state and search controller.
class KubusMapConstraintStrip extends StatelessWidget {
  const KubusMapConstraintStrip({
    super.key,
    required this.constraints,
    required this.onClear,
    required this.onResetAll,
    this.accentColor,
  });

  final List<KubusMapConstraint> constraints;
  final ValueChanged<KubusMapConstraint> onClear;
  final VoidCallback onResetAll;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final motion = KubusMapMotion.fromMediaQuery(
      animationTheme: context.animationTheme,
      mediaQuery: MediaQuery.of(context),
    ).panelEnter;

    return AnimatedSize(
      duration: motion.duration,
      curve: motion.curve,
      alignment: Alignment.topLeft,
      child: constraints.isEmpty
          ? const SizedBox(
              key: ValueKey<String>('map_constraint_strip_empty'),
              width: double.infinity,
            )
          : Semantics(
              container: true,
              label: l10n.mapConstraintsLabel,
              child: Padding(
                key: const ValueKey<String>('map_constraint_strip'),
                padding: const EdgeInsets.only(top: KubusSpacing.sm),
                child: Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (final constraint in constraints)
                      _ConstraintChip(
                        key: ValueKey<String>(
                          'map_constraint_${constraint.stableKey}',
                        ),
                        constraint: constraint,
                        label: kubusMapConstraintLabel(l10n, constraint),
                        accentColor: accentColor,
                        onClear: constraint.clearable
                            ? () => onClear(constraint)
                            : null,
                        clearLabel: l10n.mapConstraintClear(
                          kubusMapConstraintLabel(l10n, constraint),
                        ),
                      ),
                    if (constraints.any((c) => c.clearable))
                      TextButton(
                        key: const ValueKey<String>('map_constraint_reset_all'),
                        onPressed: onResetAll,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            KubusSpacing.xl + KubusSpacing.md,
                            _kChipHeight,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.sm,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(l10n.mapConstraintResetAll),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

const double _kChipHeight = 36.0;

class _ConstraintChip extends StatelessWidget {
  const _ConstraintChip({
    super.key,
    required this.constraint,
    required this.label,
    required this.clearLabel,
    required this.onClear,
    this.accentColor,
  });

  final KubusMapConstraint constraint;
  final String label;
  final String clearLabel;
  final VoidCallback? onClear;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final clearable = onClear != null;
    // Clearable chips lead with a close glyph (the whole chip is the target);
    // the baseline map-area chip is informational and keeps its own glyph.
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: KubusGlassChip(
        label: label,
        icon: clearable ? Icons.close : _iconFor(constraint.kind),
        active: clearable,
        accentColor: accentColor,
        borderRadius: KubusRadius.sm,
        minHeight: _kChipHeight,
        useMapAwareGlass: true,
        onPressed: onClear,
      ),
    );
    if (!clearable) {
      return Semantics(label: label, child: ExcludeSemantics(child: chip));
    }
    return Semantics(
      button: true,
      label: clearLabel,
      child: ExcludeSemantics(child: chip),
    );
  }
}

/// Binds [KubusMapConstraintStrip] to a screen's search controller and filter
/// state so mobile and desktop share one implementation.
///
/// It rebuilds with the search text (the query is a constraint) and applies
/// "clear one" and "reset all" through [onFiltersChanged], the same entry point
/// the filter panel uses, so a restriction removed here and one removed in the
/// panel take identical paths (data reload, marker resync).
class KubusMapConstraintStripBinding extends StatelessWidget {
  const KubusMapConstraintStripBinding({
    super.key,
    required this.searchController,
    required this.filters,
    required this.hasLocation,
    required this.onFiltersChanged,
    this.accentColor,
  });

  final KubusSearchController searchController;
  final KubusMapFilterState filters;
  final bool hasLocation;
  final ValueChanged<KubusMapFilterState> onFiltersChanged;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: searchController,
      builder: (context, _) {
        return KubusMapConstraintStrip(
          constraints: resolveMapConstraints(
            filters: filters,
            query: searchController.state.query,
            hasLocation: hasLocation,
          ),
          accentColor: accentColor,
          onClear: (constraint) {
            if (constraint.kind == KubusMapConstraintKind.query) {
              searchController.clearQueryWithContext(context);
              return;
            }
            onFiltersChanged(clearMapConstraint(filters, constraint));
          },
          onResetAll: () {
            if (searchController.state.query.trim().isNotEmpty) {
              searchController.clearQueryWithContext(context);
            }
            onFiltersChanged(filters.reset());
          },
        );
      },
    );
  }
}
