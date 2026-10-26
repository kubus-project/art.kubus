import 'dart:async';

import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/features/map/shared/map_recenter_controller.dart';
import 'package:art_kubus/services/walking_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _here = LatLng(46.0569, 14.5057);
const _elsewhere = LatLng(46.0612, 14.5101);

/// A controller wired to fakes. `acquire` records every call and returns a
/// completer the test resolves, so each request can settle at a chosen moment.
class _Harness {
  DateTime now = DateTime.utc(2026, 10, 26, 12);
  final List<bool> acquireCalls = <bool>[];
  final List<Completer<WalkingLocationAccessResult>> inFlight =
      <Completer<WalkingLocationAccessResult>>[];
  final List<LatLng> moves = <LatLng>[];
  final List<WalkingLocationAccessStatus> unavailable =
      <WalkingLocationAccessStatus>[];
  final List<bool> locating = <bool>[];
  final List<bool> followWrites = <bool>[];
  bool following = true;

  late final MapRecenterController controller = MapRecenterController(
    acquire: ({required bool requestPermission}) {
      acquireCalls.add(requestPermission);
      final completer = Completer<WalkingLocationAccessResult>();
      inFlight.add(completer);
      return completer.future;
    },
    isFollowing: () => following,
    setFollowing: (value) {
      following = value;
      followWrites.add(value);
    },
    moveCamera: moves.add,
    cameraDuration: () => const Duration(milliseconds: 320),
    reportUnavailable: unavailable.add,
    onLocatingChanged: locating.add,
    clock: () => now,
  );

  /// A fix stamped [age] before the fake clock.
  int stampMs(Duration age) => now.subtract(age).millisecondsSinceEpoch;

  Future<MapRecenterSettlement> tapWithKnownFix({
    LatLng position = _here,
    Duration age = const Duration(seconds: 10),
    double accuracyMeters = 8,
  }) =>
      controller.recenterOnUser(
        knownPosition: position,
        knownAccuracyMeters: accuracyMeters,
        knownTimestampMs: stampMs(age),
      );

  Future<MapRecenterSettlement> tapWithoutFix() => controller.recenterOnUser(
        knownPosition: null,
        knownAccuracyMeters: null,
        knownTimestampMs: null,
      );

