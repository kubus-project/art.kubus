import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/artwork.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/kubus_node_provider.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_reading_surface.dart';
import 'spatial_viewer.dart';

class ArtworkSpatialArchiveSection extends StatefulWidget {
  const ArtworkSpatialArchiveSection({required this.artwork, super.key});

  final Artwork artwork;

  @override
  State<ArtworkSpatialArchiveSection> createState() =>
      _ArtworkSpatialArchiveSectionState();
}

class _ArtworkSpatialArchiveSectionState
    extends State<ArtworkSpatialArchiveSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context
            .read<ArtworkProvider>()
            .loadSpatialHistory(widget.artwork.id)
            .catchError((_) => const ArtworkSpatialHistory(history: [])),
      );
    });
  }

  @override
  void didUpdateWidget(covariant ArtworkSpatialArchiveSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork.id == widget.artwork.id) return;
    unawaited(
      context
          .read<ArtworkProvider>()
          .loadSpatialHistory(widget.artwork.id)
          .catchError((_) => const ArtworkSpatialHistory(history: [])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArtworkProvider>();
    final history = provider.spatialHistoryFor(widget.artwork.id);
    final error = provider.spatialHistoryErrorFor(widget.artwork.id);
    final knownCount = widget.artwork.spatialCaptureCount;
    if ((history == null || history.history.isEmpty) && knownCount == 0) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    if (history == null || history.history.isEmpty) {
      if (error == null) return const SizedBox.shrink();
      return KubusReadingSurface(
        child: Row(
          children: [
            const Icon(Icons.view_in_ar_outlined),
            const SizedBox(width: KubusSpacing.sm),
            Expanded(child: Text(l10n.spatialViewerUnavailable)),
            TextButton(
              onPressed: () => unawaited(
                provider.loadSpatialHistory(widget.artwork.id, refresh: true),
              ),
              child: Text(l10n.spatialViewerRetry),
            ),
          ],
        ),
      );
    }
    final current = history.current!;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(current.capturedAt.toLocal());
    return KubusReadingSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_in_ar_outlined),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Text(
                  l10n.spatialArchiveTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(l10n.spatialCaptureCount(history.history.length)),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            l10n.spatialCapturedOn(date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: KubusSpacing.md),
          FilledButton.icon(
            onPressed: () => _openArchive(context, history),
            icon: const Icon(Icons.threed_rotation_rounded),
            label: Text(l10n.spatialViewIn3d),
          ),
        ],
      ),
    );
  }

  Future<void> _openArchive(
    BuildContext context,
    ArtworkSpatialHistory history,
  ) =>
      showDialog<void>(
        context: context,
        builder: (_) => _SpatialArchiveDialog(history: history),
      );
}

class _SpatialArchiveDialog extends StatefulWidget {
  const _SpatialArchiveDialog({required this.history});

  final ArtworkSpatialHistory history;

  @override
  State<_SpatialArchiveDialog> createState() => _SpatialArchiveDialogState();
}

class _SpatialArchiveDialogState extends State<_SpatialArchiveDialog> {
  late ArtworkSpatialCapture selected = widget.history.current!;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nodeService = context.read<KubusNodeProvider>().service;
    final size = MediaQuery.sizeOf(context);
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.spatialArchiveTitle),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: size.width),
                  child: SpatialViewer(
                    key: ValueKey(selected.id),
                    content: selected.content,
                    nodeService: nodeService,
                  ),
                ),
              ),
            ),
            if (widget.history.history.length > 1)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.spatialHistoryTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final capture in widget.history.history) ...[
                              ChoiceChip(
                                selected: capture.id == selected.id,
                                avatar:
                                    const Icon(Icons.layers_outlined, size: 18),
                                label: Text(
                                  MaterialLocalizations.of(context)
                                      .formatMediumDate(
                                          capture.capturedAt.toLocal()),
                                ),
                                onSelected: (_) =>
                                    setState(() => selected = capture),
                              ),
                              const SizedBox(width: KubusSpacing.sm),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
