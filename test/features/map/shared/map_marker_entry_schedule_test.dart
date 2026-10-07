import 'package:art_kubus/features/map/shared/map_marker_entry_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const center = LatLng(46.05, 14.50);
  final positions = <String, LatLng>{
    'far': const LatLng(46.09, 14.50),
    'near': const LatLng(46.051, 14.50),
    'mid': const LatLng(46.06, 14.50),
  };

  Map<String, int> offsets(
    Iterable<String> ids, {
    int maxStepMs = 36,
    int maxSpreadMs = 360,
    LatLng? centre = center,
  }) =>
      kubusEntryRevealOffsets(
        ids: ids,
        positionOf: (id) => positions[id],
        center: centre,
        maxStepMs: maxStepMs,
        maxSpreadMs: maxSpreadMs,
      );

  test('reveals from the viewport centre outwards', () {
    final result = offsets(<String>['far', 'mid', 'near']);
    expect(result['near'], 0);
    expect(result['mid'], 36);
    expect(result['far'], 72);
  });

  test('a large wave is compressed into the spread cap', () {
    final ids = <String>[for (var i = 0; i < 56; i++) 'm$i'];
    for (var i = 0; i < ids.length; i++) {
      positions[ids[i]] = LatLng(46.05 + i * 0.0001, 14.5);
    }
    final result = offsets(ids, maxSpreadMs: 240);
    expect(result.length, 56);
    expect(result.values.reduce((a, b) => a > b ? a : b), 240);
    expect(result['m0'], 0);
    final ordered = ids.map((id) => result[id]!).toList();
    for (var i = 1; i < ordered.length; i++) {
      expect(ordered[i], greaterThanOrEqualTo(ordered[i - 1]));
    }
  });

  test('markers without a position come last, deterministically', () {
    final result = offsets(<String>['zz-unknown', 'near', 'aa-unknown']);
    expect(result['near'], 0);
    expect(result['aa-unknown'], 36);
    expect(result['zz-unknown'], 72);
  });

  test('a single marker and an empty set have no stagger', () {
    expect(offsets(<String>['near']), <String, int>{'near': 0});
    expect(offsets(const <String>[]), isEmpty);
  });

  test('without a camera frame the order falls back to ids', () {
    final result = offsets(<String>['mid', 'far', 'near'], centre: null);
    expect(result, <String, int>{'far': 0, 'mid': 36, 'near': 72});
  });
}
