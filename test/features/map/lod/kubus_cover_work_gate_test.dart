import 'package:art_kubus/features/map/engine/kubus_cover_work_gate.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs jobs one at a time, in order, with spacing between them', () {
    fakeAsync((async) {
      final gate = KubusCoverWorkGate(
        spacing: const Duration(milliseconds: 30),
      );
      final log = <String>[];
      var running = 0;
      var maxRunning = 0;

      Future<void> job(String name) async {
        running += 1;
        maxRunning = running > maxRunning ? running : maxRunning;
        log.add('start $name @${async.elapsed.inMilliseconds}');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        running -= 1;
        log.add('end $name');
      }

      gate.runSerial<void>(() => job('a'));
      gate.runSerial<void>(() => job('b'));
      gate.runSerial<void>(() => job('c'));
      async.elapse(const Duration(seconds: 1));

      expect(maxRunning, 1);
      expect(log, <String>[
        'start a @0',
        'end a',
        // 10 ms of work + 30 ms of spacing before the next job may start.
        'start b @40',
        'end b',
        'start c @80',
        'end c',
      ]);
      gate.dispose();
    });
  });

  test('skips a job whose precondition no longer holds when its turn comes',
      () {
    fakeAsync((async) {
      final gate = KubusCoverWorkGate();
      var cameraMoving = false;
      final ran = <String>[];

      gate.runSerial<bool>(() async {
        ran.add('first');
        // The camera starts moving while the first job is still running.
        cameraMoving = true;
        return true;
      });
      bool? second = true;
      gate.runSerial<bool>(() async {
        ran.add('second');
        return true;
      }, shouldRun: () => !cameraMoving).then((value) => second = value);
      async.elapse(const Duration(seconds: 1));

      expect(ran, <String>['first']);
      expect(second, isNull);
      gate.dispose();
    });
  });

  test('a failing job does not block the queue', () {
    fakeAsync((async) {
      final gate = KubusCoverWorkGate();
      Object? error;
      var laterRan = false;

      gate
          .runSerial<void>(() async => throw StateError('boom'))
          .catchError((Object e) => error = e);
      gate.runSerial<void>(() async => laterRan = true);
      async.elapse(const Duration(seconds: 1));

      expect(error, isA<StateError>());
      expect(laterRan, isTrue);
      gate.dispose();
    });
  });

  test('coalesces a burst of resync requests into one trailing call', () {
    fakeAsync((async) {
      final gate = KubusCoverWorkGate(
        resyncDelay: const Duration(milliseconds: 100),
        resyncMaxWait: const Duration(seconds: 5),
      );
      var calls = 0;

      for (var i = 0; i < 12; i += 1) {
        gate.scheduleResync(() => calls += 1);
        async.elapse(const Duration(milliseconds: 40));
      }
      // Each request restarted the 100 ms timer, so nothing has fired yet.
      expect(calls, 0);
      expect(gate.hasPendingResync, isTrue);

      async.elapse(const Duration(milliseconds: 100));
      expect(calls, 1);
      expect(gate.hasPendingResync, isFalse);
      gate.dispose();
    });
  });

  test('a long burst still flushes every resyncMaxWait', () {
    fakeAsync((async) {
      final gate = KubusCoverWorkGate(
        resyncDelay: const Duration(milliseconds: 100),
        resyncMaxWait: const Duration(milliseconds: 300),
      );
      var calls = 0;

      // Covers keep finishing every 60 ms for 900 ms: a pure trailing debounce
      // would show nothing until the burst ends.
      for (var i = 0; i < 15; i += 1) {
        gate.scheduleResync(() => calls += 1);
        async.elapse(const Duration(milliseconds: 60));
      }
      // Flushes at 300, 600 and 900 ms: one per window, not one per cover.
      expect(calls, 3);
      expect(gate.hasPendingResync, isFalse);
      async.elapse(const Duration(milliseconds: 500));
      expect(calls, 3, reason: 'no stray trailing call after the last flush');
      gate.dispose();
    });
  });

  test('dispose cancels a pending resync and drops queued work', () {
    fakeAsync((async) {
      final gate = KubusCoverWorkGate();
      var resyncs = 0;
      var jobs = 0;

      gate.scheduleResync(() => resyncs += 1);
      gate.runSerial<void>(() async => jobs += 1);
      gate.dispose();
      async.elapse(const Duration(seconds: 1));

      expect(resyncs, 0);
      expect(jobs, 0);
    });
  });
}