  WalkingLocationAccessResult liveFix(LatLng position) =>
      WalkingLocationAccessResult(
        WalkingLocationAccessStatus.available,
        fix: WalkingLocationFix(
          position: position,
          accuracyMeters: 8,
          timestamp: now,
        ),
      );
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('known fix policy', () {
    test('a known fix is usable only when fresh, accurate and on the globe',
        () {
      final now = DateTime.utc(2026, 10, 26, 12);
      int stamp(Duration age) => now.subtract(age).millisecondsSinceEpoch;

      final fresh = stamp(const Duration(seconds: 10));
      bool usable({
        LatLng? position = _here,
        double? accuracy = 8,
        int? timestampMs,
        bool noTime = false,
      }) =>
          MapRecenterPolicy.isUsableKnownFix(
            position: position,
            accuracyMeters: accuracy,
            timestampMs: noTime ? null : (timestampMs ?? fresh),
            now: now,
          );

      expect(usable(), isTrue);
      // Desktop Wi-Fi or IP fixes are hundreds to thousands of metres out.
      // The ceiling is 2000 m, inclusive, so these must centre at once.
      expect(usable(accuracy: 100), isTrue);
      expect(usable(accuracy: 500), isTrue);
      expect(usable(accuracy: 1999), isTrue);
      expect(usable(accuracy: 2000), isTrue);
      expect(usable(accuracy: 2000.5), isFalse);
      expect(usable(accuracy: 2001), isFalse);
      for (final invalid in <double?>[
        null,
        0,
        -1,
        double.nan,
        double.infinity
      ]) {
        expect(usable(accuracy: invalid), isFalse, reason: 'accuracy $invalid');
      }

      // The age ceiling is two minutes, inclusive.
      expect(usable(timestampMs: stamp(const Duration(minutes: 2))), isTrue);
      expect(
        usable(
          timestampMs: stamp(const Duration(minutes: 2)) - 1,
        ),
        isFalse,
      );
      expect(usable(noTime: true), isFalse);

      // A fix stamped slightly ahead of the device clock is tolerated.
      expect(
        usable(timestampMs: stamp(const Duration(seconds: -4))),
        isTrue,
      );
      expect(
        usable(timestampMs: stamp(const Duration(seconds: -6))),
        isFalse,
      );

      expect(usable(position: null), isFalse);
      expect(usable(position: const LatLng(91, 14)), isFalse);
      expect(usable(position: const LatLng(46, 181)), isFalse);
      expect(usable(position: const LatLng(double.nan, 14)), isFalse);
    });

    test('a failed live request may fall back to any recent, valid fix', () {
      final now = DateTime.utc(2026, 10, 26, 12);
      int stamp(Duration age) => now.subtract(age).millisecondsSinceEpoch;

      bool fallback({
        double? accuracy = 3000,
        Duration age = const Duration(seconds: 90),
      }) =>
          MapRecenterPolicy.isFallbackKnownFix(
            position: _here,
            accuracyMeters: accuracy,
            timestampMs: stamp(age),
            now: now,
          );

      // The accuracy ceiling does not apply to a fallback...
      expect(fallback(accuracy: 3000), isTrue);
      expect(fallback(accuracy: 1), isTrue);
      // ...but freshness, a finite positive accuracy and validity still do.
      expect(fallback(age: const Duration(minutes: 2)), isTrue);
      expect(fallback(age: const Duration(minutes: 3)), isFalse);
      expect(fallback(accuracy: 0), isFalse);
      expect(fallback(accuracy: double.nan), isFalse);
      expect(fallback(accuracy: double.infinity), isFalse);
      expect(fallback(accuracy: null), isFalse);
    });
  });

  group('deliberate recentering', () {
    test('a recent accurate known fix moves the camera at once, without GPS',
        () async {
      final harness = _Harness();

      final settlement = harness.tapWithKnownFix();

      expect(
        harness.moves,
        <LatLng>[_here],
        reason: 'the transition is issued before any await',
      );
      expect(harness.acquireCalls, <bool>[false],
          reason: 'only the non-prompting background refresh starts');
      expect(await settlement, MapRecenterSettlement.centeredOnKnownFix);
      expect(harness.followWrites, isEmpty,
          reason: 'already following: nothing to switch on');
    });

    test('the background refresh never moves the camera or reports failure',
        () async {
      final harness = _Harness();
      final settlement = harness.tapWithKnownFix();
      expect(await settlement, MapRecenterSettlement.centeredOnKnownFix);

      harness.inFlight.single.complete(
        const WalkingLocationAccessResult(
          WalkingLocationAccessStatus.permissionDenied,
        ),
      );
      await _settle();

      expect(harness.moves, hasLength(1));
      expect(harness.unavailable, isEmpty);
      expect(harness.locating, isEmpty,
          reason: 'a refresh is not an explicit request');
    });

    test('a stale known fix waits for an explicit live fix, then centres once',
        () async {
      final harness = _Harness();

      final settlement = harness.tapWithKnownFix(
        age: const Duration(minutes: 3),
      );

      expect(harness.moves, isEmpty, reason: 'never centre on a stale fix');
      expect(harness.acquireCalls, <bool>[true]);
      expect(harness.locating, <bool>[true]);

      harness.inFlight.single.complete(harness.liveFix(_elsewhere));

      expect(await settlement, MapRecenterSettlement.centeredOnLiveFix);
      expect(harness.moves, <LatLng>[_elsewhere]);
      expect(harness.locating, <bool>[true, false]);
      expect(harness.unavailable, isEmpty);
    });

    test('without any fix, the request prompts only through the explicit call',
        () async {
      final harness = _Harness();

      final settlement = harness.tapWithoutFix();

      expect(harness.acquireCalls, <bool>[true]);
      expect(harness.moves, isEmpty);
      harness.inFlight.single.complete(harness.liveFix(_here));
      expect(await settlement, MapRecenterSettlement.centeredOnLiveFix);
      expect(harness.moves, <LatLng>[_here]);
    });

    test(
        'a tap while already following recenters and never switches follow off',
        () async {
      final harness = _Harness();

      await harness.tapWithKnownFix(position: _here);
      await harness.tapWithKnownFix(position: _elsewhere);

      expect(harness.following, isTrue);
      expect(harness.followWrites, isEmpty);
      expect(harness.moves, <LatLng>[_here, _elsewhere],
          reason: 'the second tap is a real recenter, not a no-op');
    });
  });

