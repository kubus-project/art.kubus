import 'package:flutter/material.dart';

import '../../models/spatial_capture_target.dart';

/// What the AR screen should do about spatial capture when it opens.
///
/// Carried as a route argument so the target travels with the navigation that
/// created it. Nothing downstream re-derives the artwork from provider state:
/// the whole point is that the capture belongs to the artwork the user was
/// looking at when they asked for it.
@immutable
class SpatialCaptureLaunchRequest {
  /// Start a new capture for an artwork the user has already chosen.
  const SpatialCaptureLaunchRequest.newCapture({
    required SpatialCaptureTarget this.target,
  })  : localSpatialId = null,
        mustChooseTarget = false;

  /// Reopen an existing record's raw source and add more samples to it.
  const SpatialCaptureLaunchRequest.continueCapture({
    required String this.localSpatialId,
    required SpatialCaptureTarget this.target,
  }) : mustChooseTarget = false;

  /// Open capture mode with no target, so the user picks one first.
  const SpatialCaptureLaunchRequest.chooseTarget()
      : target = null,
        localSpatialId = null,
        mustChooseTarget = true;

  /// The artwork (and optional marker) this capture belongs to.
  final SpatialCaptureTarget? target;

  /// Non-null to extend an existing library record rather than start a new one.
  final String? localSpatialId;

  /// True when the screen should open the artwork picker on arrival.
  final bool mustChooseTarget;

  bool get isContinuation => localSpatialId != null;

  /// Reads a request off a route, returning null when there is none.
  static SpatialCaptureLaunchRequest? maybeOf(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    return arguments is SpatialCaptureLaunchRequest ? arguments : null;
  }
}

/// Opens the AR screen in spatial capture mode for [request].
Future<void> openArSpatialCapture(
  BuildContext context,
  SpatialCaptureLaunchRequest request,
) =>
    Navigator.of(context).pushNamed('/ar', arguments: request);
