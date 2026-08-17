import 'package:art_kubus/services/ar_camera_orchestrator.dart';
import 'package:art_kubus/services/camera_ownership_coordinator.dart';
import 'package:art_kubus/services/camera_permission_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A camera device only one owner can hold at a time.
///
/// Opening it while another owner still holds it is the hardware contention the
/// ownership sequencing exists to prevent, so here it is a hard failure rather
/// than a warning.
class FakeCameraDevice {
  String? holder;
  final List<String> log = [];

  void open(String owner) {
    if (holder != null) {
      throw StateError('$owner opened the camera while $holder still held it');
    }
    holder = owner;
    log.add('open:$owner');
  }

  Future<void> release(String owner, {Duration delay = Duration.zero}) async {
    log.add('release-start:$owner');
    // Real teardown is not instantaneous; that gap is where the old
    // set-mode-then-release ordering went wrong.
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (holder == owner) holder = null;
    log.add('release-done:$owner');
  }
}

class FakePermissionCoordinator implements CameraPermissionCoordinator {
  FakePermissionCoordinator({this.granted = true});

  bool granted;
  int requests = 0;

  @override
  Future<CameraPermissionState> ensureGranted() async {
    requests++;
    return granted
        ? CameraPermissionState.granted
        : CameraPermissionState.denied;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late FakeCameraDevice device;
  late FakePermissionCoordinator permission;
  late CameraOwnershipCoordinator camera;
  late ArCameraOrchestrator orchestrator;

  /// Wires the coordinator exactly as the AR screen does: the scanner and the
  /// AR session each release the shared device, and mounting is driven by the
  /// resulting surface rather than by the selected mode.
  void build({Duration releaseDelay = const Duration(milliseconds: 5)}) {
    device = FakeCameraDevice();
    permission = FakePermissionCoordinator();
    camera = CameraOwnershipCoordinator(
      releaseScanner: () => device.release('scanner', delay: releaseDelay),
      releaseAr: () => device.release('ar', delay: releaseDelay),
    );
    orchestrator = ArCameraOrchestrator(
      camera: camera,
      permission: permission,
    );
  }

  /// Mounts whatever surface the orchestrator currently permits, the way the
  /// widget tree does when it rebuilds.
  void mountCurrentSurface() {
    switch (orchestrator.surface) {
      case ArCameraSurface.scanner:
        if (device.holder != 'scanner') device.open('scanner');
      case ArCameraSurface.ar:
        if (device.holder != 'ar') device.open('ar');
      case ArCameraSurface.none:
        break;
    }
  }

  setUp(build);

  tearDown(() {
    orchestrator.dispose();
    camera.dispose();
  });

  group('initial ownership', () {
    test('nothing holds the camera before a mode is requested', () {
      expect(orchestrator.owner, CameraOwner.none);
      expect(orchestrator.surface, ArCameraSurface.none);
      expect(orchestrator.currentMode, 'scan');
    });

    test('the initial scanner owner is registered through the coordinator',
        () async {
      // The scanner used to mount straight from the mode while the coordinator
      // still believed nobody held the camera.
      await orchestrator.requestMode('scan');
      mountCurrentSurface();

      expect(orchestrator.owner, CameraOwner.scanner);
      expect(orchestrator.surface, ArCameraSurface.scanner);
      expect(device.holder, 'scanner',
          reason: 'the coordinator and the hardware agree');
      expect(permission.requests, 1);
    });
  });

  group('the outgoing owner releases before the incoming one mounts', () {
    test('Scan -> Place releases the scanner first', () async {
      await orchestrator.requestMode('scan');
      mountCurrentSurface();
      expect(device.holder, 'scanner');

      final transition = orchestrator.requestMode('place');

      // Mid-handoff the widget tree rebuilds and must mount nothing.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(orchestrator.isTransitioning, isTrue);
      expect(orchestrator.surface, ArCameraSurface.none);
      mountCurrentSurface();

      await transition;
      mountCurrentSurface();

      expect(device.holder, 'ar');
      expect(
        device.log,
        containsAllInOrder(['open:scanner', 'release-done:scanner', 'open:ar']),
        reason: 'AR opens the camera strictly after the scanner has let go',
      );
    });

    test('Place -> Scan releases the AR session first', () async {
      await orchestrator.requestMode('place');
      mountCurrentSurface();
      expect(device.holder, 'ar');

      final transition = orchestrator.requestMode('scan');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(orchestrator.surface, ArCameraSurface.none);
      mountCurrentSurface();

      await transition;
      mountCurrentSurface();

      expect(device.holder, 'scanner');
      expect(
        device.log,
        containsAllInOrder(['open:ar', 'release-done:ar', 'open:scanner']),
      );
    });

    test('the rendered mode only advances once the handoff completes',
        () async {
      await orchestrator.requestMode('scan');
      final transition = orchestrator.requestMode('place');

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(orchestrator.requestedMode, 'place');
      expect(
        orchestrator.currentMode,
        'scan',
        reason: 'chrome must not switch while the camera is still moving',
      );

      await transition;
      expect(orchestrator.currentMode, 'place');
    });

    test('rapid toggling stays serialized and never double-opens', () async {
      await orchestrator.requestMode('scan');
      mountCurrentSurface();

      // Ten switches back and forth, all issued without waiting.
      final pending = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        pending.add(orchestrator.requestMode(i.isEven ? 'place' : 'scan'));
        mountCurrentSurface();
      }
      await Future.wait(pending);
      mountCurrentSurface();

      // FakeCameraDevice throws on a double open, so reaching here means no
      // two owners ever held the camera at once.
      expect(orchestrator.currentMode, 'scan');
      expect(device.holder, 'scanner');
    });
  });