  group('desktop accuracy and fallback', () {
    test('a 1500 m desktop fix centres at once instead of waiting for GPS',
        () async {
      final harness = _Harness();

      final settlement = harness.tapWithKnownFix(accuracyMeters: 1500);

      expect(harness.moves, <LatLng>[_here]);
      expect(harness.acquireCalls, <bool>[false],
          reason: 'no prompting live request is started');
      expect(await settlement, MapRecenterSettlement.centeredOnKnownFix);
    });

    for (final status in <WalkingLocationAccessStatus>[
      WalkingLocationAccessStatus.timedOut,
      WalkingLocationAccessStatus.liveLocationUnavailable,
    ]) {
      test('${status.name} centres on a recent known fix instead of failing',
          () async {
        final harness = _Harness();

        // Too inaccurate to centre at once, so the tap waits for a live fix.
        final settlement = harness.tapWithKnownFix(
          age: const Duration(seconds: 90),
          accuracyMeters: 3000,
        );
        expect(harness.moves, isEmpty);
        expect(harness.acquireCalls, <bool>[true]);

        harness.inFlight.single.complete(
          WalkingLocationAccessResult(status),
        );

        expect(await settlement, MapRecenterSettlement.centeredOnKnownFix);
        expect(harness.moves, <LatLng>[_here]);
        expect(harness.unavailable, isEmpty,
            reason: 'a held fix serves the request; no failure is shown');
        expect(harness.following, isTrue);
        expect(harness.followWrites, isEmpty);
      });
    }

    test('a stale known fix does not rescue a timed-out request', () async {
      final harness = _Harness();

      final settlement = harness.tapWithKnownFix(
        age: const Duration(minutes: 3),
      );
      harness.inFlight.single.complete(
        const WalkingLocationAccessResult(WalkingLocationAccessStatus.timedOut),
      );

      expect(await settlement, MapRecenterSettlement.unavailable);
      expect(harness.moves, isEmpty, reason: 'never centre on a stale fix');
      expect(harness.unavailable, <WalkingLocationAccessStatus>[
        WalkingLocationAccessStatus.timedOut,
      ]);
    });

    test('denied permission keeps its feedback even with a held fix', () async {
      final harness = _Harness();

      final settlement = harness.tapWithKnownFix(
        age: const Duration(seconds: 90),
        accuracyMeters: 3000,
      );
      harness.inFlight.single.complete(
        const WalkingLocationAccessResult(
          WalkingLocationAccessStatus.permissionDenied,
        ),
      );

      expect(await settlement, MapRecenterSettlement.unavailable);
      expect(harness.moves, isEmpty,
          reason: 'a silent centre would hide what the user must fix');
      expect(harness.unavailable, <WalkingLocationAccessStatus>[
        WalkingLocationAccessStatus.permissionDenied,
      ]);
    });
  });

