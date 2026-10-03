import 'package:art_kubus/features/map/telemetry/map_engagement_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> emitted;
  late MapEngagementTracker tracker;

  setUp(() {
    emitted = <String>[];
    tracker = MapEngagementTracker(onEngaged: emitted.add);
  });

  group('explicit interactions', () {
    test('opening a marker engages once', () {
      tracker.markerOpened();
      tracker.markerOpened();

      expect(emitted, <String>['marker_open']);
      expect(tracker.engaged, isTrue);
    });

    test('choosing a search result engages once', () {
      tracker.searchResultSelected();

      expect(emitted, <String>['search_select']);
    });

    test('the first interaction wins; later kinds are ignored', () {
      tracker.searchResultSelected();
      tracker.markerOpened();
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12);
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 16);

      expect(emitted, <String>['search_select']);
    });
  });

  group('camera gestures', () {
    test('the first user frame only sets a baseline', () {
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12);

      expect(emitted, isEmpty);
      expect(tracker.engaged, isFalse);
    });

    test('a nudge or a tiny zoom is not engagement', () {
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12);
      tracker.cameraGesture(latitude: 46.0502, longitude: 14.5003, zoom: 12.1);
      tracker.cameraGesture(latitude: 46.0504, longitude: 14.5005, zoom: 12.2);

      expect(emitted, isEmpty);
    });

    test('a deliberate zoom engages', () {
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12);
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12.6);

      expect(emitted, <String>['camera_gesture']);
    });

    test('a deliberate pan engages, scaled to how far in the visitor is', () {
      // At zoom 12 a tile spans ~0.088 degrees; a quarter of that is ~0.022.
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12);
      tracker.cameraGesture(latitude: 46.05, longitude: 14.515, zoom: 12);
      expect(emitted, isEmpty);

      tracker.cameraGesture(latitude: 46.05, longitude: 14.53, zoom: 12);
      expect(emitted, <String>['camera_gesture']);
    });

    test('the same pan distance is not enough when zoomed out', () {
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 4);
      tracker.cameraGesture(latitude: 46.05, longitude: 14.53, zoom: 4);

      expect(emitted, isEmpty);
    });

    test('longitude distance wraps across the antimeridian', () {
      tracker.cameraGesture(latitude: 0, longitude: 179.99, zoom: 10);
      tracker.cameraGesture(latitude: 0, longitude: -179.99, zoom: 10);

      expect(emitted, isEmpty);
    });

    test('a programmatic reposition resets the measuring baseline', () {
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12);
      // The app repositions the camera (fitBounds / restore) far away.
      tracker.resetBaseline();
      tracker.cameraGesture(latitude: 45.0, longitude: 13.0, zoom: 12);

      expect(emitted, isEmpty,
          reason: 'a camera the app moved must not read as the visitor moving');
    });

    test('non-finite frames are ignored', () {
      tracker.cameraGesture(latitude: double.nan, longitude: 0, zoom: 10);
      tracker.cameraGesture(latitude: 0, longitude: double.infinity, zoom: 10);

      expect(emitted, isEmpty);
    });

    test('after engaging, further frames cost nothing and emit nothing', () {
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 12);
      tracker.cameraGesture(latitude: 46.05, longitude: 14.5, zoom: 13);
      for (var i = 0; i < 100; i++) {
        tracker.cameraGesture(
          latitude: 46.05 + i * 0.01,
          longitude: 14.5,
          zoom: 12 + i * 0.1,
        );
      }

      expect(emitted, <String>['camera_gesture']);
    });
  });
}
