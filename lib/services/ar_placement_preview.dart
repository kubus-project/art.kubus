import 'package:flutter/foundation.dart';

import 'ar_placement_controller.dart';
import 'spatial_tracking_adapter.dart';
import '../config/config.dart';

/// Keeps one AR scene node in step with the placement the user is composing.
///
/// Placement used to hold a transform in Dart and only add a model when the
/// user confirmed, so "adjust then confirm" asked the user to aim at something
/// invisible. This owns a single preview node, moves/rotates/scales it live as
/// the controller changes, and either commits it or removes it — so the scene
/// never keeps an orphan behind.
class ArPlacementPreview {
  ArPlacementPreview({
    required SpatialTrackingAdapter tracking,
    required Future<String> Function(String raw) resolveModel,
    void Function(Object error)? onError,
  })  : _tracking = tracking,
        _resolveModel = resolveModel,
        _onError = onError;

  final SpatialTrackingAdapter _tracking;
  final Future<String> Function(String raw) _resolveModel;
  final void Function(Object error)? _onError;

  /// Node name currently in the scene, or null when nothing is previewed.
  String? _nodeName;

  /// Artwork the current node was built for, so selecting a different work
  /// replaces the node instead of retargeting the wrong model.
  String? _nodeArtworkId;

  /// Resolved model URI, cached so repositioning does not re-resolve content.
  String? _resolvedModelPath;
  String? _resolvedFromRaw;

  /// Last transform known to be applied to the native hierarchy. This lets
  /// gestures update only their local component; scale/rotation must not even
  /// request a replacement ARCore anchor.
  ArPlacementTransform? _appliedTransform;

  /// Serializes scene mutations. Two overlapping syncs could otherwise add a
  /// second node while the first is still resolving its model.
  Future<void> _queue = Future<void>.value();
  ArPlacementController? _latestPlacement;
  Future<void>? _syncing;

  bool _disposed = false;

  /// The node name a preview for [artworkId] uses.
  static String nodeNameFor(String artworkId) => 'placement-preview-$artworkId';

  @visibleForTesting
  String? get nodeName => _nodeName;

  /// Whether a preview node is currently in the scene.
  bool get hasPreview => _nodeName != null;

  /// Brings the scene in line with [placement].
  ///
  /// Adds the node on the first hit-tested pose, updates it in place for every
  /// later change, and removes it when the placement is cancelled.
  Future<void> sync(ArPlacementController placement) {
    _latestPlacement = placement;
    // Gesture updates can arrive every frame. If native work is still in
    // flight, retain just the newest transform and apply it next; replaying
    // every intermediate scale/yaw creates a visible backlog.
    return _syncing ??= _drainLatestSync();
  }

  Future<void> _drainLatestSync() async {
    try {
      while (!_disposed && _latestPlacement != null) {
        final placement = _latestPlacement!;
        _latestPlacement = null;
        await _sync(placement);
      }
    } finally {
      _syncing = null;
    }
  }

  Future<void> _sync(ArPlacementController placement) async {
    if (_disposed) return;
    final artworkId = placement.artworkId;
    final transform = placement.transform;

    // A confirmed placement is no longer a preview: the node has been handed to
    // the scene by commit(). Rebuilding one here would add a second node under
    // the same name, on top of the placed artwork.
    if (placement.state == ArPlacementState.confirmed) return;

    // Nothing to show: no artwork, or an artwork with no chosen pose yet.
    if (artworkId == null || transform == null) {
      await _removeNode();
      return;
    }

    // A different artwork means a different model; the old node must go first.
    if (_nodeArtworkId != null && _nodeArtworkId != artworkId) {
      await _removeNode();
    }

    if (_nodeName == null) {
      final raw = placement.modelPath ?? '';
      if (raw.trim().isEmpty) return;
      final String modelPath;
      try {
        modelPath = await _resolve(raw);
      } catch (error) {
        _onError?.call(error);
        return;
      }
      if (_disposed) return;
      final name = nodeNameFor(artworkId);
      try {
        await _tracking.addAnchoredModel(
          modelPath: modelPath,
          anchor: transform.anchor,
          localYawRadians: transform.localYawRadians,
          localScale: transform.localScale,
          name: name,
        );
      } catch (error) {
        _onError?.call(error);
        return;
      }
      _nodeName = name;
      _nodeArtworkId = artworkId;
      _appliedTransform = transform;
      return;
    }

    final previous = _appliedTransform;
    try {
      final updated = await _tracking.updateAnchoredNode(
        name: _nodeName!,
        anchor:
            previous == null || !_sameAnchor(previous.anchor, transform.anchor)
                ? transform.anchor
                : null,
        localYawRadians: previous == null ||
                previous.localYawRadians != transform.localYawRadians
            ? transform.localYawRadians
            : null,
        localScale:
            previous == null || previous.localScale != transform.localScale
                ? transform.localScale
                : null,
      );
      if (!updated) {
        // The session dropped the node underneath us (a re-created scene, for
        // instance). Rebuild from the stored anchor pose and local transform;
        // the anchor world position is never reused as a child-local offset.
        _nodeName = null;
        _nodeArtworkId = null;
        _appliedTransform = null;
        await _sync(placement);
      } else {
        _appliedTransform = transform;
      }
    } catch (error) {
      _onError?.call(error);
    }
  }

  /// Promotes the preview to the confirmed placement.
  ///
  /// The preview node already sits at the chosen pose, so it becomes the placed
  /// node rather than being torn down and rebuilt — which would make the
  /// artwork blink at the moment the user commits.
  Future<String?> commit() {
    final completer = _enqueue(() async {
      final name = _nodeName;
      _nodeName = null;
      _nodeArtworkId = null;
      return name;
    });
    return completer;
  }

  /// Removes the preview node, leaving nothing in the scene.
  Future<void> clear() => _enqueue(_removeNode);

  Future<void> _removeNode() async {
    final name = _nodeName;
    _nodeName = null;
    _nodeArtworkId = null;
    _appliedTransform = null;
    if (name == null) return;
    try {
      await _tracking.removeNode(name);
    } catch (error) {
      // A node that is already gone is not a failure worth surfacing.
      if (kDebugMode) {
        AppConfig.debugPrint('ArPlacementPreview: remove failed: $error');
      }
    }
  }

  Future<String> _resolve(String raw) async {
    if (_resolvedFromRaw == raw && _resolvedModelPath != null) {
      return _resolvedModelPath!;
    }
    final resolved = await _resolveModel(raw);
    _resolvedFromRaw = raw;
    _resolvedModelPath = resolved;
    return resolved;
  }

  static bool _sameAnchor(
    ArPlacementAnchorPose first,
    ArPlacementAnchorPose second,
  ) =>
      first.position.x == second.position.x &&
      first.position.y == second.position.y &&
      first.position.z == second.position.z &&
      first.rotation.x == second.rotation.x &&
      first.rotation.y == second.rotation.y &&
      first.rotation.z == second.rotation.z &&
      first.rotation.w == second.rotation.w;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>(
      (_) {},
      onError: (Object _) {},
    );
    return next;
  }

  void dispose() {
    _disposed = true;
    _latestPlacement = null;
    _nodeName = null;
    _nodeArtworkId = null;
  }
}
