import 'dart:async';

import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
      'nearby fixes interpolate and rapid updates retarget the displayed point',
      () {
    fakeAsync((clock) {
      final positions = <LatLng?>[];
      final animator = KubusUserLocationAnimator(
        nowMs: () => clock.elapsed.inMilliseconds,
        write: (position, epoch) async => positions.add(position),
      );
      animator.update(const LatLng(46, 14), styleEpoch: 1, reduceMotion: false);
      clock.flushMicrotasks();
      animator.update(const LatLng(46.0005, 14),
          styleEpoch: 1, reduceMotion: false);
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 132));
      final middle = positions.last!;
      expect(middle.latitude, greaterThan(46));
      expect(middle.latitude, lessThan(46.0005));
      animator.update(const LatLng(46.0002, 14),
          styleEpoch: 1, reduceMotion: false);
      clock.flushMicrotasks();
      expect(positions.last!.latitude, middle.latitude);
      clock.elapse(const Duration(milliseconds: 300));
      expect(positions.last!.latitude, closeTo(46.0002, 0.0000001));
      expect(clock.pendingTimers.length, 0);
      animator.dispose();
    });
  });

  test('reduced motion, style replacement and disposal leave no stale frames',
      () {
    fakeAsync((clock) {
      final positions = <(LatLng?, int)>[];
      final animator = KubusUserLocationAnimator(
          nowMs: () => clock.elapsed.inMilliseconds,
          write: (position, epoch) async => positions.add((position, epoch)));
      animator.update(const LatLng(46, 14), styleEpoch: 1, reduceMotion: false);
      clock.flushMicrotasks();
      animator.update(const LatLng(46.0005, 14),
          styleEpoch: 1, reduceMotion: false);
      clock.flushMicrotasks();
      animator.update(const LatLng(46.0003, 14),
          styleEpoch: 2, reduceMotion: true);
      clock.flushMicrotasks();
      expect(positions.last.$1!.latitude, 46.0003);
      expect(positions.last.$2, 2);
      expect(clock.pendingTimers.length, 0);
      animator.update(const LatLng(46.0004, 14),
          styleEpoch: 2, reduceMotion: false);
      clock.flushMicrotasks();
      animator.dispose();
      final count = positions.length;
      clock.elapse(const Duration(seconds: 1));
      expect(positions.length, count);
    });
  });

  test('slow source writes remain bounded and the latest fix eventually lands',
      () {
    fakeAsync((clock) {
      final gate = Completer<void>();
      var writes = 0;
      LatLng? last;
      final animator = KubusUserLocationAnimator(
          nowMs: () => clock.elapsed.inMilliseconds,
          write: (position, epoch) async {
            writes++;
            last = position;
            if (writes == 1) await gate.future;
          });
      animator.update(const LatLng(46, 14), styleEpoch: 1, reduceMotion: false);
      animator.update(const LatLng(46.0005, 14),
          styleEpoch: 1, reduceMotion: false);
      clock.elapse(const Duration(milliseconds: 500));
      expect(writes, 1);
      gate.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 33));
      expect(last!.latitude, closeTo(46.0005, 0.0000001));
      expect(clock.pendingTimers.length, 0);
      animator.dispose();
    });
  });
}