  group('Place <-> Spatial share one AR session', () {
    test('switching between AR modes performs no handoff at all', () async {
      await orchestrator.requestMode('place');
      mountCurrentSurface();

      final generationBefore = orchestrator.generation;
      final logBefore = List<String>.from(device.log);

      await orchestrator.requestMode('create');
      mountCurrentSurface();
      await orchestrator.requestMode('place');
      mountCurrentSurface();
      await orchestrator.requestMode('view');
      mountCurrentSurface();

      expect(orchestrator.owner, CameraOwner.ar);
      expect(orchestrator.currentMode, 'view');
      expect(
        orchestrator.generation,
        generationBefore,
        reason: 'no handoff means the same AR session generation throughout',
      );
      expect(
        device.log,
        logBefore,
        reason: 'the AR camera is never released or reopened between AR modes',
      );
      expect(device.holder, 'ar');
    });

    test('the AR surface stays mounted across AR mode changes', () async {
      await orchestrator.requestMode('place');
      expect(orchestrator.surface, ArCameraSurface.ar);

      final transition = orchestrator.requestMode('create');
      // No transitional gap: nothing is torn down, so the AR view is never
      // unmounted and the platform view is not recreated.
      expect(orchestrator.isTransitioning, isFalse);
      expect(orchestrator.surface, ArCameraSurface.ar);
      await transition;
      expect(orchestrator.surface, ArCameraSurface.ar);
    });
  });

  group('permission', () {
    test('a denied request mounts nothing and releases the camera', () async {
      await orchestrator.requestMode('scan');
      mountCurrentSurface();
      expect(device.holder, 'scanner');

      permission.granted = false;
      await orchestrator.requestMode('place');
      mountCurrentSurface();

      expect(orchestrator.permissionDenied, isTrue);
      expect(orchestrator.owner, CameraOwner.none);
      expect(orchestrator.surface, ArCameraSurface.none);
      expect(device.holder, isNull);
    });

    test('recovering permission re-acquires the requested mode', () async {
      permission.granted = false;
      await orchestrator.requestMode('place');
      expect(orchestrator.owner, CameraOwner.none);

      permission.granted = true;
      await orchestrator.reacquire();
      mountCurrentSurface();

      expect(orchestrator.permissionDenied, isFalse);
      expect(orchestrator.owner, CameraOwner.ar);
      expect(device.holder, 'ar');
    });
  });

  group('backgrounding', () {
    test('releasing everything leaves no owner and no mounted surface',
        () async {
      await orchestrator.requestMode('place');
      mountCurrentSurface();

      await orchestrator.releaseAll();
      mountCurrentSurface();

      expect(orchestrator.owner, CameraOwner.none);
      expect(orchestrator.surface, ArCameraSurface.none);
      expect(device.holder, isNull);
      expect(device.log, contains('release-done:ar'));
    });

    test('resuming re-acquires the mode that was active', () async {
      await orchestrator.requestMode('create');
      mountCurrentSurface();
      await orchestrator.releaseAll();

      await orchestrator.reacquire();
      mountCurrentSurface();

      expect(orchestrator.currentMode, 'create');
      expect(orchestrator.owner, CameraOwner.ar);
      expect(device.holder, 'ar');
    });
  });
}
