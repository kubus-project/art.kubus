import 'package:flutter/foundation.dart';

import '../../../models/art_marker.dart';

/// Geographic scope used to decide which marker set the map queries.
enum KubusMapScope {
  /// Use the currently visible map bounds.
  currentViewport,

  /// Query around the user's location using [KubusMapFilterState.nearMeRadiusKm].
  nearMe,

  /// Follow the viewport while the user deliberately explores another area.
  travel,
}

/// Mutually exclusive discovery state applied to visible map content.
enum KubusMapDiscoveryStatus {
  all,
  undiscovered,
  discovered,
}

/// Semantic kind of an active-filter summary.
///
/// Presentation code maps these typed values to localized labels. Keeping the
/// model free of display strings prevents domain state from becoming tied to a
/// specific locale or widget implementation.
enum KubusMapFilterSummaryKind {
  scope,
  discoveryStatus,
  arOnly,
  favoritesOnly,
  hiddenContentLayer,
}

/// A typed description of one active filter suitable for localized UI chips or
/// an accessibility summary.
@immutable
class KubusMapFilterSummary {
  const KubusMapFilterSummary.scope(
    KubusMapScope this.scope, {
    this.nearMeRadiusKm,
  })  : kind = KubusMapFilterSummaryKind.scope,
        discoveryStatus = null,
        contentLayer = null;

  const KubusMapFilterSummary.discoveryStatus(
    KubusMapDiscoveryStatus this.discoveryStatus,
  )   : kind = KubusMapFilterSummaryKind.discoveryStatus,
        scope = null,
        nearMeRadiusKm = null,
        contentLayer = null;

  const KubusMapFilterSummary.arOnly()
      : kind = KubusMapFilterSummaryKind.arOnly,
        scope = null,
        nearMeRadiusKm = null,
        discoveryStatus = null,
        contentLayer = null;

  const KubusMapFilterSummary.favoritesOnly()
      : kind = KubusMapFilterSummaryKind.favoritesOnly,
        scope = null,
        nearMeRadiusKm = null,
        discoveryStatus = null,
        contentLayer = null;

  const KubusMapFilterSummary.hiddenContentLayer(
    ArtMarkerType this.contentLayer,
  )   : kind = KubusMapFilterSummaryKind.hiddenContentLayer,
        scope = null,
        nearMeRadiusKm = null,
        discoveryStatus = null;

  final KubusMapFilterSummaryKind kind;
  final KubusMapScope? scope;
  final double? nearMeRadiusKm;
  final KubusMapDiscoveryStatus? discoveryStatus;
  final ArtMarkerType? contentLayer;

  /// Locale-independent key for semantics diffing and keyed UI children.
  String get stableKey => switch (kind) {
        KubusMapFilterSummaryKind.scope =>
          'scope:${scope!.name}:${nearMeRadiusKm?.toStringAsFixed(1) ?? '-'}',
        KubusMapFilterSummaryKind.discoveryStatus =>
          'discovery:${discoveryStatus!.name}',
        KubusMapFilterSummaryKind.arOnly => 'attribute:ar',
        KubusMapFilterSummaryKind.favoritesOnly => 'attribute:favorites',
        KubusMapFilterSummaryKind.hiddenContentLayer =>
          'hidden-layer:${contentLayer!.name}',
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KubusMapFilterSummary &&
            other.kind == kind &&
            other.scope == scope &&
            other.nearMeRadiusKm == nearMeRadiusKm &&
            other.discoveryStatus == discoveryStatus &&
            other.contentLayer == contentLayer;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        scope,
        nearMeRadiusKm,
        discoveryStatus,
        contentLayer,
      );
}

