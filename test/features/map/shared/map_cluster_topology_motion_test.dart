import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/features/map/shared/map_cluster_transition.dart';

Map<String, dynamic> feature(
        String id, List<String> members, double longitude) =>
    {
      'type': 'Feature',
      'id': id,
      'properties': <String, dynamic>{
        'id': id,
        'clusterMemberIds': members,
        'entryOpacity': 1.0,
        'entryScale': 1.0
      },
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': [longitude, 0.0]
      },
    };
double longitude(Map<String, dynamic> f) =>
    ((f['geometry'] as Map)['coordinates'] as List)[0] as double;

void main() {
  test('loaded children converge before retiring, without replaying entry', () {
    var now = 0;
    final motion =
        KubusClusterTopologyTransition(durationMs: 170, nowMs: () => now);
    motion.apply([
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ], reduceMotion: false);
    var frame = [
      feature('parent', ['a', 'b'], 5)
    ];
    expect(motion.apply(frame, reduceMotion: false), isTrue);
    expect(frame.map((f) => f['id']), ['parent', 'a', 'b']);
    expect(longitude(frame[1]), 0);
    expect(longitude(frame[2]), 10);
    expect((frame[1]['properties'] as Map)['entryScale'], 1);
    now = 85;
    frame = [
      feature('parent', ['a', 'b'], 5)
    ];
    expect(motion.apply(frame, reduceMotion: false), isTrue);
    expect(longitude(frame[1]), greaterThan(0));
    expect(longitude(frame[1]), lessThan(5));
    expect(longitude(frame[2]), greaterThan(5));
    expect(longitude(frame[2]), lessThan(10));
    now = 200;
    frame = [
      feature('parent', ['a', 'b'], 5)
    ];
    expect(motion.apply(frame, reduceMotion: false), isFalse);
    expect(frame.map((f) => f['id']), ['parent']);
    expect((frame.single['properties'] as Map)['entryOpacity'], 1);
  });

  test('split children emerge from their parent even when entry is complete',
      () {
    var now = 0;
    final motion =
        KubusClusterTopologyTransition(durationMs: 170, nowMs: () => now);
    motion.apply([
      feature('parent', ['a', 'b'], 5)
    ], reduceMotion: false);
    var frame = [
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ];
    expect(motion.apply(frame, reduceMotion: false), isTrue);
    expect(frame.map(longitude), [5, 5, 5]);
    expect(frame.last['id'], 'parent');
    expect((frame.last['properties'] as Map)['entryOpacity'], 1);
    now = 200;
    frame = [
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ];
    expect(motion.apply(frame, reduceMotion: false), isFalse);
    expect(frame.map(longitude), [0, 10]);
  });

  test('rapid reversal retargets on-screen children and emits each ID once',
      () {
    var now = 0;
    final motion =
        KubusClusterTopologyTransition(durationMs: 170, nowMs: () => now);
    motion.apply([
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ], reduceMotion: false);
    motion.apply([
      feature('parent', ['a', 'b'], 5)
    ], reduceMotion: false);
    now = 85;
    final merging = [
      feature('parent', ['a', 'b'], 5)
    ];
    motion.apply(merging, reduceMotion: false);
    final reversing = [
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ];
    expect(motion.apply(reversing, reduceMotion: false), isTrue);
    expect(longitude(reversing[0]), greaterThan(0));
    expect(longitude(reversing[1]), lessThan(10));
    for (final child in reversing.take(2)) {
      final previouslyDisplayed =
          merging.singleWhere((f) => f['id'] == child['id']);
      expect(longitude(child), longitude(previouslyDisplayed),
          reason: 'reversal starts at the exact displayed child position');
    }
    expect(reversing.map((f) => f['id']).toSet().length, reversing.length);
    now = 300;
    final settled = [
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ];
    expect(motion.apply(settled, reduceMotion: false), isFalse);
    expect(settled.map((f) => f['id']), ['a', 'b']);
  });

  test(
      'merge destination stays anchored even if a viewport refresh changes its centroid',
      () {
    var now = 0;
    final motion =
        KubusClusterTopologyTransition(durationMs: 170, nowMs: () => now);
    motion.apply([
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ], reduceMotion: false);
    motion.apply([
      feature('parent', ['a', 'b'], 6)
    ], reduceMotion: false);
    now = 70;
    final frame = [
      feature('parent', ['a', 'b'], 8)
    ];
    motion.apply(frame, reduceMotion: false);
    expect(longitude(frame.first), 6);
  });

  test('dateline split follows the shortest geographic path', () {
    var now = 0;
    final motion =
        KubusClusterTopologyTransition(durationMs: 170, nowMs: () => now);
    motion.apply([
      feature('parent', ['a', 'b'], 179)
    ], reduceMotion: false);
    motion.apply([
      feature('a', ['a'], -179),
      feature('b', ['b'], 178)
    ], reduceMotion: false);
    now = 85;
    final frame = [
      feature('a', ['a'], -179),
      feature('b', ['b'], 178)
    ];
    motion.apply(frame, reduceMotion: false);
    expect(longitude(frame.first).abs(), greaterThan(178));
  });

  test('same topology panning and cover replacement do not replay motion', () {
    final motion = KubusClusterTopologyTransition(durationMs: 170);
    motion.apply([
      feature('a', ['a'], 1)
    ], reduceMotion: false);
    final frame = [
      feature('a', ['a'], 2)
    ];
    (frame.first['properties'] as Map)['coverIcon'] = 'replacement';
    expect(motion.apply(frame, reduceMotion: false), isFalse);
    expect(longitude(frame.single), 2);
  });

  test('reduced motion and style reset discard all retiring features', () {
    final motion =
        KubusClusterTopologyTransition(durationMs: 170, nowMs: () => 0);
    motion.apply([
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ], reduceMotion: false);
    final reduced = [
      feature('parent', ['a', 'b'], 5)
    ];
    expect(motion.apply(reduced, reduceMotion: true), isFalse);
    expect(reduced, hasLength(1));
    motion.reset();
    final replacement = [
      feature('a', ['a'], 0)
    ];
    expect(motion.apply(replacement, reduceMotion: false), isFalse);
    expect(replacement, hasLength(1));
    expect(longitude(replacement.single), 0);
  });
}
