import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../services/walking_location_service.dart';
import '../navigation/walking_navigation_models.dart';

/// Freshness and accuracy rules for centring the map on the user.
///
/// Centring is not navigation. Desktop browsers without GPS (Wi-Fi or IP
/// positioning) routinely report accuracy in the hundreds to thousands of
/// metres, and the map already draws that accuracy circle. So a recent known
/// fix is accepted up to [maxKnownFixAccuracyMeters]; follow mode re-centres
/// once a better fix arrives. Walking navigation keeps its own live-fix
/// contract in `GeolocatorWalkingLocationService` and never reads these rules.
abstract final class MapRecenterPolicy {
  /// Oldest known fix that may centre the map without waiting for GPS, and the
  /// oldest one a failed live request may fall back to.
  static const Duration maxKnownFixAge = Duration(minutes: 2);

  /// Worst accuracy radius, in metres, a known fix may have to centre the map
  /// at once, without waiting for a live fix. Accuracy must also be finite and
  /// positive, the same rule that gates the accuracy field on the map.
  static const double maxKnownFixAccuracyMeters = 2000;

  /// Tolerance for a fix stamped slightly ahead of the device clock.
  static const Duration maxClockSkew = Duration(seconds: 5);

  /// Time after a deliberate camera move's nominal duration during which
  /// passive camera commands (heading, live fixes, startup) still yield to it.
  static const Duration cameraOwnershipGrace = Duration(milliseconds: 100);

  /// Whether a known fix may centre the map at once: recent, valid, and within
  /// [maxKnownFixAccuracyMeters].
  static bool isUsableKnownFix({
    required LatLng? position,
    required double? accuracyMeters,
    required int? timestampMs,
    required DateTime now,
  }) {
    if (accuracyMeters == null ||
        !accuracyMeters.isFinite ||
        accuracyMeters > maxKnownFixAccuracyMeters) {
      return false;
    }
    return _isRecentValidFix(
      position: position,
      accuracyMeters: accuracyMeters,
      timestampMs: timestampMs,
      now: now,
    );
  }

  /// Whether a known fix may centre the map after a failed live request
  /// (timeout or unavailable). Recent and valid with any finite positive
  /// accuracy: the explicit tap asked for the user's position and this is the
  /// best one held, so the accuracy ceiling does not apply.
  static bool isFallbackKnownFix({
    required LatLng? position,
    required double? accuracyMeters,
    required int? timestampMs,
    required DateTime now,
  }) {
    return _isRecentValidFix(
      position: position,
      accuracyMeters: accuracyMeters,
      timestampMs: timestampMs,
      now: now,
    );
  }

  static bool _isRecentValidFix({
    required LatLng? position,
    required double? accuracyMeters,
    required int? timestampMs,
    required DateTime now,
  }) {
    if (position == null || accuracyMeters == null || timestampMs == null) {
      return false;
    }
    final latitude = position.latitude;
    final longitude = position.longitude;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude.abs() > 90 || longitude.abs() > 180) return false;
    if (!accuracyMeters.isFinite || accuracyMeters <= 0) return false;
    final ageMs = now.millisecondsSinceEpoch - timestampMs;
    if (ageMs < -maxClockSkew.inMilliseconds) return false;
    return ageMs <= maxKnownFixAge.inMilliseconds;
  }
}

/// Acquires a live fix. `requestPermission` is true only for an explicit user
/// action; a passive call must never prompt.
typedef MapRecenterAcquire = Future<WalkingLocationAccessResult> Function({
  required bool requestPermission,
});

/// How one deliberate recentering request ended.
enum MapRecenterSettlement {
  /// A recent, accurate known fix centred the map at once.
  centeredOnKnownFix,

  /// A live fix arrived for the newest request and centred the map.
  centeredOnLiveFix,

  /// A newer request, a manual pan or zoom, or navigation took over first.
  superseded,

  /// No usable fix; feedback was reported and follow was restored if needed.
  unavailable,
}

