import 'package:flutter/material.dart';

import '../../../features/map/filters/map_filter_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../utils/design_tokens.dart';
import 'kubus_map_marker_layer_chips.dart';

/// Semantic, live-update content for the shared map filter surface.
///
/// This widget deliberately owns no filter state. Mobile and desktop pass the
/// same immutable [state] and apply every [onChanged] value immediately. Its
/// presentation keeps exclusive choices, independent attributes, and content
/// visibility visually distinct.
class KubusMapFilterContent extends StatelessWidget {
  const KubusMapFilterContent({
    super.key,
    required this.state,
    required this.onChanged,
    this.travelScopeEnabled = false,
    this.nearMeRadiusEnabled = true,
    this.minNearMeRadiusKm = KubusMapFilterState.minNearMeRadiusKm,
    this.maxNearMeRadiusKm = KubusMapFilterState.maxNearMeRadiusKm,
  })  : assert(minNearMeRadiusKm < maxNearMeRadiusKm),
        assert(
          minNearMeRadiusKm >= KubusMapFilterState.minNearMeRadiusKm,
        ),
        assert(
          maxNearMeRadiusKm <= KubusMapFilterState.maxNearMeRadiusKm,
        );

  final KubusMapFilterState state;
  final ValueChanged<KubusMapFilterState> onChanged;

  /// Whether the feature-gated travel scope is available to the caller.
  final bool travelScopeEnabled;

  /// Whether users may adjust the near-me radius.
  final bool nearMeRadiusEnabled;
  final double minNearMeRadiusKm;
  final double maxNearMeRadiusKm;

