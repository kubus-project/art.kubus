import 'package:art_kubus/features/map/shared/map_marker_regroup_gate.dart';
import 'package:art_kubus/features/map/shared/map_marker_selection_resolver.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/art_marker_list_diff.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_features.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_geojson_builder.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker(String id, double lat, double lng) {
  return ArtMarker(
    id: id,
    name: id,
    description: '',
    position: LatLng(lat, lng),
    type: ArtMarkerType.artwork,
    createdAt: DateTime.utc(2026, 1, 1),
    createdBy: 'test',
  );
}

Set<String> _clusterMembers(List<KubusClusterBucket> buckets) => {
      for (final b in buckets)
        if (b.markers.length > 1) ...b.markers.map((m) => m.id),
    };

void main() {
  // Three markers a few metres apart (one grid cell at any plausible level)
  // plus one far away.
  final near1 = _marker('n1', 46.0500, 14.5000);
  final near2 = _marker('n2', 46.0501, 14.5001);
  final near3 = _marker('n3', 46.0502, 14.5002);
  final far = _marker('far', 48.0, 16.0);
  final all = [near1, near2, near3, far];
  const level = 6;

  group('selected marker pinned out of clusters', () {
    test('without a selection the near markers cluster together', () {
      final buckets = kubusClusterBucketsWithPinned(all, level);
      expect(_clusterMembers(buckets), containsAll(<String>['n1', 'n2', 'n3']));
    });

    test('the selected marker is its own bucket, not absorbed by a cluster',
        () {
      final buckets = kubusClusterBucketsWithPinned(
        all,
        level,
        pinnedMarkerIds: <String>{'n2'},
      );
      final single = buckets.where((b) => b.markers.length == 1).toList();
      expect(single.any((b) => b.markers.single.id == 'n2'), isTrue);
      expect(_clusterMembers(buckets), isNot(contains('n2')));
      // The others still cluster: pinning one marker does not explode the map.
      expect(_clusterMembers(buckets), containsAll(<String>['n1', 'n3']));
    });

    test('nothing is lost: every marker appears exactly once', () {
      final buckets = kubusClusterBucketsWithPinned(
        all,
        level,
        pinnedMarkerIds: <String>{'n2', 'far'},
      );
      final ids = [for (final b in buckets) ...b.markers.map((m) => m.id)];
      expect(ids..sort(), <String>['far', 'n1', 'n2', 'n3']);
    });

    test('a pinned id that is not loaded changes nothing', () {
      final plain = kubusClusterBucketsWithPinned(all, level);
      final pinned = kubusClusterBucketsWithPinned(
        all,
        level,
        pinnedMarkerIds: <String>{'missing'},
      );
      expect(pinned.length, plain.length);
    });

    test('a selected marker inside a same-coordinate stack stays in the stack',
        () {
      final a = _marker('a', 46.05, 14.5);
      final b = _marker('b', 46.05, 14.5);
      final buckets = kubusClusterBucketsWithPinned(
        [a, b, far],
        level,
        pinnedMarkerIds: <String>{'a'},
      );
      final stack = buckets.firstWhere((x) => x.markers.length == 2);
      expect(stack.markers.map((m) => m.id), containsAll(<String>['a', 'b']));
      expect(stack.sameCoordinateKey, isNotNull);
    });

    test('the feature list emits the pinned marker as a marker feature',
        () async {
      final features = await kubusBuildMarkerFeatureList(
        markers: all,
        useClustering: true,
        zoom: 4,
        clusterGridLevelForZoom: (_) => level,
        sortClustersBySizeDesc: false,
        shouldAbort: () => false,
        pinnedMarkerIds: <String>{'n2'},
        buildMarkerFeature: (m) async =>
            <String, dynamic>{'kind': 'marker', 'id': m.id},
        buildClusterFeature: (c) async => <String, dynamic>{
          'kind': 'cluster',
          'members': c.markers.map((m) => m.id).toList(),
        },
      );
      expect(
        features.where((f) => f['kind'] == 'marker').map((f) => f['id']),
        containsAll(<String>['n2', 'far']),
      );
      final clusters = features.where((f) => f['kind'] == 'cluster').toList();
      expect(clusters, hasLength(1));
      expect(clusters.single['members'], isNot(contains('n2')));
    });
  });

  group('far-level features', () {
    test('carry the same properties as a full feature with a blank icon', () {
      final feature = kubusFarMarkerFeature(
        marker: near1,
        colorHex: '#ff8800',
        blankIconId: 'blank',
        entryScale: 0.9,
        entryOpacity: 0.5,
        coordinateKey: 'k',
        entrySerial: 3,
      );
      final props = feature['properties'] as Map<String, dynamic>;
      expect(feature['id'], 'n1');
      expect(props['id'], 'n1');
      expect(props['markerId'], 'n1');
      expect(props['kind'], 'marker');
      expect(props['icon'], 'blank');
      expect(props['iconSelected'], 'blank');
      expect(props['color'], '#ff8800');
      expect(props['coordinateKey'], 'k');
      expect(props['entrySerial'], 3);
      expect(props['entryOpacity'], 0.5);
      final geometry = feature['geometry'] as Map<String, dynamic>;
      expect(geometry['coordinates'], <double>[14.5, 46.05]);
    });

    test('a far marker honours a spiderfy position override', () {
      final feature = kubusFarMarkerFeature(
        marker: near1,
        colorHex: '#000000',
        blankIconId: 'blank',
        positionOverride: const LatLng(1, 2),
        spiderfied: true,
      );
      expect(
        (feature['geometry'] as Map)['coordinates'],
        <double>[2.0, 1.0],
      );
      expect((feature['properties'] as Map)['isSpiderfied'], isTrue);
    });
  });

  group('viewport refresh keeps what the visitor is looking at', () {
    final selected = _marker('sel', 10, 10);
    final direct = _marker('direct', 11, 11);
    final temp = _marker('${kSearchTemporaryMarkerPrefix}artwork-1', 12, 12);
    final ordinary = _marker('ordinary', 13, 13);

    test('carries the selected marker over even if the new bounds drop it', () {
      final kept = markersPreservedAcrossViewportRefresh(
        [selected, ordinary],
        selectedMarkerId: 'sel',
      ).map((m) => m.id);
      expect(kept, <String>['sel']);
    });

    test('also carries the deep-link target and search temporaries', () {
      final kept = markersPreservedAcrossViewportRefresh(
        [selected, direct, temp, ordinary],
        selectedMarkerId: 'sel',
        directTargetMarkerId: 'direct',
      ).map((m) => m.id).toSet();
      expect(kept, <String>{
        'sel',
        'direct',
        '${kSearchTemporaryMarkerPrefix}artwork-1'
      });
    });

    test('with no selection and no target only temporaries survive', () {
      final kept = markersPreservedAcrossViewportRefresh(
        [selected, direct, temp, ordinary],
      ).map((m) => m.id);
      expect(kept, <String>['${kSearchTemporaryMarkerPrefix}artwork-1']);
    });

    test('a selected marker the response returned is not carried over', () {
      final kept = markersPreservedAcrossViewportRefresh(
        [selected, ordinary],
        selectedMarkerId: 'sel',
        fetched: [selected, ordinary],
      ).map((m) => m.id);
      expect(kept, isEmpty);
    });

    test('the fresh selected record wins over the loaded copy in the merge',
        () {
      final fresh = selected.copyWith(name: 'fresh name');
      final merged = ArtMarkerListDiff.upsertById(
        current: [fresh, ordinary],
        updates: markersPreservedAcrossViewportRefresh(
          [selected, ordinary],
          selectedMarkerId: 'sel',
          fetched: [fresh, ordinary],
        ),
      );
      expect(merged.firstWhere((m) => m.id == 'sel').name, 'fresh name');
    });

    test('a selected marker the response omitted is still carried over', () {
      final merged = ArtMarkerListDiff.upsertById(
        current: [ordinary],
        updates: markersPreservedAcrossViewportRefresh(
          [selected, ordinary],
          selectedMarkerId: 'sel',
          fetched: [ordinary],
        ),
      );
      expect(
          merged.map((m) => m.id), containsAll(<String>['sel', ordinary.id]));
    });

    test('blank ids never match everything', () {
      expect(
        markersPreservedAcrossViewportRefresh(
          [selected, ordinary],
          selectedMarkerId: '  ',
          directTargetMarkerId: '',
        ),
        isEmpty,
      );
    });
  });

  group('regroup gate', () {
    int grid(double zoom) => zoom.floor();

    KubusMarkerRegroup step(KubusMarkerRegroupGate gate, double zoom) =>
        gate.update(zoom: zoom, clusterMaxZoom: 12, gridLevelForZoom: grid);

    test('the first reading is a topology change; repeating it is none', () {
      final gate = KubusMarkerRegroupGate();
      expect(step(gate, 4.2), KubusMarkerRegroup.topology);
      expect(step(gate, 4.4), KubusMarkerRegroup.none);
    });

    test('a grid level change regroups', () {
      final gate = KubusMarkerRegroupGate();
      step(gate, 8.2);
      expect(step(gate, 9.1), KubusMarkerRegroup.topology);
    });

    test('crossing into the blend band rewrites artwork without regrouping',
        () {
      final gate = KubusMarkerRegroupGate();
      step(gate, 5.2);
      // Same grid level (floor 5), but marker artwork is now needed.
      expect(step(gate, 5.6), KubusMarkerRegroup.visual);
      expect(step(gate, 5.9), KubusMarkerRegroup.none);
    });

    test('each cover stage is a visual change, not a regroup', () {
      final gate = KubusMarkerRegroupGate();
      step(gate, 12.1);
      // Past clusterMaxZoom there is no grid; covers display from 12.5 for
      // every eligible marker, so there is no further stage beyond it.
      expect(step(gate, 12.3), KubusMarkerRegroup.none);
      expect(step(gate, 12.6), KubusMarkerRegroup.visual);
      expect(step(gate, 13.0), KubusMarkerRegroup.none);
      expect(step(gate, 13.6), KubusMarkerRegroup.none);
      expect(step(gate, 14.6), KubusMarkerRegroup.none);
      expect(step(gate, 16.0), KubusMarkerRegroup.none);
    });

    test('rapid zoom in and out reports every boundary it crosses', () {
      final gate = KubusMarkerRegroupGate();
      final seen = <KubusMarkerRegroup>[];
      for (final zoom in <double>[3, 5.6, 6.5, 9.5, 12.5, 15.5, 12.5, 5.6, 3]) {
        seen.add(step(gate, zoom));
      }
      expect(seen.where((c) => c != KubusMarkerRegroup.none), isNotEmpty);
      expect(seen.first, KubusMarkerRegroup.topology);
    });

    test('jitter around the street threshold does not flip the grouping', () {
      final gate = KubusMarkerRegroupGate();
      expect(step(gate, 11.94), KubusMarkerRegroup.topology);
      expect(step(gate, 12.06), KubusMarkerRegroup.topology,
          reason: 'zooming in crosses the threshold exactly where it was');
      expect(gate.clusteringAt(12.06, clusterMaxZoom: 12), isFalse);
      final changes = <KubusMarkerRegroup>[
        for (var i = 0; i < 12; i++) step(gate, i.isEven ? 11.94 : 12.06),
      ];
      expect(changes, everyElement(KubusMarkerRegroup.none));
      expect(gate.clusteringAt(11.94, clusterMaxZoom: 12), isFalse);
    });

    test('a deliberate zoom-out regroups once the play is used up', () {
      final gate = KubusMarkerRegroupGate();
      step(gate, 12.4);
      expect(step(gate, 11.85), KubusMarkerRegroup.none,
          reason: 'one wheel notch (~0.15) below the threshold keeps markers');
      expect(step(gate, 11.7), KubusMarkerRegroup.topology);
      expect(gate.clusteringAt(11.7, clusterMaxZoom: 12), isTrue);
      expect(step(gate, 11.95), KubusMarkerRegroup.none);
      expect(step(gate, 12.0), KubusMarkerRegroup.topology,
          reason: 'entering individual markers always happens at A');
    });

    test('topology zoom follows zoom-in at once and lags zoom-out by the play',
        () {
      final gate = KubusMarkerRegroupGate();
      expect(gate.topologyZoomFor(9), 9, reason: 'no state yet: the camera');
      step(gate, 10);
      expect(gate.topologyZoomFor(10.6), 10.6);
      expect(gate.topologyZoomFor(9.9), 10);
      expect(gate.topologyZoomFor(9.5),
          closeTo(9.5 + KubusMarkerRegroupGate.defaultTopologyPlay, 1e-9));
    });

    test('grid levels get the same slack as the street threshold', () {
      final gate = KubusMarkerRegroupGate();
      step(gate, 9.02);
      expect(step(gate, 8.95), KubusMarkerRegroup.none);
      expect(step(gate, 9.05), KubusMarkerRegroup.none);
      expect(step(gate, 8.7), KubusMarkerRegroup.topology);
    });
  });
}