/// Immutable, typed source of truth for map filtering.
///
/// The four filter concepts deliberately remain independent:
///
/// * [scope] is one exclusive geographic choice; its near-me radius is stored
///   in [nearMeRadiusKm].
/// * [discoveryStatus] is one exclusive discovery choice.
/// * [arOnly] and [favoritesOnly] are independent attributes.
/// * [visibleContentLayers] controls marker-type visibility.
///
/// An empty content-layer set is rejected by the constructor, and attempts to
/// hide the last visible layer are no-ops. This prevents a map that appears
/// broken because every content type was accidentally disabled.
@immutable
class KubusMapFilterState {
  factory KubusMapFilterState({
    KubusMapScope scope = KubusMapScope.currentViewport,
    double nearMeRadiusKm = defaultNearMeRadiusKm,
    KubusMapDiscoveryStatus discoveryStatus = KubusMapDiscoveryStatus.all,
    bool arOnly = false,
    bool favoritesOnly = false,
    Set<ArtMarkerType>? visibleContentLayers,
  }) {
    final layers = Set<ArtMarkerType>.unmodifiable(
      visibleContentLayers ?? allContentLayers,
    );
    if (layers.isEmpty) {
      throw ArgumentError.value(
        visibleContentLayers,
        'visibleContentLayers',
        'At least one map content layer must remain visible.',
      );
    }

    return KubusMapFilterState._(
      scope: scope,
      nearMeRadiusKm: _normalizeRadius(nearMeRadiusKm),
      discoveryStatus: discoveryStatus,
      arOnly: arOnly,
      favoritesOnly: favoritesOnly,
      visibleContentLayers: layers,
    );
  }

  const KubusMapFilterState._({
    required this.scope,
    required this.nearMeRadiusKm,
    required this.discoveryStatus,
    required this.arOnly,
    required this.favoritesOnly,
    required this.visibleContentLayers,
  });

  static const double minNearMeRadiusKm = 1.0;
  static const double maxNearMeRadiusKm = 200.0;
  static const double defaultNearMeRadiusKm = 5.0;

  /// All marker types supported by the current map domain.
  static final Set<ArtMarkerType> allContentLayers =
      Set<ArtMarkerType>.unmodifiable(ArtMarkerType.values);

  factory KubusMapFilterState.defaults() => KubusMapFilterState();

  final KubusMapScope scope;

  /// Radius for [KubusMapScope.nearMe], normalized to 0.1 km and clamped to
  /// [minNearMeRadiusKm]...[maxNearMeRadiusKm].
  final double nearMeRadiusKm;

  final KubusMapDiscoveryStatus discoveryStatus;
  final bool arOnly;
  final bool favoritesOnly;
  final Set<ArtMarkerType> visibleContentLayers;

  bool get isDefault => this == KubusMapFilterState.defaults();

  /// Number displayed by the compact active-filter affordance.
  ///
  /// A non-default scope counts once (the radius is part of that scope), a
  /// non-default discovery state counts once, each enabled attribute counts
  /// once, and each hidden content layer counts once. The default viewport
  /// scope and visible layers do not inflate the count.
  int get activeFilterCount => activeSummaries.length;

  /// Typed active filters in deterministic presentation order.
  List<KubusMapFilterSummary> get activeSummaries {
    final summaries = <KubusMapFilterSummary>[];

    if (scope != KubusMapScope.currentViewport) {
      summaries.add(
        KubusMapFilterSummary.scope(
          scope,
          nearMeRadiusKm: scope == KubusMapScope.nearMe ? nearMeRadiusKm : null,
        ),
      );
    }
    if (discoveryStatus != KubusMapDiscoveryStatus.all) {
      summaries.add(
        KubusMapFilterSummary.discoveryStatus(discoveryStatus),
      );
    }
    if (arOnly) {
      summaries.add(const KubusMapFilterSummary.arOnly());
    }
    if (favoritesOnly) {
      summaries.add(const KubusMapFilterSummary.favoritesOnly());
    }
    for (final type in ArtMarkerType.values) {
      if (!visibleContentLayers.contains(type)) {
        summaries.add(KubusMapFilterSummary.hiddenContentLayer(type));
      }
    }

    return List<KubusMapFilterSummary>.unmodifiable(summaries);
  }

