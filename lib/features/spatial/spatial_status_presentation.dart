import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/spatial_library_store.dart';
import '../../utils/kubus_color_roles.dart';

/// Semantic tone of a spatial status.
///
/// Tones — not hues. Every surface that shows spatial state resolves the tone
/// through [KubusColorRoles] so the capture card, the detail screen, the AR
/// header and the processing sheet cannot drift apart, and so a theme change
/// moves all of them together.
enum SpatialStatusTone {
  /// No state worth accenting (private, idle).
  neutral,

  /// Capture data exists on the device.
  captured,

  /// Waiting on something outside the app: a processor, a provider, the user.
  pending,

  /// Work is measurably in flight.
  active,

  /// Finished successfully.
  positive,

  /// Usable but out of date or degraded.
  warning,

  /// Failed.
  negative,
}

extension SpatialStatusToneColor on SpatialStatusTone {
  /// Resolves the tone against the app's semantic roles.
  Color resolve(KubusColorRoles roles, ColorScheme scheme) => switch (this) {
        SpatialStatusTone.neutral => scheme.onSurfaceVariant,
        SpatialStatusTone.captured => roles.statTeal,
        SpatialStatusTone.pending => roles.statAmber,
        SpatialStatusTone.active => roles.statBlue,
        SpatialStatusTone.positive => roles.positiveAction,
        SpatialStatusTone.warning => roles.warningAction,
        SpatialStatusTone.negative => roles.negativeAction,
      };

  Color of(BuildContext context) =>
      resolve(KubusColorRoles.of(context), Theme.of(context).colorScheme);
}

