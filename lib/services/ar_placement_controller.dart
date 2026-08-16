import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

/// Lifecycle of placing one artwork into the user's space.
///
/// Selecting an artwork is not placing it, and creating the AR view is not
/// confirming a placement: every step is an explicit transition the user
/// drives.
enum ArPlacementState {
  /// No artwork chosen.
  none,

  /// An artwork is chosen but the AR session is not tracking yet.
  selected,

  /// Tracking, but no usable surface has been found.
  searchingSurface,

  /// A surface is available and a preview follows the reticle. Nothing is
  /// anchored yet.
  previewing,

  /// Anchored to a hit-tested pose and awaiting confirmation.
  placed,

  /// The user is actively repositioning, rotating, or scaling.
  adjusting,

  /// Committed by the user.
  confirmed,

  /// A recoverable placement error.
  error,
}

/// Position, yaw and scale of a previewed or placed artwork.
@immutable
class ArPlacementTransform {
  const ArPlacementTransform({
    required this.position,
    this.rotationRadians = 0,
    this.scale = 1.0,
  });

  final Vector3 position;

  /// Yaw about the world up axis. Artworks stay upright, so pitch and roll
  /// are not user-adjustable.
  final double rotationRadians;
  final double scale;

  ArPlacementTransform copyWith({
    Vector3? position,
    double? rotationRadians,
    double? scale,
  }) {
    return ArPlacementTransform(
      position: position ?? this.position,
      rotationRadians: rotationRadians ?? this.rotationRadians,
      scale: scale ?? this.scale,
    );
  }
}

/// Drives the Place Artwork workflow.
///
/// Replaces dropping the model at a fixed `Vector3(0, 0, -1.5)` the moment the
/// AR view became ready, which ignored the room entirely and gave the user no
/// say in where the work went.
class ArPlacementController extends ChangeNotifier {
  ArPlacementController({
    this.minScale = 0.2,
    this.maxScale = 5.0,
  });

  final double minScale;
  final double maxScale;

  ArPlacementState _state = ArPlacementState.none;
  String? _artworkId;
  String? _modelPath;
  ArPlacementTransform? _transform;
  String? _errorCode;
  bool _isTracking = false;
  bool _surfaceAvailable = false;

  ArPlacementState get state => _state;
  String? get artworkId => _artworkId;
  String? get modelPath => _modelPath;
  ArPlacementTransform? get transform => _transform;
  String? get errorCode => _errorCode;
  bool get isTracking => _isTracking;
  bool get surfaceAvailable => _surfaceAvailable;

  /// Whether anything is anchored in the scene.
  bool get hasPlacement =>
      _state == ArPlacementState.placed ||
      _state == ArPlacementState.adjusting ||
      _state == ArPlacementState.confirmed;

  /// Whether a tap should be treated as a placement attempt.
  bool get acceptsHitTest =>
      _isTracking &&
      (_state == ArPlacementState.previewing ||
          _state == ArPlacementState.searchingSurface ||
          _state == ArPlacementState.placed ||
          _state == ArPlacementState.adjusting);

  /// Adjustment requires live tracking: moving an anchor the session cannot
  /// currently localize would place it somewhere arbitrary.
  bool get canAdjust => hasPlacement && _isTracking;

  bool get canConfirm =>
      _isTracking &&
      (_state == ArPlacementState.placed ||
          _state == ArPlacementState.adjusting);

  /// True once tracking is lost while something is placed. The anchor is
  /// preserved; only operations needing tracking are disabled.
  bool get isRecoveringTracking => hasPlacement && !_isTracking;

  /// Chooses an artwork. This does not place anything.
  void selectArtwork({required String artworkId, required String modelPath}) {
    _artworkId = artworkId;
    _modelPath = modelPath;
    _transform = null;
    _errorCode = null;
    _state = _isTracking
        ? (_surfaceAvailable
            ? ArPlacementState.previewing
            : ArPlacementState.searchingSurface)
        : ArPlacementState.selected;
    notifyListeners();
  }

