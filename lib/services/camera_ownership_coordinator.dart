import 'dart:async';

import 'package:flutter/foundation.dart';

/// Who currently holds the camera.
///
/// The scanner (CameraX via the QR plugin) and ARCore cannot both hold it.
/// Relying on widget disposal to release one before the other starts is a
/// race: the new owner can open the camera before the old owner's teardown
/// has actually completed.
enum CameraOwner {
  none,

  /// QR / marker scanner.
  scanner,

  /// ARCore or ARKit session.
  ar,
}

/// Serializes camera handoff between the scanner and the AR session.
///
/// Every transition releases the outgoing owner and waits for that release to
/// complete before the incoming owner starts. Transitions are queued, so
/// rapid mode toggling cannot interleave two handoffs.
class CameraOwnershipCoordinator extends ChangeNotifier {
  CameraOwnershipCoordinator({
    Future<void> Function()? releaseScanner,
    Future<void> Function()? releaseAr,
    Future<void> Function()? startScanner,
    Future<void> Function()? startAr,
  })  : _releaseScanner = releaseScanner,
        _releaseAr = releaseAr,
        _startScanner = startScanner,
        _startAr = startAr;

  Future<void> Function()? _releaseScanner;
  Future<void> Function()? _releaseAr;
  Future<void> Function()? _startScanner;
  Future<void> Function()? _startAr;

  CameraOwner _owner = CameraOwner.none;
  Future<void> _queue = Future<void>.value();
  bool _inTransition = false;
  int _generation = 0;

  CameraOwner get owner => _owner;

  /// True while a handoff is running. Callers must not treat the camera as
  /// usable during a transition.
  bool get isTransitioning => _inTransition;

  /// Increments on every completed handoff, so a late callback from a previous
  /// owner can be recognized and ignored.
  int get generation => _generation;

  @visibleForTesting
  void configure({
    Future<void> Function()? releaseScanner,
    Future<void> Function()? releaseAr,
    Future<void> Function()? startScanner,
    Future<void> Function()? startAr,
  }) {
    _releaseScanner = releaseScanner ?? _releaseScanner;
    _releaseAr = releaseAr ?? _releaseAr;
    _startScanner = startScanner ?? _startScanner;
    _startAr = startAr ?? _startAr;
  }

  /// Hands the camera to [next].
  ///
  /// A request for the current owner is a no-op, which is what keeps switching
  /// between Place and Spatial from tearing down and rebuilding the ARCore
  /// session: both are the same owner.
  Future<void> requestOwner(CameraOwner next) {
    _queue = _queue.then((_) => _transition(next));
    return _queue;
  }

  Future<void> _transition(CameraOwner next) async {
    if (_owner == next) return;

    _inTransition = true;
    notifyListeners();
    try {
      // Release first, and wait for it. The incoming owner must never open the
      // camera while the outgoing one still holds it.
      await _release(_owner);
      _owner = CameraOwner.none;
      _generation++;

      await _start(next);
      _owner = next;
    } finally {
      _inTransition = false;
      notifyListeners();
    }
  }

  Future<void> _release(CameraOwner owner) async {
    final release = switch (owner) {
      CameraOwner.scanner => _releaseScanner,
      CameraOwner.ar => _releaseAr,
      CameraOwner.none => null,
    };
    if (release == null) return;
    try {
      await release();
    } catch (error) {
      // A failed release must not strand ownership: the outgoing owner is
      // dropped regardless so the camera can be reclaimed.
      if (kDebugMode) {
        debugPrint('CameraOwnershipCoordinator: release failed: $error');
      }
    }
  }

  Future<void> _start(CameraOwner owner) async {
    final start = switch (owner) {
      CameraOwner.scanner => _startScanner,
      CameraOwner.ar => _startAr,
      CameraOwner.none => null,
    };
    if (start == null) return;
    await start();
  }

  /// Releases whatever holds the camera and returns to [CameraOwner.none].
  Future<void> releaseAll() => requestOwner(CameraOwner.none);
}
