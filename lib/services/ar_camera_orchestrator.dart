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
    _requestedMode = modeId;
    notifyListeners();
    await _acquire(modeId);
  }

  /// Re-acquires the camera for the current mode, used on app resume.
  Future<void> reacquire() => _acquire(_requestedMode);

  Future<void> _acquire(String modeId) async {
    final permission = await _permission.ensureGranted();
    if (!permission.isGranted) {
      // Never start ARCore or the scanner without permission: the platform
      // would fail opaquely and look like a broken camera.
      _permissionDenied = true;
      await _camera.releaseAll();
      notifyListeners();
      return;
    }
    _permissionDenied = false;
    await _camera.requestOwner(ownerForMode(modeId));
    // Only a request that is still the latest one may advance the rendered
    // mode; an older queued handoff completing must not drag the UI backwards.
    if (_requestedMode != modeId) return;
    _currentMode = modeId;
    notifyListeners();
  }

  /// Releases whatever holds the camera, for backgrounding.
  Future<void> releaseAll() => _camera.releaseAll();

  @override
  void dispose() {
    _camera.removeListener(notifyListeners);
    super.dispose();
  }
}