  /// Reports AR session tracking. Tracking loss never discards a placement.
  void setTracking(bool isTracking) {
    if (_isTracking == isTracking) return;
    _isTracking = isTracking;
    if (!isTracking) {
      _surfaceAvailable = false;
      // A preview that is not anchored has nothing to preserve.
      if (_state == ArPlacementState.previewing ||
          _state == ArPlacementState.searchingSurface) {
        _state = ArPlacementState.selected;
      }
      notifyListeners();
      return;
    }
    if (_state == ArPlacementState.selected && _artworkId != null) {
      _state = ArPlacementState.searchingSurface;
    }
    notifyListeners();
  }

  /// Reports that ARCore has a usable surface.
  void setSurfaceAvailable(bool available) {
    if (_surfaceAvailable == available) return;
    _surfaceAvailable = available;
    if (available &&
        _isTracking &&
        _state == ArPlacementState.searchingSurface) {
      _state = ArPlacementState.previewing;
    }
    notifyListeners();
  }

  /// Applies a hit-test result from a tap on a tracked surface.
  ///
  /// Returns false when the hit is rejected, so the caller can leave the
  /// existing placement untouched instead of moving it somewhere invalid.
  bool applyHitTest(Vector3? position, {double? rotationRadians}) {
    if (!acceptsHitTest) return false;
    if (position == null) return false;
    if (!position.x.isFinite || !position.y.isFinite || !position.z.isFinite) {
      return false;
    }

    final existing = _transform;
    _transform = existing == null
        ? ArPlacementTransform(
            position: position,
            rotationRadians: rotationRadians ?? 0,
          )
        : existing.copyWith(
            position: position,
            rotationRadians: rotationRadians ?? existing.rotationRadians,
          );
    _state = ArPlacementState.placed;
    _errorCode = null;
    notifyListeners();
    return true;
  }

  /// Begins a direct-manipulation gesture.
  void beginAdjusting() {
    if (!canAdjust) return;
    _state = ArPlacementState.adjusting;
    notifyListeners();
  }

  /// Ends a gesture, returning to the placed state.
  void endAdjusting() {
    if (_state != ArPlacementState.adjusting) return;
    _state = ArPlacementState.placed;
    notifyListeners();
  }

  void rotateBy(double deltaRadians) {
    final current = _transform;
    if (current == null || !canAdjust) return;
    var next = (current.rotationRadians + deltaRadians) % (2 * math.pi);
    if (next < 0) next += 2 * math.pi;
    _transform = current.copyWith(rotationRadians: next);
    notifyListeners();
  }

  void scaleBy(double factor) {
    final current = _transform;
    if (current == null || !canAdjust) return;
    if (!factor.isFinite || factor <= 0) return;
    _transform = current.copyWith(
      scale: (current.scale * factor).clamp(minScale, maxScale),
    );
    notifyListeners();
  }

  /// Moves an existing placement to a new hit-tested pose.
  bool repositionTo(Vector3 position) {
    if (!canAdjust) return false;
    return applyHitTest(position);
  }

  /// Commits the placement.
  void confirm() {
    if (!canConfirm) return;
    _state = ArPlacementState.confirmed;
    notifyListeners();
  }

  /// Discards the placement but keeps the artwork selected, so the user can
  /// immediately try somewhere else.
  void cancelPlacement() {
    if (_artworkId == null) {
      reset();
      return;
    }
    _transform = null;
    _errorCode = null;
    _state = _isTracking
        ? (_surfaceAvailable
            ? ArPlacementState.previewing
            : ArPlacementState.searchingSurface)
        : ArPlacementState.selected;
    notifyListeners();
  }

  /// Reports a recoverable placement failure.
  void reportError(String code) {
    _errorCode = code;
    _state = ArPlacementState.error;
    notifyListeners();
  }

  /// Clears an error and returns to the best available state.
  void clearError() {
    if (_state != ArPlacementState.error) return;
    _errorCode = null;
    if (_artworkId == null) {
      _state = ArPlacementState.none;
    } else if (_transform != null) {
      _state = ArPlacementState.placed;
    } else if (_isTracking) {
      _state = _surfaceAvailable
          ? ArPlacementState.previewing
          : ArPlacementState.searchingSurface;
    } else {
      _state = ArPlacementState.selected;
    }
    notifyListeners();
  }

  /// Clears everything, including the artwork selection.
  void reset() {
    _artworkId = null;
    _modelPath = null;
    _transform = null;
    _errorCode = null;
    _state = ArPlacementState.none;
    notifyListeners();
  }
}
