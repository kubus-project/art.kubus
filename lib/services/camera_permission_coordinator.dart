import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera permission as the AR feature needs to reason about it.
enum CameraPermissionState {
  /// Not yet checked this run.
  unknown,

  granted,

  /// Refused, but the OS will still show a prompt if asked again.
  denied,

  /// Refused for good. Only the system settings screen can change this, so
  /// asking again silently fails and must not be attempted.
  permanentlyDenied,

  /// Blocked by policy or parental controls; the user cannot grant it.
  restricted;

  bool get isGranted => this == CameraPermissionState.granted;

  /// Whether requesting again can still produce a system prompt.
  bool get canPrompt =>
      this == CameraPermissionState.unknown ||
      this == CameraPermissionState.denied;

  /// Whether the only remaining route is the system settings screen.
  bool get needsSettings => this == CameraPermissionState.permanentlyDenied;
}

/// Single owner of the camera permission request.
///
/// The scanner and the AR session both need the camera. Without one owner they
/// each request independently and the user can be prompted twice for the same
/// permission, or prompted again after a permanent denial where the OS shows
/// nothing at all.
class CameraPermissionCoordinator {
  CameraPermissionCoordinator({
    Future<PermissionStatus> Function()? checkStatus,
    Future<PermissionStatus> Function()? request,
    Future<bool> Function()? openSettings,
  })  : _checkStatus = checkStatus ?? (() => Permission.camera.status),
        _request = request ?? (() => Permission.camera.request()),
        _openSettings = openSettings ?? openAppSettings;

  final Future<PermissionStatus> Function() _checkStatus;
  final Future<PermissionStatus> Function() _request;
  final Future<bool> Function() _openSettings;

  CameraPermissionState _state = CameraPermissionState.unknown;
  Future<CameraPermissionState>? _inFlight;

  CameraPermissionState get state => _state;

  /// Ensures the camera permission is granted, prompting at most once.
  ///
  /// Concurrent callers share a single request, so a mode switch that starts
  /// the scanner and the AR session together cannot produce two prompts.
  Future<CameraPermissionState> ensureGranted() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _ensureGranted();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<CameraPermissionState> _ensureGranted() async {
    _state = _map(await _safe(_checkStatus));
    if (_state.isGranted) return _state;

    // Asking again after a permanent denial shows no prompt at all, so the
    // caller must be routed to settings instead.
    if (!_state.canPrompt) return _state;

    _state = _map(await _safe(_request));
    return _state;
  }

  /// Re-reads the permission without prompting.
  ///
  /// Used when the app returns to the foreground, since the user may have
  /// granted it in system settings while the app was backgrounded.
  Future<CameraPermissionState> refresh() async {
    _state = _map(await _safe(_checkStatus));
    return _state;
  }

  /// Opens the system settings screen. Only meaningful after a permanent
  /// denial.
  Future<bool> openSettings() async {
    try {
      return await _openSettings();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('CameraPermissionCoordinator: openSettings failed: $error');
      }
      return false;
    }
  }

  Future<PermissionStatus> _safe(
    Future<PermissionStatus> Function() action,
  ) async {
    try {
      return await action();
    } catch (error) {
      // A platform failure must not be read as "granted".
      if (kDebugMode) {
        debugPrint('CameraPermissionCoordinator: check failed: $error');
      }
      return PermissionStatus.denied;
    }
  }

  static CameraPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return CameraPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return CameraPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) return CameraPermissionState.restricted;
    return CameraPermissionState.denied;
  }
}
