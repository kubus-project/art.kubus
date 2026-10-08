import 'package:art_kubus/screens/map_core/marker_visual_sync_coordinator.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MarkerVisualSyncCoordinator coordinator(
    List<int> runs,
    FakeAsync async, {
    Duration syncDuration = Duration.zero,
  }) {
    return MarkerVisualSyncCoordinator(
      throttleMs: 60,
      isReady: () => true,
      nowMs: () => async.elapsed.inMilliseconds,
      sync: () async {
        runs.add(async.elapsed.inMilliseconds);
        if (syncDuration > Duration.zero) {
          await Future<void>.delayed(syncDuration);
        }
      },
    );
  }

  test('a throttled request after the last sync finished still runs', () {
    fakeAsync((async) {
      final runs = <int>[];
      final sync = coordinator(runs, async);
      sync.request();
      async.elapse(const Duration(milliseconds: 20));
      // The first sync is done; this one falls inside the throttle window.
      sync.request();
      async.elapse(const Duration(milliseconds: 200));
      expect(runs, <int>[0, 60],
          reason: 'it must run once the window closes, not wait for an '
              'unrelated later request');
      sync.dispose();
    });
  });

  test('a burst inside one window coalesces into one trailing sync', () {
    fakeAsync((async) {
      final runs = <int>[];
      final sync = coordinator(runs, async);
      sync.request();
      for (var i = 0; i < 5; i += 1) {
        async.elapse(const Duration(milliseconds: 10));
        sync.request();
      }
      async.elapse(const Duration(milliseconds: 300));
      expect(runs, <int>[0, 60]);
      sync.dispose();
    });
  });

  test('a request during an in-flight sync runs right after it', () {
    fakeAsync((async) {
      final runs = <int>[];
      final sync = coordinator(
        runs,
        async,
        syncDuration: const Duration(milliseconds: 100),
      );
      sync.request();
      async.elapse(const Duration(milliseconds: 70));
      sync.request();
      async.elapse(const Duration(milliseconds: 400));
      expect(runs, <int>[0, 100]);
      sync.dispose();
    });
  });

  test('a forced request answers a waiting one without an extra sync', () {
    fakeAsync((async) {
      final runs = <int>[];
      final sync = coordinator(runs, async);
      sync.request();
      async.elapse(const Duration(milliseconds: 10));
      sync.request();
      async.elapse(const Duration(milliseconds: 10));
      sync.request(force: true);
      async.elapse(const Duration(milliseconds: 300));
      expect(runs, <int>[0, 20]);
      sync.dispose();
    });
  });

  test('dispose drops a pending trailing sync', () {
    fakeAsync((async) {
      final runs = <int>[];
      final sync = coordinator(runs, async);
      sync.request();
      async.elapse(const Duration(milliseconds: 10));
      sync.request();
      sync.dispose();
      async.elapse(const Duration(milliseconds: 200));
      expect(runs, <int>[0]);
    });
  });
}
