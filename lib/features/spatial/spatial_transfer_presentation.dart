import '../../l10n/app_localizations.dart';
import '../../services/node/kubus_node_transport.dart';
import '../../services/spatial_node_upload.dart';
import '../../utils/node_state_presentation.dart';

/// Everything an upload surface shows, derived from measured progress alone.
///
/// Pure, so the rules about what may be claimed are testable without a widget:
/// a percentage only when the total is known, a speed only once one has been
/// measured, and a countdown only while the transfer is actually moving.
class SpatialTransferPresentation {
  const SpatialTransferPresentation({
    required this.phaseLabel,
    required this.semanticsLabel,
    this.fraction,
    this.percentLabel,
    this.bytesLabel,
    this.throughputLabel,
    this.etaLabel,
    this.filesLabel,
    this.routeLabel,
    this.indeterminate = false,
  });

  /// What the transfer is doing, in the user's words.
  final String phaseLabel;

  /// One sentence for a screen reader, so progress is not conveyed by the bar
  /// alone.
  final String semanticsLabel;

  /// Measured fraction, or null when there is no honest one to draw.
  final double? fraction;

  /// Exact percentage, present only alongside [fraction].
  final String? percentLabel;

  final String? bytesLabel;
  final String? throughputLabel;

  /// Either a measured countdown or, when the transfer has stopped moving,
  /// what is actually happening. Never a countdown against a stalled transfer.
  final String? etaLabel;

  final String? filesLabel;
  final String? routeLabel;

  /// True when the bar must animate rather than fill: a real phase with no
  /// measurable fraction, never a fabricated one.
  final bool indeterminate;

  /// Reads [progress], or null when nothing is being transferred.
  static SpatialTransferPresentation? forProgress(
    AppLocalizations l10n,
    SpatialTransferProgress progress,
  ) {
    if (!progress.isActive) return null;

    final phaseLabel = switch (progress.phase) {
      SpatialTransferPhase.preparing => l10n.spatialTransferPreparing,
      SpatialTransferPhase.uploading => l10n.spatialLibraryStatusUploading,
      SpatialTransferPhase.validating => l10n.spatialTransferValidating,
      SpatialTransferPhase.repairing => l10n.spatialTransferRepairing,
      SpatialTransferPhase.idle || SpatialTransferPhase.complete => '',
    };

    final route = _routeLabel(l10n, progress.route);

    // Preparing and validating are real phases with nothing to measure. An
    // indeterminate bar says "working" honestly; a made-up percentage does
    // not.
    if (progress.phase != SpatialTransferPhase.uploading &&
        progress.phase != SpatialTransferPhase.repairing) {
      return SpatialTransferPresentation(
        phaseLabel: phaseLabel,
        semanticsLabel: phaseLabel,
        routeLabel: route,
        indeterminate: true,
      );
    }

    final fraction = progress.fraction;
    final percent =
        fraction == null ? null : '${(fraction * 100).floor().clamp(0, 100)}%';
    final bytes = progress.totalBytes > 0
        ? l10n.spatialTransferBytes(
            NodeStatePresentation.formatBytes(progress.uploadedBytes),
            NodeStatePresentation.formatBytes(progress.totalBytes),
          )
        : null;
    final rate = progress.bytesPerSecond;
    final throughput = rate == null || progress.stalled
        ? null
        : l10n.spatialTransferThroughput(
            NodeStatePresentation.formatBytes(rate.round()),
          );
    final eta = progress.stalled
        ? l10n.spatialTransferWaiting
        : (progress.eta == null
            ? null
            : l10n.spatialTransferEta(_duration(l10n, progress.eta!)));
    final files = progress.totalFiles > 0
        ? l10n.spatialTransferFiles(progress.uploadedFiles, progress.totalFiles)
        : null;

    return SpatialTransferPresentation(
      phaseLabel: phaseLabel,
      semanticsLabel: <String?>[phaseLabel, percent, bytes, eta]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(', '),
      fraction: fraction,
      percentLabel: percent,
      bytesLabel: bytes,
      throughputLabel: throughput,
      etaLabel: eta,
      filesLabel: files,
      routeLabel: route,
      indeterminate: fraction == null,
    );
  }

  /// Restrained diagnostic wording: which route, not which address.
  static String? _routeLabel(
    AppLocalizations l10n,
    KubusNodeTransportKind? route,
  ) =>
      switch (route) {
        KubusNodeTransportKind.localDirect => l10n.spatialTransferRouteLocal,
        KubusNodeTransportKind.remoteHttps => l10n.spatialTransferRouteRemote,
        KubusNodeTransportKind.webRtcDirect => l10n.spatialTransferRouteDirect,
        KubusNodeTransportKind.webRtcRelay => l10n.spatialTransferRouteRelay,
        null => null,
      };

  static String _duration(AppLocalizations l10n, Duration remaining) {
    if (remaining.inMinutes < 1) {
      return l10n.spatialDurationSeconds(remaining.inSeconds.clamp(1, 59));
    }
    if (remaining.inHours < 1) {
      return l10n.spatialDurationMinutes(remaining.inMinutes);
    }
    return l10n.spatialDurationHours(
      remaining.inHours,
      remaining.inMinutes.remainder(60),
    );
  }
}
