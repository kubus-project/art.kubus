import 'package:art_kubus/features/map/shared/map_marker_entrance_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewport exit and re-entry of a known marker is not a true entrance',
      () {
    final tracker = KubusMarkerEntranceTracker();
    tracker.observeIncoming(
      const <String>['known'],
      viewportInitialized: false,
    );

    final entrances = tracker.consumeTrueEntrances(
      enteredIds: <String>{'known'},
      eligibleIds: <String>{'known'},
    );

    expect(entrances, isEmpty);
  });

  test('a new identity entering an initialized viewport animates once', () {
    final tracker = KubusMarkerEntranceTracker();
    tracker.observeIncoming(
      const <String>['known'],
      viewportInitialized: false,
    );
    tracker.observeIncoming(
      const <String>['known', 'new'],
      viewportInitialized: true,
    );

    expect(
      tracker.consumeTrueEntrances(
        enteredIds: <String>{'new'},
        eligibleIds: <String>{'known', 'new'},
      ),
      <String>{'new'},
    );
    expect(
      tracker.consumeTrueEntrances(
        enteredIds: <String>{'new'},
        eligibleIds: <String>{'known', 'new'},
      ),
      isEmpty,
    );
  });

  test('a new offscreen marker remains pending until it becomes eligible', () {
    final tracker = KubusMarkerEntranceTracker();
    tracker.observeIncoming(const <String>[], viewportInitialized: false);
    tracker.observeIncoming(
      const <String>['later'],
      viewportInitialized: true,
    );

    expect(
      tracker.consumeTrueEntrances(
        enteredIds: <String>{},
        eligibleIds: <String>{},
      ),
      isEmpty,
    );
    expect(
      tracker.consumeTrueEntrances(
        enteredIds: <String>{'later'},
        eligibleIds: <String>{'later'},
      ),
      <String>{'later'},
    );
  });
}
