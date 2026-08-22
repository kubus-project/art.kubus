import 'package:art_kubus/services/ar_camera_orchestrator.dart';
import 'package:art_kubus/services/camera_permission_coordinator.dart';
import 'package:art_kubus/services/camera_ownership_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Always-granted permission, so these tests exercise surface lifecycle only.
class _GrantedPermission implements CameraPermissionCoordinator {
  @override
  Future<CameraPermissionState> ensureGranted() async =>
      CameraPermissionState.granted;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Marker standing in for the ARCore platform view.
///
/// A real platform view is disposed by Flutter the moment it leaves the tree,
/// which is precisely the failure being guarded against, so the test asserts
/// on tree membership rather than on the native view.
class _ArSurfaceMarker extends StatefulWidget {
  const _ArSurfaceMarker({required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_ArSurfaceMarker> createState() => _ArSurfaceMarkerState();
}

class _ArSurfaceMarkerState extends State<_ArSurfaceMarker> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

/// Mirrors `_buildCameraSurface`'s AR branch: the archive is painted over a
/// still-mounted AR view rather than replacing it.
class _ArSurfaceHost extends StatelessWidget {
  const _ArSurfaceHost({required this.mode, required this.onArDisposed});

  final String mode;
  final VoidCallback onArDisposed;

  @override
  Widget build(BuildContext context) {
    // Unconditional Stack with the AR view always at index 0: swapping between
    // a bare child and a Stack child moves it in the element tree and Flutter
    // disposes it.
    return Stack(
      fit: StackFit.expand,
      children: [
        _ArSurfaceMarker(onDispose: onArDisposed),
        if (mode == 'view')
          const ColoredBox(
            color: Colors.white,
            child: Center(child: Text('archive')),
          ),
      ],
    );
  }
}

class _PlacementRevisionHost extends StatelessWidget {
  const _PlacementRevisionHost({
    required this.revision,
    required this.onArDisposed,
  });

  final ValueListenable<int> revision;
  final VoidCallback onArDisposed;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _ArSurfaceMarker(onDispose: onArDisposed),
          Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<int>(
              valueListenable: revision,
              builder: (_, value, __) => Text('transform-$value'),
            ),
          ),
        ],
      );
}

Future<void> _pump(WidgetTester tester, String mode, VoidCallback onDisposed) {
  return tester.pumpWidget(
    MaterialApp(home: _ArSurfaceHost(mode: mode, onArDisposed: onDisposed)),
  );
}

void main() {
  group('Archive mode keeps the AR session alive', () {
    testWidgets('entering Archive does not dispose the AR view',
        (tester) async {
      var disposals = 0;
      await _pump(tester, 'place', () => disposals++);

      await _pump(tester, 'view', () => disposals++);
      await tester.pumpAndSettle();

      // The regression: returning the archive alone removed the platform view
      // from the tree, so Flutter disposed the native session while the
      // orchestrator still reported CameraOwner.ar. Returning to Place then
      // rendered a cached widget over a dead session.
      expect(disposals, isZero);
      expect(find.byType(_ArSurfaceMarker), findsOneWidget);
    });

    testWidgets('the archive paints over the camera', (tester) async {
      await _pump(tester, 'view', () {});
      await tester.pumpAndSettle();

      expect(find.text('archive'), findsOneWidget);
      expect(find.byType(_ArSurfaceMarker), findsOneWidget,
          reason: 'mounted underneath, not replaced');
    });

    testWidgets('Place -> Archive -> Place never rebuilds the AR view',
        (tester) async {
      var disposals = 0;
      await _pump(tester, 'place', () => disposals++);
      final first = tester.state(find.byType(_ArSurfaceMarker));

      await _pump(tester, 'view', () => disposals++);
      await _pump(tester, 'place', () => disposals++);
      await tester.pumpAndSettle();

      expect(disposals, isZero);
      expect(
        tester.state(find.byType(_ArSurfaceMarker)),
        same(first),
        reason: 'the same State survives the round trip',
      );
    });
  });

  group('Archive stays on the AR camera owner', () {
    late CameraOwnershipCoordinator camera;
    late ArCameraOrchestrator orchestrator;
    late List<String> released;

    setUp(() {
      released = <String>[];
      camera = CameraOwnershipCoordinator(
        releaseScanner: () async => released.add('scanner'),
        releaseAr: () async => released.add('ar'),
      );
      orchestrator = ArCameraOrchestrator(
        camera: camera,
        permission: _GrantedPermission(),
      );
    });

    tearDown(() {
      orchestrator.dispose();
      camera.dispose();
    });

    test('Place -> Archive -> Place never releases the AR camera', () async {
      await orchestrator.requestMode('place');
      released.clear();

      await orchestrator.requestMode('view');
      await orchestrator.requestMode('place');

      expect(released, isEmpty,
          reason: 'Archive is a viewer on the AR owner, not a handoff');
      expect(orchestrator.owner, CameraOwner.ar);
      expect(orchestrator.surface, ArCameraSurface.ar);
    });
  });

  testWidgets(
      'placement transform revisions never remount the AR platform view',
      (tester) async {
    final revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    var disposals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _PlacementRevisionHost(
          revision: revision,
          onArDisposed: () => disposals++,
        ),
      ),
    );
    final initialState = tester.state(find.byType(_ArSurfaceMarker));

    for (var value = 1; value <= 20; value++) {
      revision.value = value;
      await tester.pump();
    }

    expect(find.text('transform-20'), findsOneWidget);
    expect(disposals, isZero);
    expect(tester.state(find.byType(_ArSurfaceMarker)), same(initialState));
  });
}
