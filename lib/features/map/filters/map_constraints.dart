import 'package:flutter/foundation.dart';

import '../../../models/art_marker.dart';
import 'map_filter_state.dart';

/// Every way the map can silently hold results back, as one typed list.
///
/// The map is restricted by independent things: the area being looked at (map
/// viewport or a travel radius around the visitor), a free-text search, a
/// discovery status, attribute filters and hidden content layers. Each is a
/// separate constraint so a visitor can see *why* a marker is not on the map
/// and remove exactly that restriction, instead of wondering where half the
/// artworks went.
enum KubusMapConstraintKind {
  /// The current map view bounds the result (the default area; informational).
  viewport,

  /// A travel radius around the visitor bounds the result.
  radius,

  /// A free-text search restricts the result.
  query,

  /// Only discovered / undiscovered content.
  discovery,

  /// Only AR-capable content.
  arOnly,

  /// Only favourited content.
  favoritesOnly,

  /// One or more content layers (marker types) are hidden.
  hiddenLayers,
}

/// One active restriction on the map's results.
///
/// Immutable and locale-free: the strip maps [kind] and the typed fields to
/// localised text, and [stableKey] keys the UI and semantics diffing.
@immutable
class KubusMapConstraint {
  const KubusMapConstraint._({
    required this.kind,
    this.radiusKm,
    this.locationPending = false,
    this.query,
    this.discoveryStatus,
    this.hiddenLayers = const <ArtMarkerType>[],
  });

  const KubusMapConstraint.viewport()
      : this._(kind: KubusMapConstraintKind.viewport);

  const KubusMapConstraint.radius({
    required double radiusKm,
    required bool locationPending,
  }) : this._(
          kind: KubusMapConstraintKind.radius,
          radiusKm: radiusKm,
          locationPending: locationPending,
        );

  const KubusMapConstraint.query(String query)
      : this._(kind: KubusMapConstraintKind.query, query: query);

  const KubusMapConstraint.discovery(KubusMapDiscoveryStatus status)
      : this._(
          kind: KubusMapConstraintKind.discovery,
          discoveryStatus: status,
        );

  const KubusMapConstraint.arOnly()
      : this._(kind: KubusMapConstraintKind.arOnly);

  const KubusMapConstraint.favoritesOnly()
      : this._(kind: KubusMapConstraintKind.favoritesOnly);

  const KubusMapConstraint.hiddenLayers(List<ArtMarkerType> layers)
      : this._(kind: KubusMapConstraintKind.hiddenLayers, hiddenLayers: layers);

  final KubusMapConstraintKind kind;
  final double? radiusKm;

  /// Radius scope is active but no location fix exists yet, so the radius is
  /// not narrowing anything. The strip says so rather than implying it is.
  final bool locationPending;
  final String? query;
  final KubusMapDiscoveryStatus? discoveryStatus;
  final List<ArtMarkerType> hiddenLayers;

  /// The viewport is the baseline area, not a restriction the visitor added,
  /// so it has no "clear". Every other constraint can be removed on its own.
  bool get clearable => kind != KubusMapConstraintKind.viewport;

  String get stableKey => switch (kind) {
        KubusMapConstraintKind.viewport => 'viewport',
        KubusMapConstraintKind.radius =>
          'radius:${radiusKm?.toStringAsFixed(1)}:$locationPending',
        KubusMapConstraintKind.query => 'query:$query',
        KubusMapConstraintKind.discovery =>
          'discovery:${discoveryStatus!.name}',
        KubusMapConstraintKind.arOnly => 'ar',
        KubusMapConstraintKind.favoritesOnly => 'favorites',
        KubusMapConstraintKind.hiddenLayers =>
          'layers:${hiddenLayers.map((l) => l.name).join(',')}',
      };

  @override
  bool operator ==(Object other) =>
      other is KubusMapConstraint && other.stableKey == stableKey;

  @override
  int get hashCode => stableKey.hashCode;
}

/// The constraints active on the map right now, in presentation order.
///
/// Returns an empty list when the map is unrestricted beyond its own view, so
/// nothing is shown for the plain browsing state. As soon as anything narrows
/// the result, the area baseline (viewport or radius) is listed first so the
/// strip reads as a complete explanation, followed by search, discovery,
/// attributes and hidden layers.
List<KubusMapConstraint> resolveMapConstraints({
  required KubusMapFilterState filters,
  required String query,
  required bool hasLocation,
}) {
  final trimmed = query.trim();
  final restrictions = <KubusMapConstraint>[
    if (filters.scope == KubusMapScope.nearMe)
      KubusMapConstraint.radius(
        radiusKm: filters.nearMeRadiusKm,
        locationPending: !hasLocation,
      ),
    if (trimmed.isNotEmpty) KubusMapConstraint.query(trimmed),
    if (filters.discoveryStatus != KubusMapDiscoveryStatus.all)
      KubusMapConstraint.discovery(filters.discoveryStatus),
    if (filters.arOnly) const KubusMapConstraint.arOnly(),
    if (filters.favoritesOnly) const KubusMapConstraint.favoritesOnly(),
    if (filters.visibleContentLayers.length < ArtMarkerType.values.length)
      KubusMapConstraint.hiddenLayers(<ArtMarkerType>[
        for (final type in ArtMarkerType.values)
          if (!filters.visibleContentLayers.contains(type)) type,
      ]),
  ];
  if (restrictions.isEmpty) return const <KubusMapConstraint>[];

  final baselineIsViewport = filters.scope == KubusMapScope.currentViewport;
  return List<KubusMapConstraint>.unmodifiable(<KubusMapConstraint>[
    if (baselineIsViewport) const KubusMapConstraint.viewport(),
    ...restrictions,
  ]);
}

/// What clearing [constraint] does to the filter state. The search query is
/// not part of [KubusMapFilterState]; callers clear it themselves when
/// [KubusMapConstraint.kind] is [KubusMapConstraintKind.query].
KubusMapFilterState clearMapConstraint(
  KubusMapFilterState filters,
  KubusMapConstraint constraint,
) {
  switch (constraint.kind) {
    case KubusMapConstraintKind.viewport:
    case KubusMapConstraintKind.query:
      return filters;
    case KubusMapConstraintKind.radius:
      return filters.withScope(KubusMapScope.currentViewport);
    case KubusMapConstraintKind.discovery:
      return filters.withDiscoveryStatus(KubusMapDiscoveryStatus.all);
    case KubusMapConstraintKind.arOnly:
      return filters.withArOnly(false);
    case KubusMapConstraintKind.favoritesOnly:
      return filters.withFavoritesOnly(false);
    case KubusMapConstraintKind.hiddenLayers:
      return filters.withAllContentLayersVisible();
  }
}