  void _emit(KubusMapFilterState next) {
    if (next != state) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final visibleLayerCount = state.visibleContentLayers.length;
    final totalLayerCount = ArtMarkerType.values.length;
    final activeCountLabel = l10n.mapFilterActiveCountLabel(
      state.activeFilterCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: activeCountLabel,
                child: ExcludeSemantics(
                  child: Text(
                    activeCountLabel,
                    key: const ValueKey<String>('map_filter_active_count'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: state.isDefault
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                  ),
                ),
              ),
            ),
            if (!state.isDefault)
              TextButton.icon(
                key: const ValueKey<String>('map_filter_reset'),
                onPressed: () => _emit(state.reset()),
                icon: const Icon(Icons.restart_alt),
                label: Text(l10n.commonReset),
              ),
          ],
        ),
        const SizedBox(height: KubusSpacing.md),
        _FilterSection(
          title: l10n.mapFilterScopeTitle,
          child: RadioGroup<KubusMapScope>(
            groupValue: state.scope,
            onChanged: (value) {
              if (value != null) _emit(state.withScope(value));
            },
            child: Column(
              children: <Widget>[
                _ScopeRadioTile(
                  value: KubusMapScope.currentViewport,
                  selected: state.scope == KubusMapScope.currentViewport,
                  label: l10n.mapFilterScopeCurrentViewport,
                  icon: Icons.crop_free,
                ),
                _ScopeRadioTile(
                  value: KubusMapScope.nearMe,
                  selected: state.scope == KubusMapScope.nearMe,
                  label: l10n.mapFilterScopeNearMe,
                  icon: Icons.near_me_outlined,
                ),
                if (travelScopeEnabled)
                  _ScopeRadioTile(
                    value: KubusMapScope.travel,
                    selected: state.scope == KubusMapScope.travel,
                    label: l10n.mapFilterScopeTravel,
                    icon: Icons.travel_explore,
                  ),
              ],
            ),
          ),
        ),
        if (state.scope == KubusMapScope.nearMe) ...<Widget>[
          const SizedBox(height: KubusSpacing.sm),
          _NearMeRadiusControl(
            value: state.nearMeRadiusKm,
            enabled: nearMeRadiusEnabled,
            min: minNearMeRadiusKm,
            max: maxNearMeRadiusKm,
            onChanged: (value) => _emit(state.withNearMeRadiusKm(value)),
          ),
        ],
        const SizedBox(height: KubusSpacing.lg),
        _FilterSection(
          title: l10n.mapFilterDiscoveryStatusTitle,
          child: RadioGroup<KubusMapDiscoveryStatus>(
            groupValue: state.discoveryStatus,
            onChanged: (value) {
              if (value != null) _emit(state.withDiscoveryStatus(value));
            },
            child: Column(
              children: <Widget>[
                _DiscoveryRadioTile(
                  value: KubusMapDiscoveryStatus.all,
                  selected:
                      state.discoveryStatus == KubusMapDiscoveryStatus.all,
                  label: l10n.mapFilterAll,
                  icon: Icons.layers_outlined,
                ),
                _DiscoveryRadioTile(
                  value: KubusMapDiscoveryStatus.undiscovered,
                  selected: state.discoveryStatus ==
                      KubusMapDiscoveryStatus.undiscovered,
                  label: l10n.mapFilterUndiscovered,
                  icon: Icons.visibility_off_outlined,
                ),
                _DiscoveryRadioTile(
                  value: KubusMapDiscoveryStatus.discovered,
                  selected: state.discoveryStatus ==
                      KubusMapDiscoveryStatus.discovered,
                  label: l10n.mapFilterDiscovered,
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        _FilterSection(
          title: l10n.mapFilterAttributesTitle,
          child: Column(
            children: <Widget>[
              _AttributeSwitchTile(
                semanticKey: const ValueKey<String>('map_filter_ar'),
                value: state.arOnly,
                onChanged: (value) => _emit(state.withArOnly(value)),
                icon: Icons.view_in_ar_outlined,
                label: l10n.mapFilterArEnabled,
              ),
              _AttributeSwitchTile(
                semanticKey: const ValueKey<String>('map_filter_favorites'),
                value: state.favoritesOnly,
                onChanged: (value) => _emit(state.withFavoritesOnly(value)),
                icon: Icons.favorite_border,
                label: l10n.mapFilterFavorites,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        _FilterSection(
          title: l10n.mapFilterContentLayersTitle,
          trailing: Semantics(
            liveRegion: true,
            label: l10n.mapFilterVisibleLayerCountLabel(
              visibleLayerCount,
              totalLayerCount,
            ),
            child: ExcludeSemantics(
              child: Text(
                l10n.mapFilterVisibleLayerCountLabel(
                  visibleLayerCount,
                  totalLayerCount,
                ),
                key: const ValueKey<String>('map_filter_layer_count'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: KubusSpacing.sm),
            child: KubusMapMarkerLayerChips(
              l10n: l10n,
              visibility: <ArtMarkerType, bool>{
                for (final type in ArtMarkerType.values)
                  type: state.visibleContentLayers.contains(type),
              },
              onToggle: (type, visible) => _emit(
                state.withContentLayerVisibility(
                  type,
                  visible: visible,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: KubusSpacing.sm),
        child,
      ],
    );
  }
}

class _ScopeRadioTile extends StatelessWidget {
  const _ScopeRadioTile({
    required this.value,
    required this.selected,
    required this.label,
    required this.icon,
  });

  final KubusMapScope value;
  final bool selected;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>('map_filter_scope_${value.name}'),
      selected: selected,
      child: RadioListTile<KubusMapScope>(
        value: value,
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon),
        title: Text(label),
      ),
    );
  }
}

class _DiscoveryRadioTile extends StatelessWidget {
  const _DiscoveryRadioTile({
    required this.value,
    required this.selected,
    required this.label,
    required this.icon,
  });

  final KubusMapDiscoveryStatus value;
  final bool selected;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>('map_filter_discovery_${value.name}'),
      selected: selected,
      child: RadioListTile<KubusMapDiscoveryStatus>(
        value: value,
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon),
        title: Text(label),
      ),
    );
  }
}

class _NearMeRadiusControl extends StatelessWidget {
  const _NearMeRadiusControl({
    required this.value,
    required this.enabled,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  String _formatRadius(double radius) {
    return radius == radius.roundToDouble()
        ? radius.toStringAsFixed(0)
        : radius.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resolvedValue = value.clamp(min, max).toDouble();
    final label = l10n.mapFilterNearMeRadiusLabel(
      _formatRadius(resolvedValue),
    );
    final divisions = ((max - min) * 2).round();

    return Semantics(
      container: true,
      label: label,
      enabled: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            label,
            key: const ValueKey<String>('map_filter_radius_label'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Slider(
            key: const ValueKey<String>('map_filter_radius_slider'),
            value: resolvedValue,
            min: min,
            max: max,
            divisions: divisions,
            label: _formatRadius(resolvedValue),
            semanticFormatterCallback: (radius) =>
                l10n.mapFilterNearMeRadiusLabel(_formatRadius(radius)),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _AttributeSwitchTile extends StatelessWidget {
  const _AttributeSwitchTile({
    required this.semanticKey,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.label,
  });

  final Key semanticKey;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticKey,
      container: true,
      label: label,
      toggled: value,
      enabled: true,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon),
          title: Text(label),
        ),
      ),
    );
  }
}
