import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/spatial_library_store.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/kubus_kit.dart';
import 'spatial_failure_messages.dart';
import 'spatial_status_presentation.dart';

/// A titled block on the spatial detail screen.
///
/// The detail screen is a content-management surface, so it reads as sections
/// with one job each — Capture, Processing, Archive — rather than a metadata
/// table followed by a wall of equally weighted buttons.
class SpatialDetailSection extends StatelessWidget {
  const SpatialDetailSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return KubusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: KubusTextStyles.detailSectionTitle,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// A label/value row inside a section.
class SpatialDetailMetric extends StatelessWidget {
  const SpatialDetailMetric({
    super.key,
    required this.label,
    required this.value,
    this.emphasis,
  });

  final String label;
  final String value;

  /// Optional semantic accent for a value that carries state.
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: KubusTextStyles.detailBody.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: KubusTextStyles.detailBody.copyWith(
                color: emphasis ?? scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The capture-quality block: what was actually recorded.
class SpatialCaptureQuality extends StatelessWidget {
  const SpatialCaptureQuality({super.key, required this.record});

  final SpatialLibraryRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final coverage = _coverageFraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (coverage != null) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.spatialLibraryCoverage,
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                l10n.spatialLibraryCoveragePercent((coverage * 100).round()),
                style: KubusTextStyles.detailBody.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.xs),
          KubusMeterBar(
            progress: coverage,
            color: coverage >= 0.8 ? roles.positiveAction : roles.statTeal,
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],
        SpatialDetailMetric(
          label: l10n.spatialLibraryTrackedViews(record.sampleCount),
          value: record.hasDepth
              ? l10n.spatialLibraryDepthAvailable
              : l10n.spatialLibraryDepthUnavailable,
        ),
        SpatialDetailMetric(
          label: l10n.spatialLibraryRawSource,
          value: record.rawPresent
              ? NodeStatePresentation.formatBytes(record.sourceBytes)
              : l10n.spatialLibraryRawSourceDeleted,
          emphasis: record.rawPresent ? null : scheme.onSurfaceVariant,
        ),
        SpatialDetailMetric(
          label: l10n.spatialLibraryCapturedOnLabel,
          value: MaterialLocalizations.of(context)
              .formatMediumDate(record.capturedAt.toLocal()),
        ),
      ],
    );
  }

  /// Coverage as recorded at capture time, or null when it was never measured.
  ///
  /// Never inferred from the sample count: a hundred frames from one spot is
  /// not good coverage, and saying otherwise would be a lie the pipeline can
  /// not back up.
  double? get _coverageFraction {
    final raw = record.coverageMetadata['progress'];
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null || value.isNaN) return null;
    return value.clamp(0.0, 1.0).toDouble();
  }
}

/// The processing block: what is happening, or what could.
class SpatialProcessingStatus extends StatelessWidget {
  const SpatialProcessingStatus({super.key, required this.record});

  final SpatialLibraryRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final request = record.networkRequest;
    final status = SpatialStatusPresentation.forRecord(l10n, record);
    final failure = SpatialFailureMessages.reason(l10n, record.lastErrorCode);
    final showsStatus = record.isBusy ||
        record.hasActiveNetworkRequest ||
        record.hasLocalResult ||
        record.processingState == SpatialLibraryProcessingState.failedRetryable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!showsStatus)
          Text(
            l10n.spatialLibraryNotProcessed,
            style: KubusTextStyles.detailBody.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              KubusBadge(
                text: status.label,
                icon: status.icon,
                variant: KubusBadgeVariant.status,
                accent: status.accent(context),
              ),
            ],
          ),
          if (status.busy || status.progress != null) ...<Widget>[
            const SizedBox(height: KubusSpacing.sm),
            // Measured where the pipeline reports a fraction, indeterminate
            // where it does not. A fabricated percentage is worse than none.
            InlineLoading(
              height: KubusSizes.meterStandard,
              progress: status.progress,
              animate: status.progress == null,
              color: status.accent(context),
            ),
          ],
        ],
        if (request != null && request.providerLabel != null) ...<Widget>[
          const SizedBox(height: KubusSpacing.sm),
          SpatialDetailMetric(
            label: l10n.spatialProviderLabel,
            value: request.providerLabel!,
          ),
          if (request.queuedAhead != null)
            SpatialDetailMetric(
              label: l10n.spatialProviderQueueAhead(request.queuedAhead!),
              value: request.providerTier ?? l10n.spatialProviderNoEstimate,
            ),
          if (request.estimatedDurationSeconds != null)
            SpatialDetailMetric(
              label: l10n.spatialProviderEstimatedDuration(
                (request.estimatedDurationSeconds! / 60).ceil(),
              ),
              value: request.estimatedCostKub8 == null
                  ? l10n.spatialProviderNoEstimate
                  : l10n.spatialProviderEstimatedCost(
                      request.estimatedCostKub8!.toStringAsFixed(2),
                    ),
            ),
        ],
        if (record.hasStaleResult) ...<Widget>[
          const SizedBox(height: KubusSpacing.sm),
          _Advisory(
            message: l10n.spatialLibraryStaleResultWarning,
            tone: SpatialStatusTone.warning,
          ),
        ],
        if (failure != null) ...<Widget>[
          const SizedBox(height: KubusSpacing.sm),
          _Advisory(message: failure, tone: SpatialStatusTone.negative),
          if (record.rawPresent) ...<Widget>[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              l10n.spatialFailureRawIntact,
              style: KubusTextStyles.detailCaption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _Advisory extends StatelessWidget {
  const _Advisory({required this.message, required this.tone});

  final String message;
  final SpatialStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone.of(context);
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        border: KubusBorders.accentTint(accent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            tone == SpatialStatusTone.negative
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            size: KubusHeaderMetrics.actionIcon,
            color: accent,
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Text(message, style: KubusTextStyles.detailCaption),
          ),
        ],
      ),
    );
  }
}
