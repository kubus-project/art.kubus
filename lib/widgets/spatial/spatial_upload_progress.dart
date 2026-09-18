import 'package:flutter/material.dart';

import '../../features/spatial/spatial_transfer_presentation.dart';
import '../../l10n/app_localizations.dart';
import '../../services/spatial_node_upload.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_meter_bar.dart';
import '../inline_loading.dart';

/// What a Spatial transfer is actually doing, while it is doing it.
///
/// A bar and a spinner cannot answer the questions a transfer raises — how
/// much is left, how fast it is going, whether it has stopped, and whether the
/// phone still needs to be on this network. Every line here is a measurement;
/// a line the transfer cannot yet justify is simply absent rather than filled
/// with a plausible number.
class SpatialUploadProgress extends StatelessWidget {
  const SpatialUploadProgress({super.key, required this.progress});

  final SpatialTransferProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final view = SpatialTransferPresentation.forProgress(l10n, progress);
    if (view == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final detail = <String>[
      if (view.bytesLabel != null) view.bytesLabel!,
      if (view.throughputLabel != null) view.throughputLabel!,
      if (view.etaLabel != null) view.etaLabel!,
    ];
    final footer = <String>[
      if (view.filesLabel != null) view.filesLabel!,
      if (view.routeLabel != null) view.routeLabel!,
    ];

    return Semantics(
      container: true,
      liveRegion: true,
      // The bar is a picture of the same fact. A screen reader gets the
      // sentence, so progress is never carried by the visual alone.
      label: view.semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    view.phaseLabel,
                    style: KubusTextStyles.detailCardTitle,
                  ),
                ),
                if (view.percentLabel != null) ...<Widget>[
                  const SizedBox(width: KubusSpacing.xs),
                  Text(
                    view.percentLabel!,
                    // Tabular figures so the number does not jitter as it
                    // counts up.
                    style: KubusTextStyles.detailCardTitle.copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: KubusSpacing.xs),
            if (view.indeterminate)
              const InlineLoading(height: 6)
            else
              KubusMeterBar(progress: view.fraction ?? 0),
            if (detail.isNotEmpty) ...<Widget>[
              const SizedBox(height: KubusSpacing.xs),
              Text(
                detail.join(' · '),
                style: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
            if (footer.isNotEmpty) ...<Widget>[
              const SizedBox(height: KubusSpacing.xxs),
              Text(
                footer.join(' · '),
                style: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