  /// Deterministic, locale-independent identity for query and render caches.
  ///
  /// The version prefix makes future contract changes explicit. Layers use
  /// enum declaration order, so caller set insertion order cannot affect the
  /// value.
  String get queryFingerprint {
    final layers = ArtMarkerType.values
        .where(visibleContentLayers.contains)
        .map((type) => type.name)
        .join(',');
    return 'v1|scope=${scope.name}'
        '|radius=${nearMeRadiusKm.toStringAsFixed(1)}'
        '|discovery=${discoveryStatus.name}'
        '|ar=${arOnly ? 1 : 0}'
        '|favorites=${favoritesOnly ? 1 : 0}'
        '|layers=$layers';
  }

  KubusMapFilterState copyWith({
    KubusMapScope? scope,
    double? nearMeRadiusKm,
    KubusMapDiscoveryStatus? discoveryStatus,
    bool? arOnly,
    bool? favoritesOnly,
    Set<ArtMarkerType>? visibleContentLayers,
  }) {
    final next = KubusMapFilterState(
      scope: scope ?? this.scope,
      nearMeRadiusKm: nearMeRadiusKm ?? this.nearMeRadiusKm,
      discoveryStatus: discoveryStatus ?? this.discoveryStatus,
      arOnly: arOnly ?? this.arOnly,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      visibleContentLayers: visibleContentLayers ?? this.visibleContentLayers,
    );
    return next == this ? this : next;
  }

  KubusMapFilterState withScope(KubusMapScope value) => copyWith(scope: value);

  /// Updates the radius and activates the scope it belongs to.
  KubusMapFilterState withNearMeRadiusKm(double value) => copyWith(
        scope: KubusMapScope.nearMe,
        nearMeRadiusKm: value,
      );

  KubusMapFilterState withDiscoveryStatus(
    KubusMapDiscoveryStatus value,
  ) =>
      copyWith(discoveryStatus: value);

  KubusMapFilterState withArOnly(bool value) => copyWith(arOnly: value);

  KubusMapFilterState withFavoritesOnly(bool value) =>
      copyWith(favoritesOnly: value);

  /// Changes one layer while preserving the non-empty-layer invariant.
  KubusMapFilterState withContentLayerVisibility(
    ArtMarkerType type, {
    required bool visible,
  }) {
    final currentlyVisible = visibleContentLayers.contains(type);
    if (currentlyVisible == visible) return this;
    if (!visible && visibleContentLayers.length == 1) return this;

    final nextLayers = Set<ArtMarkerType>.of(visibleContentLayers);
    if (visible) {
      nextLayers.add(type);
    } else {
      nextLayers.remove(type);
    }
    return copyWith(visibleContentLayers: nextLayers);
  }

  KubusMapFilterState toggleContentLayer(ArtMarkerType type) =>
      withContentLayerVisibility(
        type,
        visible: !visibleContentLayers.contains(type),
      );

  KubusMapFilterState withAllContentLayersVisible() =>
      copyWith(visibleContentLayers: allContentLayers);

  KubusMapFilterState reset() => KubusMapFilterState.defaults();

  static double _normalizeRadius(double value) {
    if (value.isNaN) return defaultNearMeRadiusKm;
    if (value == double.infinity) return maxNearMeRadiusKm;
    if (value == double.negativeInfinity) return minNearMeRadiusKm;
    final clamped = value.clamp(minNearMeRadiusKm, maxNearMeRadiusKm);
    return (clamped * 10).roundToDouble() / 10;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KubusMapFilterState &&
            other.scope == scope &&
            other.nearMeRadiusKm == nearMeRadiusKm &&
            other.discoveryStatus == discoveryStatus &&
            other.arOnly == arOnly &&
            other.favoritesOnly == favoritesOnly &&
            setEquals(other.visibleContentLayers, visibleContentLayers);
  }

  @override
  int get hashCode {
    final orderedLayers = ArtMarkerType.values
        .where(visibleContentLayers.contains)
        .toList(growable: false);
    return Object.hash(
      scope,
      nearMeRadiusKm,
      discoveryStatus,
      arOnly,
      favoritesOnly,
      Object.hashAll(orderedLayers),
    );
  }
}
