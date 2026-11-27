import '../models/kubus_node_models.dart';
import 'spatial_web_delivery.dart';

enum SpatialWebLoadStatus { awaitingConsent, loading, ready, failed }

/// The state of one inline web viewer: which tier is loading, what a failure
/// does next, and when the visitor is asked before the archive starts.
///
/// Pure Dart on purpose. The browser-only widget owns the iframe and the
/// timers; every decision lives here so it runs in the VM test suite.
class SpatialWebLoadSession {
  /// [attemptBase] is the last attempt number of the session this one
  /// replaces (same viewer, refreshed record). Attempt numbers never repeat
  /// within one viewer, so a message still in flight from the old page cannot
  /// match the new session's first attempt.
  ///
  /// [constrained] is the device class (SpatialDeviceClass.constrained): such a
  /// device opens the preview tier first and asks before a large optimised
  /// model.
  SpatialWebLoadSession(
    this.content, {
    int attemptBase = 0,
    this.constrained = false,
  }) : attempt = attemptBase + 1 {
    final initial =
        SpatialWebDelivery.defaultVariant(content, constrained: constrained);
    if (initial != null) {
      _start(initial, bump: false);
    } else if (SpatialWebDelivery.archiveVariant(content) != null) {
      pending = SpatialWebDelivery.archiveVariant(content);
      status = SpatialWebLoadStatus.awaitingConsent;
    } else {
      status = SpatialWebLoadStatus.failed;
    }
  }

  final SpatialContent content;
  final bool constrained;

  /// The tier waiting for the visitor's go-ahead while [status] is
  /// [SpatialWebLoadStatus.awaitingConsent]; its [variant] stays unset.
  SpatialVariant? pending;

  SpatialWebLoadStatus status = SpatialWebLoadStatus.loading;
  SpatialVariant? variant;

  /// Incremented every time a (new) load starts; a stale async result carries
  /// the attempt it belongs to and is dropped when it no longer matches.
  int attempt;
  bool viewerReady = false;
  bool commandSent = false;

  SpatialVariant? get archive => SpatialWebDelivery.archiveVariant(content);

  bool get canOfferArchive =>
      archive != null &&
      variant?.role != 'spatial_archive' &&
      status == SpatialWebLoadStatus.ready;

  /// True when "Try again" would start something: a failed record with no
  /// viewable variant has nothing to retry, so the button must not be offered.
  bool get canRetry => variant != null || pending != null || archive != null;

  /// The optimised tier a constrained device may ask for once the preview is
  /// showing.
  SpatialVariant? get fullQuality => constrained &&
          variant?.role == 'spatial_preview' &&
          status == SpatialWebLoadStatus.ready
      ? SpatialWebDelivery.defaultTiers(content, constrained: true)
          .where((v) => v.role == 'spatial_mobile')
          .firstOrNull
      : null;

  /// The load budget of the tier now loading.
  Duration get timeout => variant == null
      ? const Duration(seconds: 120)
      : SpatialWebDelivery.loadTimeout(variant!);

  /// Opens [next], or parks it behind the visitor's confirmation when the size
  /// rule asks for one (a large optimised model on a constrained device).
  void _start(SpatialVariant next, {bool bump = true}) {
    if (next.role != 'spatial_archive' &&
        SpatialWebDelivery.needsConfirmation(next, constrained: constrained)) {
      variant = null;
      pending = next;
      if (bump) attempt++;
      viewerReady = false;
      commandSent = false;
      status = SpatialWebLoadStatus.awaitingConsent;
    } else {
      _begin(next, bump: bump);
    }
  }

  void _begin(SpatialVariant next, {bool bump = true}) {
    variant = next;
    pending = null;
    if (bump) attempt++;
    viewerReady = false;
    commandSent = false;
    status = SpatialWebLoadStatus.loading;
  }

  /// The viewer page booted and can take a load command.
  void onViewerReady() => viewerReady = true;

  /// True once, when the load command for the current attempt may be sent.
  bool takeLoadCommand() {
    if (variant == null ||
        commandSent ||
        !viewerReady ||
        status != SpatialWebLoadStatus.loading) {
      return false;
    }
    commandSent = true;
    return true;
  }

  /// True while the work started for [attemptNumber] still has somewhere to
  /// go: it is the current attempt and that attempt is still loading. A tier
  /// timeout that ends in the failed state (no fallback left) keeps the attempt
  /// number but ends the attempt, so the number alone is not enough.
  bool isLiveAttempt(int attemptNumber) =>
      attemptNumber == attempt && status == SpatialWebLoadStatus.loading;

  void onLoaded() {
    if (status == SpatialWebLoadStatus.loading) {
      status = SpatialWebLoadStatus.ready;
    }
  }

  /// A load failed (viewer error or timeout). A default tier falls back to the
  /// next default tier; the archive and the last tier end in the failed state.
  /// Returns true when a fallback tier started, so the caller restarts the
  /// iframe.
  bool onFailed() {
    if (status != SpatialWebLoadStatus.loading) return false;
    final current = variant;
    final next = current == null
        ? null
        : SpatialWebDelivery.nextTier(content, current,
            constrained: constrained);
    if (next != null) {
      _start(next);
      return status == SpatialWebLoadStatus.loading;
    }
    status = SpatialWebLoadStatus.failed;
    return false;
  }

  /// "Try again": the archive retries the archive, anything else starts over
  /// from the best default tier.
  void retry() {
    final current = variant;
    final target = current != null && current.role == 'spatial_archive'
        ? current
        : SpatialWebDelivery.defaultVariant(content,
                constrained: constrained) ??
            current ??
            pending ??
            archive;
    if (target != null) _start(target);
  }

  /// Starts the tier [needsConfirmation] parked: the caller has asked the
  /// visitor. Does nothing when no tier is waiting.
  void loadPending() {
    final target = pending;
    if (target != null) _begin(target);
  }

  /// Starts the optimised tier on request (a constrained device that opened
  /// the preview). Callers confirm first when
  /// [SpatialWebDelivery.needsConfirmation] says it is large.
  void loadFullQuality() {
    final target = SpatialWebDelivery.defaultTiers(content, constrained: true)
        .where((v) => v.role == 'spatial_mobile')
        .firstOrNull;
    if (target != null) _begin(target);
  }

  /// Starts the archive tier. Callers confirm first when
  /// [SpatialWebDelivery.archiveNeedsConfirmation] says the archive is large.
  void loadArchive() {
    final target = archive;
    if (target != null) _begin(target);
  }
}
