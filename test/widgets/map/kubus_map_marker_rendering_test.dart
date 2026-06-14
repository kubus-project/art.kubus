import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/map_marker_icon_ids.dart';
import 'package:art_kubus/widgets/art_marker_cube.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_rendering.dart';

ArtMarker _marker(
  String id,
  LatLng pos, {
  ArtMarkerType type = ArtMarkerType.artwork,
}) {
  return ArtMarker(
    id: id,
    name: 'm$id',
    description: '',
    position: pos,
    type: type,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

void main() {
  test('kubusClusterMarkersByGridLevel groups markers and computes centroid', () {
    final a = _marker('a', const LatLng(52.0, 13.0));
    final b = _marker('b', const LatLng(52.0, 13.0));
    final c = _marker('c', const LatLng(48.0, 2.0));

    final buckets = kubusClusterMarkersByGridLevel([a, b, c], 20);

    expect(buckets.length, 2);

    final two = buckets.firstWhere((b) => b.markers.length == 2);
    expect(two.centroid.latitude, 52.0);
    expect(two.centroid.longitude, 13.0);

    final one = buckets.firstWhere((b) => b.markers.length == 1);
    expect(one.markers.single.id, 'c');
  });

  test('kubusClusterMarkersByGridLevel can sort largest clusters first', () {
    final a = _marker('a', const LatLng(52.0, 13.0));
    final b = _marker('b', const LatLng(52.0, 13.0));
    final c = _marker('c', const LatLng(52.0, 13.0));
    final d = _marker('d', const LatLng(48.0, 2.0));

    final buckets = kubusClusterMarkersByGridLevel(
      [a, b, c, d],
      20,
      sortBySizeDesc: true,
    );

    expect(buckets.first.markers.length, 3);
    expect(buckets.last.markers.length, 1);
  });

  test('kubusClusterCategoryBreakdown orders categories dominant-first', () {
    final markers = <ArtMarker>[
      _marker('a1', const LatLng(52.0, 13.0), type: ArtMarkerType.artwork),
      _marker('a2', const LatLng(52.0, 13.0), type: ArtMarkerType.artwork),
      _marker('s1', const LatLng(52.0, 13.0), type: ArtMarkerType.streetArt),
      _marker('s2', const LatLng(52.0, 13.0), type: ArtMarkerType.streetArt),
      _marker('s3', const LatLng(52.0, 13.0), type: ArtMarkerType.streetArt),
      _marker('e1', const LatLng(52.0, 13.0), type: ArtMarkerType.event),
    ];

    final breakdown = kubusClusterCategoryBreakdown(markers);

    expect(breakdown.length, 3);
    // Dominant first: streetArt (3), artwork (2), event (1).
    expect(breakdown[0].type, ArtMarkerType.streetArt);
    expect(breakdown[0].count, 3);
    expect(breakdown[1].type, ArtMarkerType.artwork);
    expect(breakdown[1].count, 2);
    expect(breakdown[2].type, ArtMarkerType.event);
    expect(breakdown[2].count, 1);
  });

  test('kubusClusterCategorySignature is stable and composition-aware', () {
    final mixed = <ArtMarker>[
      _marker('a', const LatLng(1, 1), type: ArtMarkerType.artwork),
      _marker('b', const LatLng(1, 1), type: ArtMarkerType.event),
    ];
    final single = <ArtMarker>[
      _marker('c', const LatLng(1, 1), type: ArtMarkerType.artwork),
      _marker('d', const LatLng(1, 1), type: ArtMarkerType.artwork),
    ];

    final mixedSig =
        kubusClusterCategorySignature(kubusClusterCategoryBreakdown(mixed));
    final singleSig =
        kubusClusterCategorySignature(kubusClusterCategoryBreakdown(single));

    expect(mixedSig, isNot(equals(singleSig)));
    expect(singleSig, 'artwork');
    expect(mixedSig.split('-').length, 2);
  });

  test('kubusClusterCategorySignature caps at the max badge categories', () {
    final types = ArtMarkerType.values;
    final markers = <ArtMarker>[
      for (var i = 0; i < types.length; i++)
        _marker('m$i', const LatLng(1, 1), type: types[i]),
    ];

    final signature =
        kubusClusterCategorySignature(kubusClusterCategoryBreakdown(markers));

    expect(signature.split('-').length, kKubusClusterMaxBadgeCategories);
  });

  group('cluster badge render data', () {
    final scheme = const ColorScheme.dark();
    const roles = KubusColorRoles.dark;
    IconData resolveIcon(ArtMarkerType type) =>
        KubusMapMarkerHelpers.resolveArtMarkerIcon(type);

    test('mixed cluster yields distinct shapes, colours and icons', () {
      final markers = <ArtMarker>[
        _marker('a', const LatLng(1, 1), type: ArtMarkerType.artwork),
        _marker('s', const LatLng(1, 1), type: ArtMarkerType.streetArt),
        _marker('e', const LatLng(1, 1), type: ArtMarkerType.event),
      ];

      final data = kubusClusterBadgeRenderData(
        markers,
        scheme: scheme,
        roles: roles,
        resolveIcon: resolveIcon,
      );

      expect(data.badges.length, 3);
      // Each visible category carries shape + colour + icon.
      expect(data.badges.map((b) => b.shape).toSet().length, 3);
      expect(data.badges.map((b) => b.color.toARGB32()).toSet().length,
          greaterThan(1));
      expect(data.badges.map((b) => b.icon.codePoint).toSet().length, 3);
      // Glyphs are real (non-zero) icon code points, not just coloured pips.
      expect(data.badges.every((b) => b.icon.codePoint != 0), isTrue);
    });

    test('single-category cluster keeps that category identity (not generic)',
        () {
      final markers = <ArtMarker>[
        _marker('a', const LatLng(1, 1), type: ArtMarkerType.streetArt),
        _marker('b', const LatLng(1, 1), type: ArtMarkerType.streetArt),
      ];

      final data = kubusClusterBadgeRenderData(
        markers,
        scheme: scheme,
        roles: roles,
        resolveIcon: resolveIcon,
      );

      expect(data.badges.length, 1);
      final badge = data.badges.single;
      expect(badge.shape, ArtMapMarkerShape.forType(ArtMarkerType.streetArt));
      // Generic circle is only the no-category fallback; a real category never
      // resolves to it here (streetArt => diamond).
      expect(badge.shape, isNot(ArtMapMarkerShape.circle));
      expect(badge.icon.codePoint,
          resolveIcon(ArtMarkerType.streetArt).codePoint);
      expect(badge.count, 2);
    });

    test('filtered marker list drives cluster composition', () {
      final all = <ArtMarker>[
        _marker('a', const LatLng(1, 1), type: ArtMarkerType.artwork),
        _marker('e', const LatLng(1, 1), type: ArtMarkerType.event),
      ];
      // Simulate a filter that removes events.
      final filtered =
          all.where((m) => m.type == ArtMarkerType.artwork).toList();

      final allData = kubusClusterBadgeRenderData(
        all,
        scheme: scheme,
        roles: roles,
        resolveIcon: resolveIcon,
      );
      final filteredData = kubusClusterBadgeRenderData(
        filtered,
        scheme: scheme,
        roles: roles,
        resolveIcon: resolveIcon,
      );

      expect(allData.badges.length, 2);
      expect(filteredData.badges.length, 1);
      expect(filteredData.badges.single.shape,
          ArtMapMarkerShape.forType(ArtMarkerType.artwork));
    });
  });

  group('cluster icon id', () {
    test('changes when category composition changes', () {
      final mixed = kubusClusterCategorySignature(
        kubusClusterCategoryBreakdown(<ArtMarker>[
          _marker('a', const LatLng(1, 1), type: ArtMarkerType.artwork),
          _marker('e', const LatLng(1, 1), type: ArtMarkerType.event),
        ]),
      );
      final single = kubusClusterCategorySignature(
        kubusClusterCategoryBreakdown(<ArtMarker>[
          _marker('a', const LatLng(1, 1), type: ArtMarkerType.artwork),
        ]),
      );

      final mixedId = MapMarkerIconIds.cluster(
        categorySignature: mixed,
        label: '2',
        isDark: true,
      );
      final singleId = MapMarkerIconIds.cluster(
        categorySignature: single,
        label: '2',
        isDark: true,
      );

      expect(mixedId, isNot(singleId));
    });

    test('embeds the renderer version so stale circle icons are not reused',
        () {
      final id = MapMarkerIconIds.cluster(
        categorySignature: 'artwork',
        label: '3',
        isDark: false,
      );
      expect(id, contains(MapMarkerIconIds.clusterRendererVersion));
    });
  });
}
