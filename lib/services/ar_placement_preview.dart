import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

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

  /// Serializes scene mutations. Two overlapping syncs could otherwise add a
  /// second node while the first is still resolving its model.
  Future<void> _queue = Future<void>.value();

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
    return _enqueue(() => _sync(placement));
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
        await _tracking.addModel(
          modelPath: modelPath,
          position: transform.position,
          scale: vector.Vector3.all(transform.scale),
          yawRadians: transform.rotationRadians,
          name: name,
        );
      } catch (error) {
        _onError?.call(error);
        return;
      }
      _nodeName = name;
      _nodeArtworkId = artworkId;
      return;
    }

    try {
      final updated = await _tracking.updateNodeTransform(
        name: _nodeName!,
        position: transform.position,
        yawRadians: transform.rotationRadians,
        scale: transform.scale,
      );
      if (!updated) {
        // The session dropped the node underneath us (a re-created scene, for
        // instance). Forget it so the next sync rebuilds it.
        _nodeName = null;
        _nodeArtworkId = null;
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
    _nodeName = null;
    _nodeArtworkId = null;
  }
}
