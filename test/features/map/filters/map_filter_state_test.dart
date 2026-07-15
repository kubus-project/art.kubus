import 'package:art_kubus/features/map/filters/map_filter_state.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KubusMapFilterState defaults', () {
    test('starts map-first with every content layer visible', () {
      final state = KubusMapFilterState.defaults();

      expect(state.scope, KubusMapScope.currentViewport);
      expect(state.nearMeRadiusKm, 5.0);
      expect(state.discoveryStatus, KubusMapDiscoveryStatus.all);
      expect(state.arOnly, isFalse);
      expect(state.favoritesOnly, isFalse);
      expect(state.visibleContentLayers, KubusMapFilterState.allContentLayers);
      expect(state.activeFilterCount, 0);
      expect(state.activeSummaries, isEmpty);
      expect(state.isDefault, isTrue);
    });

    test('reset returns a fresh default state', () {
      final changed = KubusMapFilterState(
        scope: KubusMapScope.travel,
        discoveryStatus: KubusMapDiscoveryStatus.discovered,
        arOnly: true,
        favoritesOnly: true,
        visibleContentLayers: const <ArtMarkerType>{ArtMarkerType.event},
      );

      expect(changed.reset(), KubusMapFilterState.defaults());
      expect(changed.reset().isDefault, isTrue);
    });
  });

  group('exclusive and independent concepts', () {
    test('scope updates replace rather than combine choices', () {
      final state = KubusMapFilterState.defaults()
          .withScope(KubusMapScope.nearMe)
          .withScope(KubusMapScope.travel);

      expect(state.scope, KubusMapScope.travel);
      expect(state.activeFilterCount, 1);
    });

    test('discovery updates replace rather than combine choices', () {
      final state = KubusMapFilterState.defaults()
          .withDiscoveryStatus(KubusMapDiscoveryStatus.undiscovered)
          .withDiscoveryStatus(KubusMapDiscoveryStatus.discovered);

      expect(state.discoveryStatus, KubusMapDiscoveryStatus.discovered);
      expect(state.activeFilterCount, 1);
    });

    test('AR and favorites attributes compose independently', () {
      final state = KubusMapFilterState.defaults()
          .withArOnly(true)
          .withFavoritesOnly(true);

      expect(state.arOnly, isTrue);
      expect(state.favoritesOnly, isTrue);
      expect(state.activeFilterCount, 2);

      final arDisabled = state.withArOnly(false);
      expect(arDisabled.arOnly, isFalse);
      expect(arDisabled.favoritesOnly, isTrue);
      expect(arDisabled.activeFilterCount, 1);
    });
  });

  group('near-me radius', () {
    test('clamps finite values and normalizes to a tenth of a kilometre', () {
      expect(
        KubusMapFilterState(nearMeRadiusKm: -20).nearMeRadiusKm,
        KubusMapFilterState.minNearMeRadiusKm,
      );
      expect(
        KubusMapFilterState(nearMeRadiusKm: 400).nearMeRadiusKm,
        KubusMapFilterState.maxNearMeRadiusKm,
      );
      expect(KubusMapFilterState(nearMeRadiusKm: 5.04).nearMeRadiusKm, 5.0);
      expect(KubusMapFilterState(nearMeRadiusKm: 5.06).nearMeRadiusKm, 5.1);
    });

    test('normalizes non-finite input safely', () {
      expect(
        KubusMapFilterState(nearMeRadiusKm: double.nan).nearMeRadiusKm,
        KubusMapFilterState.defaultNearMeRadiusKm,
      );
      expect(
        KubusMapFilterState(nearMeRadiusKm: double.infinity).nearMeRadiusKm,
        KubusMapFilterState.maxNearMeRadiusKm,
      );
      expect(
        KubusMapFilterState(nearMeRadiusKm: double.negativeInfinity)
            .nearMeRadiusKm,
        KubusMapFilterState.minNearMeRadiusKm,
      );
    });

    test('radius helper activates the near-me scope', () {
      final state = KubusMapFilterState.defaults().withNearMeRadiusKm(12.26);

      expect(state.scope, KubusMapScope.nearMe);
      expect(state.nearMeRadiusKm, 12.3);
      expect(state.activeFilterCount, 1);
    });
  });

  group('content-layer invariant', () {
    test('constructor rejects an empty layer set', () {
      expect(
        () => KubusMapFilterState(
          visibleContentLayers: const <ArtMarkerType>{},
        ),
        throwsArgumentError,
      );
    });

    test('attempting to hide the final visible layer is a no-op', () {
      final singleLayer = KubusMapFilterState(
        visibleContentLayers: const <ArtMarkerType>{ArtMarkerType.artwork},
      );

      final result = singleLayer.withContentLayerVisibility(
        ArtMarkerType.artwork,
        visible: false,
      );

      expect(identical(result, singleLayer), isTrue);
      expect(
          result.visibleContentLayers, <ArtMarkerType>{ArtMarkerType.artwork});
    });

    test('layers toggle independently and can be restored together', () {
      final initial = KubusMapFilterState.defaults();
      final hiddenArtwork = initial.toggleContentLayer(ArtMarkerType.artwork);
      final hiddenArtworkAndEvent =
          hiddenArtwork.toggleContentLayer(ArtMarkerType.event);

      expect(
        hiddenArtworkAndEvent.visibleContentLayers,
        isNot(contains(ArtMarkerType.artwork)),
      );
      expect(
        hiddenArtworkAndEvent.visibleContentLayers,
        isNot(contains(ArtMarkerType.event)),
      );
      expect(hiddenArtworkAndEvent.activeFilterCount, 2);
      expect(
        hiddenArtworkAndEvent.withAllContentLayersVisible(),
        KubusMapFilterState.defaults(),
      );
    });

    test('defensively copies the caller layer set', () {
      final layers = <ArtMarkerType>{ArtMarkerType.artwork};
      final state = KubusMapFilterState(visibleContentLayers: layers);

      layers.add(ArtMarkerType.event);

      expect(
          state.visibleContentLayers, <ArtMarkerType>{ArtMarkerType.artwork});
      expect(
        () => state.visibleContentLayers.add(ArtMarkerType.event),
        throwsUnsupportedError,
      );
    });
  });

  group('active count and summaries', () {
    test('count follows documented semantic dimensions', () {
      final state = KubusMapFilterState(
        scope: KubusMapScope.nearMe,
        nearMeRadiusKm: 8.0,
        discoveryStatus: KubusMapDiscoveryStatus.undiscovered,
        arOnly: true,
        favoritesOnly: true,
        visibleContentLayers: ArtMarkerType.values
            .where(
              (type) =>
                  type != ArtMarkerType.event &&
                  type != ArtMarkerType.institution,
            )
            .toSet(),
      );

      expect(state.activeFilterCount, 6);
      expect(
        state.activeSummaries.map((summary) => summary.kind),
        <KubusMapFilterSummaryKind>[
          KubusMapFilterSummaryKind.scope,
          KubusMapFilterSummaryKind.discoveryStatus,
          KubusMapFilterSummaryKind.arOnly,
          KubusMapFilterSummaryKind.favoritesOnly,
          KubusMapFilterSummaryKind.hiddenContentLayer,
          KubusMapFilterSummaryKind.hiddenContentLayer,
        ],
      );
      expect(state.activeSummaries.first.scope, KubusMapScope.nearMe);
      expect(state.activeSummaries.first.nearMeRadiusKm, 8.0);
      expect(
        state.activeSummaries.map((summary) => summary.stableKey),
        containsAll(<String>[
          'scope:nearMe:8.0',
          'discovery:undiscovered',
          'attribute:ar',
          'attribute:favorites',
          'hidden-layer:event',
          'hidden-layer:institution',
        ]),
      );
    });

    test('travel scope summary does not expose an irrelevant radius', () {
      final summary = KubusMapFilterState(
        scope: KubusMapScope.travel,
        nearMeRadiusKm: 42,
      ).activeSummaries.single;

      expect(summary.scope, KubusMapScope.travel);
      expect(summary.nearMeRadiusKm, isNull);
      expect(summary.stableKey, 'scope:travel:-');
    });
  });

  group('identity and fingerprint', () {
    test('equality and hash ignore input set insertion order', () {
      final first = KubusMapFilterState(
        visibleContentLayers: const <ArtMarkerType>{
          ArtMarkerType.artwork,
          ArtMarkerType.event,
        },
      );
      final second = KubusMapFilterState(
        visibleContentLayers: const <ArtMarkerType>{
          ArtMarkerType.event,
          ArtMarkerType.artwork,
        },
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.queryFingerprint, second.queryFingerprint);
    });

    test('fingerprint is versioned, deterministic, and state-sensitive', () {
      final state = KubusMapFilterState(
        scope: KubusMapScope.nearMe,
        nearMeRadiusKm: 7.06,
        discoveryStatus: KubusMapDiscoveryStatus.discovered,
        arOnly: true,
        favoritesOnly: true,
        visibleContentLayers: const <ArtMarkerType>{
          ArtMarkerType.event,
          ArtMarkerType.artwork,
        },
      );

      expect(
        state.queryFingerprint,
        'v1|scope=nearMe|radius=7.1|discovery=discovered|ar=1'
        '|favorites=1|layers=artwork,event',
      );
      expect(
        state.withArOnly(false).queryFingerprint,
        isNot(state.queryFingerprint),
      );
    });

    test('copy and helpers preserve identity for semantic no-ops', () {
      final state = KubusMapFilterState.defaults();

      expect(identical(state.copyWith(), state), isTrue);
      expect(
        identical(state.withScope(KubusMapScope.currentViewport), state),
        isTrue,
      );
      expect(identical(state.withArOnly(false), state), isTrue);
      expect(
        identical(
          state.withContentLayerVisibility(
            ArtMarkerType.artwork,
            visible: true,
          ),
          state,
        ),
        isTrue,
      );
    });
  });
}
