import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:art_kubus/services/spatial_capture_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frames that all look at the same thing from the same place.
///
/// Volume without diversity: exactly the shape of capture that the old
/// `frameCount >= 8` gate declared finishable.
Map<String, dynamic> stationaryFrame(int index) => <String, dynamic>{
      'rgb': Uint8List.fromList(List<int>.filled(3, 1)),
      'timestampNanos': index,
      // A hair of movement each frame, enough to pass the duplicate-pose gate
      // but nowhere near enough to see the subject from another side.
      'poseTranslation': [index * 0.06, 0.0, 0.0],
      'poseRotation': const [0.0, 0.0, 0.0, 1.0],
      'intrinsics': {'width': 640, 'height': 480},
      'depthAvailable': false,
    };

/// Frames spread evenly around the subject.
Map<String, dynamic> orbitFrame(int index) {
  final angle = (index / 12) * 2 * math.pi;
  return <String, dynamic>{
    'rgb': Uint8List.fromList(List<int>.filled(3, 1)),
    'timestampNanos': index,
    'poseTranslation': [math.cos(angle), 0.0, math.sin(angle)],
    'poseRotation': [0.0, math.sin(angle / 2), 0.0, math.cos(angle / 2)],
    'intrinsics': {'width': 640, 'height': 480},
    'depthAvailable': false,
  };
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_finish_gate_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  SpatialCaptureProvider buildProvider() => SpatialCaptureProvider(
        storageRoot: root,
        policy: const SpatialCapturePolicy(minSampleInterval: Duration.zero),
      );

  group('finish eligibility', () {
    test(
      'many frames from one viewpoint never become finishable',
      () async {
        final provider = buildProvider();
        await provider.begin(artworkId: 'art-1', capturedBy: 'wallet-1');

        for (var i = 0; i < 40; i++) {
          await provider.offerFrame(stationaryFrame(i), isTracking: true);
        }

        // Well past the old eight-frame threshold, and past the sample-count
        // bar too — but from a single side of the subject.
        expect(provider.frameCount, greaterThanOrEqualTo(8));
        expect(
          provider.viewpointCount,
          lessThan(provider.policy.minViewpointsForFinish),
          reason: 'a stationary sweep sees only a few viewing directions',
        );
        expect(
          provider.canFinish,
          isFalse,
          reason: 'coverage, not frame count, decides finish eligibility',
        );
      },
    );

    test('viewpoint diversity plus volume makes a capture finishable',
        () async {
      final provider = buildProvider();
      await provider.begin(artworkId: 'art-1', capturedBy: 'wallet-1');

      for (var i = 0; i < 30; i++) {
        await provider.offerFrame(orbitFrame(i), isTracking: true);
      }

      expect(provider.viewpointCount,
          greaterThanOrEqualTo(provider.policy.minViewpointsForFinish));
      expect(provider.canFinish, isTrue);
    });
  });

  group('sampler survives an ineligible capture', () {
    test(
      'the sampler keeps running while coverage is still insufficient',
      () async {
        final provider = buildProvider();
        await provider.begin(artworkId: 'art-1', capturedBy: 'wallet-1');

        var index = 0;
        final session = SpatialCaptureSession(
          provider: provider,
          isTracking: () => true,
          captureFrame: () async => stationaryFrame(index++),
          // Never fires a real timer: ticks are driven explicitly below.
          timerFactory: (_, __) => Timer(const Duration(days: 1), () {}),
        );
        addTearDown(session.dispose);

        session.start();
        for (var i = 0; i < 20; i++) {
          await session.tick();
        }

        expect(provider.frameCount, greaterThanOrEqualTo(8));
        expect(provider.canFinish, isFalse);
        expect(
          provider.state,
          SpatialCaptureState.capturing,
          reason: 'an ineligible capture is still a live capture',
        );
        expect(
          session.isSampling,
          isTrue,
          reason: 'nothing stopped the sampler, so more angles can be added',
        );
      },
    );

    test(
      'a premature finish leaves the capture active and resumable',
      () async {
        final provider = buildProvider();
        await provider.begin(artworkId: 'art-1', capturedBy: 'wallet-1');

        for (var i = 0; i < 10; i++) {
          await provider.offerFrame(stationaryFrame(i), isTracking: true);
        }
        expect(provider.canFinish, isFalse);

        // The provider refuses, and says so with a typed exception rather than
        // a raw StateError carrying an English sentence.
        await expectLater(
          provider.finish(_UnusedNodeProvider()),
          throwsA(isA<SpatialCaptureNotReadyException>()),
        );

        expect(
          provider.state,
          SpatialCaptureState.capturing,
          reason:
              'a rejected finish must not move the capture out of capturing',
        );

        // And the capture can still make progress toward being finishable.
        for (var i = 0; i < 30; i++) {
          await provider.offerFrame(orbitFrame(i), isTracking: true);
        }
        expect(provider.canFinish, isTrue);
      },
    );
  });
}

/// `finish()` rejects before it ever touches the node.
///
/// Every member throws, so the test fails loudly if a future change starts
/// contacting the node before checking whether the capture is finishable.
class _UnusedNodeProvider implements KubusNodeProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the node must not be reached for an unready capture');
}