  group('failure settlement', () {
    for (final status in <WalkingLocationAccessStatus>[
      WalkingLocationAccessStatus.permissionDenied,
      WalkingLocationAccessStatus.permissionDeniedPermanently,
      WalkingLocationAccessStatus.serviceDisabled,
      WalkingLocationAccessStatus.timedOut,
      WalkingLocationAccessStatus.liveLocationUnavailable,
    ]) {
      test('${status.name} settles with feedback and restores follow',
          () async {
        final harness = _Harness()..following = false;

        final settlement = harness.tapWithoutFix();
        expect(harness.following, isTrue,
            reason: 'the tap engages follow while the request is pending');

        harness.inFlight.single.complete(
          WalkingLocationAccessResult(status),
        );

        expect(await settlement, MapRecenterSettlement.unavailable);
        expect(harness.unavailable, <WalkingLocationAccessStatus>[status]);
        expect(harness.following, isFalse, reason: 'no false following state');
        expect(harness.followWrites, <bool>[true, false]);
        expect(harness.moves, isEmpty);
        expect(harness.locating, <bool>[true, false]);
      });
    }

    test('a failure while already following keeps follow on', () async {
      final harness = _Harness();

      final settlement = harness.tapWithoutFix();
      harness.inFlight.single.complete(
        const WalkingLocationAccessResult(
          WalkingLocationAccessStatus.timedOut,
        ),
      );

      expect(await settlement, MapRecenterSettlement.unavailable);
      expect(harness.following, isTrue);
      expect(harness.followWrites, isEmpty);
    });

    test('an acquisition that throws settles as unavailable, not stuck',
        () async {
      final harness = _Harness();
      final throwing = MapRecenterController(
        acquire: ({required bool requestPermission}) =>
            Future<WalkingLocationAccessResult>.error(StateError('boom')),
        isFollowing: () => true,
        setFollowing: (_) {},
        moveCamera: (_) {},
        cameraDuration: () => Duration.zero,
        reportUnavailable: harness.unavailable.add,
        onLocatingChanged: harness.locating.add,
        clock: () => harness.now,
      );

      final settlement = await throwing.recenterOnUser(
        knownPosition: null,
        knownAccuracyMeters: null,
        knownTimestampMs: null,
      );

      expect(settlement, MapRecenterSettlement.unavailable);
      expect(throwing.isLocating, isFalse);
      expect(harness.unavailable, <WalkingLocationAccessStatus>[
        WalkingLocationAccessStatus.liveLocationUnavailable,
      ]);
    });
  });

  group('request bounds and supersession', () {
    test('repeated taps share one explicit request and one camera transition',
        () async {
      final harness = _Harness();

      final taps = <Future<MapRecenterSettlement>>[
        for (var i = 0; i < 5; i += 1) harness.tapWithoutFix(),
      ];

      expect(
        harness.acquireCalls.where((prompting) => prompting).length,
        1,
        reason: 'five taps start one live request, not five',
      );

      harness.inFlight.single.complete(harness.liveFix(_here));
      final settlements = await Future.wait(taps);

      expect(settlements.last, MapRecenterSettlement.centeredOnLiveFix);
      expect(
        settlements.take(4),
        everyElement(MapRecenterSettlement.superseded),
        reason: 'only the newest intent moves the camera',
      );
      expect(harness.moves, <LatLng>[_here]);
      expect(harness.locating, <bool>[true, false]);
    });

    test('a newer known-fix tap supersedes an older pending request', () async {
      final harness = _Harness();

      final slow = harness.tapWithoutFix();
      final fast = harness.tapWithKnownFix(position: _elsewhere);

      expect(await fast, MapRecenterSettlement.centeredOnKnownFix);
      expect(harness.moves, <LatLng>[_elsewhere]);

      // The first request is the explicit one; the second is the refresh.
      harness.inFlight.first.complete(harness.liveFix(_here));

      expect(await slow, MapRecenterSettlement.superseded);
      expect(harness.moves, <LatLng>[_elsewhere],
          reason: 'a late GPS result cannot override the newer intent');
    });

    test('an explicit tap is retained while a passive request is in flight',
        () async {
      final harness = _Harness();

      // A passive acquisition (startup or a timer) is already in flight. The
      // controller never awaits it, so it is only modelled as a pending call.
      final passive = Completer<WalkingLocationAccessResult>();
      harness.acquireCalls.add(false);
      harness.inFlight.add(passive);

      final settlement = harness.tapWithoutFix();

      expect(harness.acquireCalls, <bool>[false, true],
          reason: 'the explicit tap starts its own live request');
      harness.inFlight.last.complete(harness.liveFix(_elsewhere));
      expect(await settlement, MapRecenterSettlement.centeredOnLiveFix);
      expect(harness.moves, <LatLng>[_elsewhere]);
    });

    test('a passive result cannot override a deliberate request in flight',
        () async {
      final harness = _Harness();

      final settlement = harness.tapWithoutFix();
      expect(harness.controller.allowsPassiveCamera, isFalse,
          reason: 'a pending request blocks passive camera commands');

      harness.inFlight.single.complete(harness.liveFix(_here));
      expect(await settlement, MapRecenterSettlement.centeredOnLiveFix);
    });

    test('manual pan or zoom supersedes a pending request', () async {
      final harness = _Harness();

      final settlement = harness.tapWithoutFix();
      harness.controller.supersede();

      expect(harness.locating, <bool>[true, false],
          reason: 'the feedback is cleared, nothing is left spinning');
      harness.inFlight.single.complete(harness.liveFix(_here));

      expect(await settlement, MapRecenterSettlement.superseded);
      expect(harness.moves, isEmpty);
      expect(harness.unavailable, isEmpty);
    });

    test('a newer navigation supersedes a deliberate move that owns the camera',
        () async {
      final harness = _Harness();
      await harness.tapWithKnownFix();
      expect(harness.controller.allowsPassiveCamera, isFalse);

      harness.controller.supersede();

      expect(harness.controller.allowsPassiveCamera, isTrue);
      expect(harness.moves, <LatLng>[_here]);
    });
  });

