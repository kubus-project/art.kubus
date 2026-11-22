import '../models/kubus_node_models.dart';
import 'spatial_web_delivery.dart';

enum SpatialWebLoadStatus { awaitingArchiveConsent, loading, ready, failed }

/// The state of one inline web viewer: which tier is loading, what a failure
/// does next, and when the visitor is asked before the archive starts.
///
/// Pure Dart on purpose. The browser-only widget owns the iframe and the
/// timers; every decision lives here so it runs in the VM test suite.
class SpatialWebLoadSession {
  SpatialWebLoadSession(this.content) {
    final initial = SpatialWebDelivery.defaultVariant(content);
    if (initial != null) {
      _begin(initial);
    } else if (SpatialWebDelivery.archiveVariant(content) != null) {
      status = SpatialWebLoadStatus.awaitingArchiveConsent;
    } else {
      status = SpatialWebLoadStatus.failed;
    }
  }

  final SpatialContent content;

  SpatialWebLoadStatus status = SpatialWebLoadStatus.loading;
  SpatialVariant? variant;

  /// Incremented every time a (new) load starts; a stale async result carries
  /// the attempt it belongs to and is dropped when it no longer matches.
  int attempt = 0;
  bool viewerReady = false;
  bool commandSent = false;

  SpatialVariant? get archive => SpatialWebDelivery.archiveVariant(content);

  bool get canOfferArchive =>
      archive != null &&
      variant?.role != 'spatial_archive' &&
      status == SpatialWebLoadStatus.ready;

  /// The load budget of the tier now loading.
  Duration get timeout => variant == null
      ? const Duration(seconds: 120)
      : SpatialWebDelivery.loadTimeout(variant!);

  void _begin(SpatialVariant next) {
    variant = next;
    attempt++;
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
    final next =
        current == null ? null : SpatialWebDelivery.nextTier(content, current);
    if (next != null) {
      _begin(next);
      return true;
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
        : SpatialWebDelivery.defaultVariant(content) ?? current ?? archive;
    if (target != null) _begin(target);
  }

  /// Starts the archive tier. Callers confirm first when
  /// [SpatialWebDelivery.archiveNeedsConfirmation] says the archive is large.
  void loadArchive() {
    final target = archive;
    if (target != null) _begin(target);
  }
}