/// One status, presented the same way everywhere.
@immutable
class SpatialStatusPresentation {
  const SpatialStatusPresentation({
    required this.label,
    required this.icon,
    required this.tone,
    this.progress,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final SpatialStatusTone tone;

  /// Measured progress in 0..1, or null when no honest fraction exists.
  /// Never interpolated: an unknown duration stays indeterminate.
  final double? progress;

  /// Whether the state is actively moving, so meters animate rather than sit.
  final bool busy;

  Color accent(BuildContext context) => tone.of(context);

  /// The single status shown for a library record.
  ///
  /// Order matters: an active network request outranks the local processing
  /// state, because a request that is still searching for a provider is the
  /// truest thing to say about a record whose local state is only "captured".
  static SpatialStatusPresentation forRecord(
    AppLocalizations l10n,
    SpatialLibraryRecord record,
  ) {
    final request = record.networkRequest;
    if (request != null && request.isActive && !record.isBusy) {
      return _forNetworkRequest(l10n, request.state);
    }
    if (record.hasStaleResult) {
      return SpatialStatusPresentation(
        label: l10n.spatialLibraryStatusReprocessNeeded,
        icon: Icons.update_rounded,
        tone: SpatialStatusTone.warning,
      );
    }
    switch (record.processingState) {
      case SpatialLibraryProcessingState.capturing:
      case SpatialLibraryProcessingState.capturedPrivate:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusCaptured,
          icon: Icons.camera_alt_outlined,
          tone: SpatialStatusTone.captured,
        );
      case SpatialLibraryProcessingState.waitingForProcessor:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusWaiting,
          icon: Icons.hourglass_empty_rounded,
          tone: SpatialStatusTone.pending,
        );
      case SpatialLibraryProcessingState.uploading:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusUploading,
          icon: Icons.cloud_upload_outlined,
          tone: SpatialStatusTone.active,
          progress: record.totalUploadBytes > 0
              ? (record.uploadedBytes / record.totalUploadBytes)
                  .clamp(0.0, 1.0)
                  .toDouble()
              : null,
          busy: true,
        );
      case SpatialLibraryProcessingState.queued:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusQueued,
          icon: Icons.schedule_rounded,
          tone: SpatialStatusTone.active,
          busy: true,
        );
      case SpatialLibraryProcessingState.processing:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusProcessing,
          icon: Icons.memory_rounded,
          tone: SpatialStatusTone.active,
          busy: true,
        );
      case SpatialLibraryProcessingState.downloadingResult:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusDownloading,
          icon: Icons.cloud_download_outlined,
          tone: SpatialStatusTone.active,
          busy: true,
        );
      case SpatialLibraryProcessingState.readyPrivate:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusReady,
          icon: Icons.check_circle_outline_rounded,
          tone: SpatialStatusTone.positive,
        );
      case SpatialLibraryProcessingState.publishing:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusPublishing,
          icon: Icons.publish_rounded,
          tone: SpatialStatusTone.active,
          busy: true,
        );
      case SpatialLibraryProcessingState.published:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusPublished,
          icon: Icons.public_rounded,
          tone: SpatialStatusTone.positive,
        );
      case SpatialLibraryProcessingState.failedRetryable:
        return SpatialStatusPresentation(
          label: l10n.spatialLibraryStatusFailed,
          icon: Icons.error_outline_rounded,
          tone: SpatialStatusTone.negative,
        );
    }
  }

  /// The status of a persisted network compute request on its own.
  static SpatialStatusPresentation forNetworkRequest(
    AppLocalizations l10n,
    SpatialNetworkRequestState state,
  ) =>
      _forNetworkRequest(l10n, state);

  static SpatialStatusPresentation _forNetworkRequest(
    AppLocalizations l10n,
    SpatialNetworkRequestState state,
  ) =>
      switch (state) {
        SpatialNetworkRequestState.networkRequested =>
          SpatialStatusPresentation(
            label: l10n.spatialNetworkStateRequested,
            icon: Icons.hub_outlined,
            tone: SpatialStatusTone.pending,
          ),
        SpatialNetworkRequestState.searchingProvider =>
          SpatialStatusPresentation(
            label: l10n.spatialNetworkStateSearching,
            icon: Icons.travel_explore_rounded,
            tone: SpatialStatusTone.pending,
            busy: true,
          ),
        SpatialNetworkRequestState.providerOffered => SpatialStatusPresentation(
            label: l10n.spatialNetworkStateOffered,
            icon: Icons.handshake_outlined,
            tone: SpatialStatusTone.pending,
          ),
        SpatialNetworkRequestState.providerAccepted =>
          SpatialStatusPresentation(
            label: l10n.spatialNetworkStateAccepted,
            icon: Icons.verified_outlined,
            tone: SpatialStatusTone.active,
          ),
        SpatialNetworkRequestState.queued => SpatialStatusPresentation(
            label: l10n.spatialLibraryStatusQueued,
            icon: Icons.schedule_rounded,
            tone: SpatialStatusTone.active,
            busy: true,
          ),
        SpatialNetworkRequestState.processing => SpatialStatusPresentation(
            label: l10n.spatialLibraryStatusProcessing,
            icon: Icons.memory_rounded,
            tone: SpatialStatusTone.active,
            busy: true,
          ),
        SpatialNetworkRequestState.verifying => SpatialStatusPresentation(
            label: l10n.spatialNetworkStateVerifying,
            icon: Icons.fact_check_outlined,
            tone: SpatialStatusTone.active,
            busy: true,
          ),
        SpatialNetworkRequestState.downloading => SpatialStatusPresentation(
            label: l10n.spatialLibraryStatusDownloading,
            icon: Icons.cloud_download_outlined,
            tone: SpatialStatusTone.active,
            busy: true,
          ),
        SpatialNetworkRequestState.complete => SpatialStatusPresentation(
            label: l10n.spatialLibraryStatusReady,
            icon: Icons.check_circle_outline_rounded,
            tone: SpatialStatusTone.positive,
          ),
        SpatialNetworkRequestState.failed => SpatialStatusPresentation(
            label: l10n.spatialLibraryStatusFailed,
            icon: Icons.error_outline_rounded,
            tone: SpatialStatusTone.negative,
          ),
        SpatialNetworkRequestState.expired => SpatialStatusPresentation(
            label: l10n.spatialNetworkStateExpired,
            icon: Icons.timer_off_outlined,
            tone: SpatialStatusTone.warning,
          ),
        SpatialNetworkRequestState.cancelled => SpatialStatusPresentation(
            label: l10n.spatialNetworkStateCancelled,
            icon: Icons.cancel_outlined,
            tone: SpatialStatusTone.neutral,
          ),
      };

  /// Publication state, shown beside the processing status rather than folded
  /// into it: "Ready" and "Private" are two different facts.
  static SpatialStatusPresentation forPublication(
    AppLocalizations l10n,
    SpatialLibraryRecord record,
  ) =>
      switch (record.publicationState) {
        SpatialLibraryPublicationState.published => SpatialStatusPresentation(
            label: record.version == null
                ? l10n.spatialLibraryPublic
                : l10n.spatialLibraryVersionLabel(record.version!),
            icon: Icons.public_rounded,
            tone: SpatialStatusTone.positive,
          ),
        SpatialLibraryPublicationState.publishing => SpatialStatusPresentation(
            label: l10n.spatialLibraryStatusPublishing,
            icon: Icons.publish_rounded,
            tone: SpatialStatusTone.active,
            busy: true,
          ),
        SpatialLibraryPublicationState.failed => SpatialStatusPresentation(
            label: l10n.spatialLibraryStatusFailed,
            icon: Icons.error_outline_rounded,
            tone: SpatialStatusTone.negative,
          ),
        SpatialLibraryPublicationState.private => SpatialStatusPresentation(
            label: l10n.spatialLibraryPrivate,
            icon: Icons.lock_outline_rounded,
            tone: SpatialStatusTone.neutral,
          ),
      };
}