/// Owns the deliberate "center on me" intent of one map screen.
///
/// Every tap is a new intent with a revision. A newer intent or any navigation
/// (a manual pan or zoom, a search result, a map link) supersedes older ones,
/// and only the newest pending request moves the camera. Explicit acquisition
/// is shared, so repeated taps never start more than one live request at a
/// time. A passive acquisition (startup or a timer) is never awaited here, so
/// an explicit tap is never dropped because one is in flight.
///
/// A recent accurate known fix moves the camera at once; a live refresh then
/// runs without prompting and without moving the camera. Without a usable fix
/// the request waits for an explicit live fix, then centres once.
///
/// Passive camera commands ask [allowsPassiveCamera] first. They yield while a
/// request is pending and during the ownership window of a deliberate move, so
/// a heading or location update never restarts or cancels that tween.
class MapRecenterController {
  MapRecenterController({
    required this.acquire,
    required this.isFollowing,
    required this.setFollowing,
    required this.moveCamera,
    required this.cameraDuration,
    required this.reportUnavailable,
    required this.onLocatingChanged,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Acquires a fix and applies it to the screen's location state. It must not
  /// move the camera; the controller decides that.
  final MapRecenterAcquire acquire;

  final bool Function() isFollowing;
  final void Function(bool value) setFollowing;

  /// Issues one camera transition to [target].
  final void Function(LatLng target) moveCamera;

  /// Nominal duration of a camera transition, used for the ownership window.
  final Duration Function() cameraDuration;

  /// Reports a failed explicit request so the screen can show feedback.
  final void Function(WalkingLocationAccessStatus status) reportUnavailable;

  /// Reports when an explicit live request is pending for the newest intent.
  final void Function(bool locating) onLocatingChanged;

  final DateTime Function() _clock;

  int _revision = 0;
  int? _pendingRevision;
  bool _followBeforeRequest = false;
  Future<WalkingLocationAccessResult>? _explicitAcquisition;
  DateTime? _cameraOwnedUntil;
  bool _locating = false;
  bool _disposed = false;

  /// Increases on every deliberate request and every [supersede].
  int get revision => _revision;

  /// Whether a deliberate request is still waiting to move the camera.
  bool get hasPendingRequest => _pendingRevision != null;

  bool get isLocating => _locating;

  /// Whether a passive camera command may move the camera right now.
  bool get allowsPassiveCamera {
    if (_disposed || _pendingRevision != null) return false;
    final until = _cameraOwnedUntil;
    return until == null || !_clock().isBefore(until);
  }

  /// Handles one "center on me" tap.
  ///
  /// The synchronous part runs before the first await, so a usable known fix
  /// issues its camera transition in the same event as the tap.
  Future<MapRecenterSettlement> recenterOnUser({
    required LatLng? knownPosition,
    required double? knownAccuracyMeters,
    required int? knownTimestampMs,
  }) async {
    if (_disposed) return MapRecenterSettlement.superseded;
    final now = _clock();

    if (_pendingRevision == null) _followBeforeRequest = isFollowing();
    _revision += 1;
    final ticket = _revision;
    _pendingRevision = ticket;

    // A tap engages follow. Following is never switched off by centering.
    if (!isFollowing()) setFollowing(true);

    if (MapRecenterPolicy.isUsableKnownFix(
      position: knownPosition,
      accuracyMeters: knownAccuracyMeters,
      timestampMs: knownTimestampMs,
      now: now,
    )) {
      _pendingRevision = null;
      _notifyLocating();
      _centerNow(knownPosition!);
      // The refresh only corrects the displayed fix. It neither moves the
      // camera nor reports failure, because the known fix already served.
      unawaited(_refreshInBackground());
      return MapRecenterSettlement.centeredOnKnownFix;
    }

    final acquisition = _explicitAcquisition ??= _runExplicitAcquisition();
    _notifyLocating();
    final result = await acquisition;

    if (_disposed || _pendingRevision != ticket) {
      return MapRecenterSettlement.superseded;
    }
    _pendingRevision = null;
    _notifyLocating();

    final fix = result.fix;
    if (result.isAvailable && fix != null) {
      _centerNow(fix.position);
      return MapRecenterSettlement.centeredOnLiveFix;
    }
    // A timed-out or unavailable live request still centres on a held fix that
    // is recent enough. Denied, blocked and disabled-service outcomes keep their
    // feedback: the user has to act on those, and a silent centre would hide them.
    final fallbackAllowed = result.status ==
            WalkingLocationAccessStatus.timedOut ||
        result.status == WalkingLocationAccessStatus.liveLocationUnavailable;
    if (fallbackAllowed &&
        MapRecenterPolicy.isFallbackKnownFix(
          position: knownPosition,
          accuracyMeters: knownAccuracyMeters,
          timestampMs: knownTimestampMs,
          now: _clock(),
        )) {
      _centerNow(knownPosition!);
      return MapRecenterSettlement.centeredOnKnownFix;
    }
    if (!_followBeforeRequest) setFollowing(false);
    reportUnavailable(result.status);
    return MapRecenterSettlement.unavailable;
  }

  /// A manual pan or zoom, a newer navigation, or a marker selection: the
  /// pending request is dropped and an owned camera move is released.
  void supersede() {
    if (_disposed) return;
    _revision += 1;
    _pendingRevision = null;
    _cameraOwnedUntil = null;
    _notifyLocating();
  }

  void dispose() {
    _disposed = true;
    _pendingRevision = null;
    _cameraOwnedUntil = null;
    _locating = false;
  }

  void _centerNow(LatLng target) {
    _cameraOwnedUntil =
        _clock().add(cameraDuration() + MapRecenterPolicy.cameraOwnershipGrace);
    moveCamera(target);
  }

  Future<WalkingLocationAccessResult> _runExplicitAcquisition() async {
    try {
      return await acquire(requestPermission: true);
    } catch (_) {
      return const WalkingLocationAccessResult(
        WalkingLocationAccessStatus.liveLocationUnavailable,
      );
    } finally {
      _explicitAcquisition = null;
      _notifyLocating();
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      await acquire(requestPermission: false);
    } catch (_) {
      // Passive refresh failures are silent; the known fix already served.
    }
  }

  void _notifyLocating() {
    final next =
        !_disposed && _explicitAcquisition != null && _pendingRevision != null;
    if (next == _locating) return;
    _locating = next;
    onLocatingChanged(next);
  }
}
