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
    expect(frame.map(longitude), [5, 5]);
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
    expect(reversing.map((f) => f['id']).toSet().length, reversing.length);
    now = 300;
    final settled = [
      feature('a', ['a'], 0),
      feature('b', ['b'], 10)
    ];
    expect(motion.apply(settled, reduceMotion: false), isFalse);
    expect(settled.map((f) => f['id']), ['a', 'b']);
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
