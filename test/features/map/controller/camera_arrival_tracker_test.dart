import 'dart:async';

import 'package:art_kubus/features/map/controller/camera_arrival_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const target = LatLng(46.0569, 14.5058);
  const wideCentre = LatLng(53.0, 14.0);

  Future<bool> completed(Future<void> future) async {
    var done = false;
    unawaited(future.then((_) => done = true));
    await Future<void>.delayed(Duration.zero);
    return done;
  }

  test('a camera at the target and zoom is "at" it, within three pixels', () {
    expect(
      KubusCameraArrivalTracker.isAt(
        center: target,
        zoom: 17,
        target: target,
        targetZoom: 17,
      ),
      isTrue,
    );
    // One pixel at zoom 17 is about 2.7e-6 degrees of longitude.
    expect(
      KubusCameraArrivalTracker.isAt(
        center: const LatLng(46.0569, 14.505808),
        zoom: 17,
        target: target,
        targetZoom: 17,
      ),
      isTrue,
    );
    expect(
      KubusCameraArrivalTracker.isAt(
        center: const LatLng(46.0569, 14.5059),
        zoom: 17,
        target: target,
        targetZoom: 17,
      ),
      isFalse,
    );
    expect(
      KubusCameraArrivalTracker.isAt(
        center: target,
        zoom: 16.5,
        target: target,
        targetZoom: 17,
      ),
      isFalse,
    );
  });

  test(
      'an idle that precedes the flight does not complete arrival (the cold '
      'link race): only the idle at the target does', () async {
    final tracker = KubusCameraArrivalTracker();
    final arrival = tracker.wait(
      center: wideCentre,
      currentZoom: 4,
      settled: true,
      target: target,
      zoom: 17,
    );

    // The map reports idle for movement before the flight, still at zoom 4.
    tracker.cameraIdle(center: wideCentre, zoom: 4);
    expect(await completed(arrival), isFalse);
    expect(tracker.pendingCount, 1);

    // Mid-flight idle (a frame boundary) is not arrival either.
    tracker.cameraIdle(center: const LatLng(46.5, 14.6), zoom: 10.03);
    expect(await completed(arrival), isFalse);

    tracker.cameraIdle(center: target, zoom: 17);
    expect(await completed(arrival), isTrue);
    expect(tracker.pendingCount, 0);
  });

  test('a camera that is already settled at the target needs no event',
      () async {
    final tracker = KubusCameraArrivalTracker();
    final arrival = tracker.wait(
      center: target,
      currentZoom: 17,
      settled: true,
      target: target,
      zoom: 17,
    );
    expect(await completed(arrival), isTrue);
    expect(tracker.pendingCount, 0);
  });

  test('a camera at the target but still moving waits for idle', () async {
    final tracker = KubusCameraArrivalTracker();
    final arrival = tracker.wait(
      center: target,
      currentZoom: 17,
      settled: false,
      target: target,
      zoom: 17,
    );
    expect(await completed(arrival), isFalse);
    tracker.cameraIdle(center: target, zoom: 17);
    expect(await completed(arrival), isTrue);
  });

  test('a newer waiter supersedes an older one, which completes stale',
      () async {
    final tracker = KubusCameraArrivalTracker();
    final first = tracker.wait(
      center: wideCentre,
      currentZoom: 4,
      settled: true,
      target: target,
      zoom: 17,
    );
    final second = tracker.wait(
      center: wideCentre,
      currentZoom: 4,
      settled: true,
      target: const LatLng(45.8, 15.9),
      zoom: 17,
    );
    expect(await completed(first), isTrue);
    expect(await completed(second), isFalse);
    expect(tracker.pendingCount, 1);
  });

  test('release completes every pending waiter', () async {
    final tracker = KubusCameraArrivalTracker();
    final arrival = tracker.wait(
      center: wideCentre,
      currentZoom: 4,
      settled: true,
      target: target,
      zoom: 17,
    );
    tracker.release();
    expect(await completed(arrival), isTrue);
    expect(tracker.pendingCount, 0);
  });
}