  group('camera ownership', () {
    test('passive camera commands yield for the move duration plus grace',
        () async {
      final harness = _Harness();
      await harness.tapWithKnownFix();
      final start = harness.now;

      // A 320 ms transition plus 100 ms grace owns the camera until 420 ms.
      harness.now = start.add(const Duration(milliseconds: 319));
      expect(harness.controller.allowsPassiveCamera, isFalse,
          reason: 'a heading update during the tween must not restart it');
      harness.now = start.add(const Duration(milliseconds: 419));
      expect(harness.controller.allowsPassiveCamera, isFalse);
      harness.now = start.add(const Duration(milliseconds: 420));
      expect(harness.controller.allowsPassiveCamera, isTrue);
    });

    test(
        'a passive camera decision read after a tap yields, even if it was '
        'granted before the tap', () async {
      final harness = _Harness();
      // A passive acquisition started while the camera was still free must
      // re-read this grant when its result is applied, not reuse the old one.
      expect(harness.controller.allowsPassiveCamera, isTrue);
      final settlement = harness.tapWithoutFix();

      expect(harness.acquireCalls, <bool>[true],
          reason: 'the tap starts its own explicit request');
      expect(harness.controller.allowsPassiveCamera, isFalse,
          reason: 'a pending deliberate request owns the camera');

      harness.inFlight.single.complete(harness.liveFix(_here));
      expect(await settlement, MapRecenterSettlement.centeredOnLiveFix);
      expect(harness.moves, <LatLng>[_here]);
      expect(harness.controller.allowsPassiveCamera, isFalse,
          reason: 'the deliberate move still owns the camera after settling');
    });

    test('dispose stops late results from moving the camera or reporting',
        () async {
      final harness = _Harness();

      final settlement = harness.tapWithoutFix();
      harness.controller.dispose();
      harness.inFlight.single.complete(harness.liveFix(_here));

      expect(await settlement, MapRecenterSettlement.superseded);
      expect(harness.moves, isEmpty);
      expect(harness.unavailable, isEmpty);
      expect(harness.locating, <bool>[true],
          reason:
              'disposal clears feedback silently; nothing is reported after');
      expect(harness.controller.allowsPassiveCamera, isFalse);

      expect(
        await harness.tapWithKnownFix(),
        MapRecenterSettlement.superseded,
        reason: 'a disposed controller accepts no new intent',
      );
      expect(harness.moves, isEmpty);
    });
  });
}
