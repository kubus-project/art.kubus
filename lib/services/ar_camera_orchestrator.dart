import 'dart:async';

import 'package:flutter/foundation.dart';

import 'camera_ownership_coordinator.dart';
import 'camera_permission_coordinator.dart';

/// Which camera surface may be mounted right now.
///
/// Distinct from [CameraOwner]: during a handoff nobody may mount anything,
/// even though an owner is still nominally recorded.
enum ArCameraSurface { none, scanner, ar }

/// Owns the AR screen's mode and camera handoff.
///
/// The screen used to set its mode first and only then ask for the camera
/// asynchronously, so the incoming platform view could mount while the outgoing
/// owner was still releasing the device. Here the requested mode and the
/// rendered mode are separate values, and the rendered one only advances once
/// the handoff has completed — which is what makes "the new camera widget never
/// mounts before the old owner has released" a property of the code rather than
/// a hope.
class ArCameraOrchestrator extends ChangeNotifier {
  ArCameraOrchestrator({
    required CameraOwnershipCoordinator camera,
    required CameraPermissionCoordinator permission,
    String initialMode = 'scan',
  })  : _camera = camera,
        _permission = permission,
        _requestedMode = initialMode,
        _currentMode = initialMode {
    _camera.addListener(notifyListeners);
  }

  final CameraOwnershipCoordinator _camera;
  final CameraPermissionCoordinator _permission;

  String _requestedMode;
  String _currentMode;
  bool _permissionDenied = false;

  /// Set once the AR screen is gone.
  ///
  /// A handoff outlives the screen that started it - the user can pop the
  /// route while the outgoing owner is still releasing - and notifying a
  /// disposed [ChangeNotifier] throws. Every async continuation checks this.
  bool _disposed = false;

  /// The mode the user last asked for.
  String get requestedMode => _requestedMode;

  /// The mode whose chrome may be rendered. Lags [requestedMode] for the
  /// duration of a handoff.
  String get currentMode => _currentMode;

  CameraOwner get owner => _camera.owner;
  bool get isTransitioning => _camera.isTransitioning;

  /// Increments on every completed handoff, so a caller can tell whether the
  /// AR session it was using is still the current one.
  int get generation => _camera.generation;

  /// True once a permission request came back denied.
  bool get permissionDenied => _permissionDenied;

  /// Which owner a mode needs.
  ///
  /// Place, Spatial and Archive all run on the AR session, so switching
  /// between them is a no-op handoff and never recreates it.
  static CameraOwner ownerForMode(String modeId) =>
      modeId == 'scan' ? CameraOwner.scanner : CameraOwner.ar;

  /// The surface that may be mounted right now.
  ///
  /// Nothing is mounted mid-handoff: that is the invariant the coordinator
  /// exists to enforce, expressed where the widget tree reads it.
  ArCameraSurface get surface {
    if (_camera.isTransitioning) return ArCameraSurface.none;
    return switch (_camera.owner) {
      CameraOwner.scanner => ArCameraSurface.scanner,
      CameraOwner.ar => ArCameraSurface.ar,
      CameraOwner.none => ArCameraSurface.none,
    };
  }

  /// Requests [modeId], sequencing the camera handoff before the mode follows.
  ///
  /// Safe to call repeatedly: the coordinator queues transitions, so rapid
  /// toggling serializes rather than interleaving two handoffs.
  Future<void> requestMode(String modeId) async {
    if (_disposed) return;
    _requestedMode = modeId;
    _notify();
    await _acquire(modeId);
  }

  /// Re-acquires the camera for the current mode, used on app resume.
  Future<void> reacquire() => _acquire(_requestedMode);

  /// Never throws.
  ///
  /// Callers legitimately fire this without awaiting - a mode button cannot
  /// block on a camera handoff - so a rejection here would surface as an
  /// unhandled error in the root zone rather than as a recoverable AR state.
  Future<void> _acquire(String modeId) async {
    if (_disposed) return;
    final CameraPermissionState permission;
    try {
      permission = await _permission.ensureGranted();
    } catch (error, stack) {
      // An unusable permission check is treated as "not granted": mounting a
      // camera on the strength of a failed check is the worse outcome.
      if (kDebugMode) {
        debugPrint('ArCameraOrchestrator: permission check failed: $error');
        debugPrintStack(stackTrace: stack);
      }
      await _denyAndRelease();
      return;
    }

    if (_disposed) return;
    if (!permission.isGranted) {
      // Never start ARCore or the scanner without permission: the platform
      // would fail opaquely and look like a broken camera.
      await _denyAndRelease();
      return;
    }

    _permissionDenied = false;
    try {
      await _camera.requestOwner(ownerForMode(modeId));
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('ArCameraOrchestrator: handoff to $modeId failed: $error');
        debugPrintStack(stackTrace: stack);
      }
      _notify();
      return;
    }

    // Only a request that is still the latest one may advance the rendered
    // mode; an older queued handoff completing must not drag the UI backwards.
    if (_disposed || _requestedMode != modeId) return;
    _currentMode = modeId;
    _notify();
  }

  /// Records a denied permission and gives the camera back.
  Future<void> _denyAndRelease() async {
    _permissionDenied = true;
    try {
      await _camera.releaseAll();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('ArCameraOrchestrator: release failed: $error');
      }
    }
    _notify();
  }

  /// Notifies only while this orchestrator is still alive.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Releases whatever holds the camera, for backgrounding.
  Future<void> releaseAll() => _camera.releaseAll();

  @override
  void dispose() {
    // The screen's dispose and a queued teardown can both land here.
    if (_disposed) return;
    _disposed = true;
    _camera.removeListener(notifyListeners);
    super.dispose();
  }
}
