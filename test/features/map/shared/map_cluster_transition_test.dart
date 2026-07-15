import 'package:art_kubus/features/map/shared/map_cluster_transition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

KubusClusterTransitionNode _node(
  String id,
  Set<String> members,
  double latitude,
  double longitude,
) {
  return KubusClusterTransitionNode(
    id: id,
    memberIds: members,
    position: LatLng(latitude, longitude),
  );
}

void main() {
  test('children originate from their previous parent cluster', () {
    final parent = _node('parent', <String>{'a', 'b'}, 46, 14);
    final child = _node('a', <String>{'a'}, 46.1, 14.1);

    expect(
      resolveKubusClusterTransitionOrigin(
        target: child,
        previous: <KubusClusterTransitionNode>[parent],
      ),
      const LatLng(46, 14),
    );
  });

  test('merged cluster originates at weighted child centroid', () {
    final target = _node('parent', <String>{'a', 'b', 'c'}, 46, 14);
    final previous = <KubusClusterTransitionNode>[
      _node('a', <String>{'a'}, 45, 13),
      _node('bc', <String>{'b', 'c'}, 48, 16),
    ];

    final origin = resolveKubusClusterTransitionOrigin(
      target: target,
      previous: previous,
    );
    expect(origin!.latitude, 47);
    expect(origin.longitude, 15);
  });

  test('interpolation clamps progress and progress normalizes opacity', () {
    expect(
      interpolateKubusClusterPosition(
        const LatLng(0, 0),
        const LatLng(10, 20),
        0.5,
      ),
      const LatLng(5, 10),
    );
    expect(
      kubusClusterRegroupProgress(
        entryOpacities: const <double>[0.55, 1],
        startOpacity: 0.55,
      ),
      0,
    );
    expect(
      kubusClusterRegroupProgress(
        entryOpacities: const <double>[1, 1],
        startOpacity: 0.55,
      ),
      1,
    );
    expect(
      kubusClusterRegroupProgress(
        entryOpacities: const <double>[0, 0.55, 1],
        startOpacity: 0.55,
      ),
      0,
      reason: 'off-screen entries must not pin a visible regroup transition',
    );
    expect(
      kubusClusterRegroupProgress(
        entryOpacities: const <double>[0, 0],
        startOpacity: 0.55,
      ),
      1,
      reason: 'a fully off-screen topology commits without an invisible tween',
    );
  });
}
