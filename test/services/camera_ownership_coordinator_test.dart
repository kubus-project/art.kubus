import 'dart:async';

import 'package:art_kubus/services/camera_ownership_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> events;

  CameraOwnershipCoordinator build({
    Future<void> Function()? releaseScanner,
    Future<void> Function()? releaseAr,
  }) {
    return CameraOwnershipCoordinator(
      releaseScanner: releaseScanner ??
          () async {
            events.add('release:scanner');
          },
      releaseAr: releaseAr ??
          () async {
            events.add('release:ar');
          },
      startScanner: () async {
        events.add('start:scanner');
      },
      startAr: () async {
        events.add('start:ar');
      },
    );
  }

  setUp(() => events = <String>[]);

  group('handoff ordering', () {
    test('scan to AR releases the scanner before starting AR', () async {
      final coordinator = build();
      await coordinator.requestOwner(CameraOwner.scanner);
      events.clear();

      await coordinator.requestOwner(CameraOwner.ar);

      expect(events, ['release:scanner', 'start:ar']);
      expect(coordinator.owner, CameraOwner.ar);
    });

    test('AR to scan releases AR before starting the scanner', () async {
      final coordinator = build();
      await coordinator.requestOwner(CameraOwner.ar);
      events.clear();

      await coordinator.requestOwner(CameraOwner.scanner);

      expect(events, ['release:ar', 'start:scanner']);
      expect(coordinator.owner, CameraOwner.scanner);
    });

    test('release is awaited, not fired and forgotten', () async {
      final gate = Completer<void>();
      final coordinator = build(
        releaseScanner: () async {
          events.add('release:start');
          await gate.future;
          events.add('release:done');
        },
      );
      await coordinator.requestOwner(CameraOwner.scanner);
      events.clear();

      final pending = coordinator.requestOwner(CameraOwner.ar);
      await Future<void>.delayed(Duration.zero);

      // AR must not have started while the scanner is still releasing.
      expect(events, ['release:start']);
      gate.complete();
      await pending;

      expect(events, ['release:start', 'release:done', 'start:ar']);
    });
  });

  group('no needless AR teardown', () {
    test('Place to Spatial keeps the same owner and does not restart AR',
        () async {
      final coordinator = build();
      await coordinator.requestOwner(CameraOwner.ar);
      events.clear();

      // Both Place and Spatial are the AR owner.
      await coordinator.requestOwner(CameraOwner.ar);
      await coordinator.requestOwner(CameraOwner.ar);

      expect(events, isEmpty,
          reason: 'the ARCore session must survive a mode switch');
      expect(coordinator.owner, CameraOwner.ar);
    });

    test('the generation only advances on a real handoff', () async {
      final coordinator = build();
      await coordinator.requestOwner(CameraOwner.ar);
      final generation = coordinator.generation;

      await coordinator.requestOwner(CameraOwner.ar);
      expect(coordinator.generation, generation);

      await coordinator.requestOwner(CameraOwner.scanner);
      expect(coordinator.generation, greaterThan(generation));
    });
  });

  group('rapid toggling', () {
    test('transitions are serialized, never interleaved', () async {
      final coordinator = build(
        releaseScanner: () async {
          events.add('release:scanner:start');
          await Future<void>.delayed(const Duration(milliseconds: 5));
          events.add('release:scanner:end');
        },
        releaseAr: () async {
          events.add('release:ar:start');
          await Future<void>.delayed(const Duration(milliseconds: 5));
          events.add('release:ar:end');
        },
      );

      await Future.wait([
        coordinator.requestOwner(CameraOwner.scanner),
        coordinator.requestOwner(CameraOwner.ar),
        coordinator.requestOwner(CameraOwner.scanner),
        coordinator.requestOwner(CameraOwner.ar),
      ]);

      // Every release that starts must finish before the next one begins.
      for (var i = 0; i < events.length; i++) {
        if (!events[i].endsWith(':start')) continue;
        final owner = events[i].split(':')[1];
        expect(events[i + 1], 'release:$owner:end',
            reason: 'handoffs must not interleave');
      }
      expect(coordinator.owner, CameraOwner.ar);
    });

    test('ten scan/AR toggles end with exactly one owner', () async {
      final coordinator = build();

      for (var i = 0; i < 10; i++) {
        await coordinator.requestOwner(CameraOwner.scanner);
        await coordinator.requestOwner(CameraOwner.ar);
      }

      expect(coordinator.owner, CameraOwner.ar);
      expect(coordinator.isTransitioning, isFalse);
      // Balanced: every start had a matching release.
      final starts = events.where((e) => e.startsWith('start:')).length;
      final releases = events.where((e) => e.startsWith('release:')).length;
      expect(starts - releases, 1,
          reason: 'exactly one owner is left holding the camera');
    });
  });

  group('failure handling', () {
    test('a failed release still hands the camera over', () async {
      final coordinator = build(
        releaseScanner: () async => throw StateError('camera stuck'),
      );
      await coordinator.requestOwner(CameraOwner.scanner);
      events.clear();

      await coordinator.requestOwner(CameraOwner.ar);

      expect(coordinator.owner, CameraOwner.ar,
          reason: 'a stuck release must not strand ownership');
      expect(events, ['start:ar']);
    });

    test('releaseAll drops ownership', () async {
      final coordinator = build();
      await coordinator.requestOwner(CameraOwner.ar);

      await coordinator.releaseAll();

      expect(coordinator.owner, CameraOwner.none);
      expect(events.last, 'release:ar');
    });
  });

  test('isTransitioning is true only during a handoff', () async {
    final gate = Completer<void>();
    final coordinator = build(releaseScanner: () => gate.future);
    await coordinator.requestOwner(CameraOwner.scanner);

    expect(coordinator.isTransitioning, isFalse);
    final pending = coordinator.requestOwner(CameraOwner.ar);
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.isTransitioning, isTrue);

    gate.complete();
    await pending;
    expect(coordinator.isTransitioning, isFalse);
  });
}
