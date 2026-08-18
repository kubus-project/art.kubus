import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/kubus_node_provider.dart';
import '../../providers/spatial_library_provider.dart';
import '../../services/kubus_node_service.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../services/spatial_library_store.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/kubus_kit.dart';
import '../../widgets/spatial/spatial_viewer.dart';

enum _LibraryFilter { all, captured, processing, ready, published }

@visibleForTesting
enum SpatialLibraryAction {
  process,
  publish,
  share,
  deleteRaw,
  deleteProcessed,
  deleteRecord,
}

@visibleForTesting
Set<SpatialLibraryAction> spatialLibraryActionsFor(
  SpatialLibraryRecord record,
) {
  final actions = <SpatialLibraryAction>{SpatialLibraryAction.deleteRecord};
  final processing = const <SpatialLibraryProcessingState>{
    SpatialLibraryProcessingState.uploading,
    SpatialLibraryProcessingState.queued,
    SpatialLibraryProcessingState.processing,
    SpatialLibraryProcessingState.downloadingResult,
    SpatialLibraryProcessingState.publishing,
  }.contains(record.processingState);
  if (record.rawPresent && !processing && !record.hasLocalResult) {
    actions.add(SpatialLibraryAction.process);
  }
  if (record.hasLocalResult &&
      record.publicationState != SpatialLibraryPublicationState.published) {
    actions.add(SpatialLibraryAction.publish);
  }
  if (record.publicationState == SpatialLibraryPublicationState.published) {
    actions.add(SpatialLibraryAction.share);
  }
  if (record.rawPresent && record.hasLocalResult) {
    actions.add(SpatialLibraryAction.deleteRaw);
  }
  if (record.hasLocalResult) {
    actions.add(SpatialLibraryAction.deleteProcessed);
  }
  return actions;
}

class SpatialLibraryScreen extends StatefulWidget {
  const SpatialLibraryScreen({
    this.artworkTitleResolver,
    this.viewerNodeService,
    super.key,
  });

  @visibleForTesting
  final String? Function(String artworkId)? artworkTitleResolver;

  @visibleForTesting
  final KubusNodeService? viewerNodeService;

  @override
  State<SpatialLibraryScreen> createState() => _SpatialLibraryScreenState();
}

class _SpatialLibraryScreenState extends State<SpatialLibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<SpatialLibraryProvider>();
    final l10n = AppLocalizations.of(context)!;
    final filtered = library.records.where(_matchesFilter).toList();
    final raw =
        library.records.fold<int>(0, (sum, item) => sum + item.sourceBytes);
    final processed =
        library.records.fold<int>(0, (sum, item) => sum + item.resultBytes);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spatialLibraryTitle),
        actions: <Widget>[
          IconButton(
            tooltip:
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            onPressed:
                library.loading ? null : () => unawaited(library.reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: library.reload,
        child: ListView(
          padding: const EdgeInsets.all(KubusSpacing.md),
          children: <Widget>[
            _StorageSummary(raw: raw, processed: processed),
            const SizedBox(height: KubusSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _LibraryFilter.values
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: KubusSpacing.sm),
                        child: KubusGlassChip(
                          label: _filterLabel(l10n, filter),
                          icon: _filterIcon(filter),
                          active: _filter == filter,
                          onPressed: () => setState(() => _filter = filter),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            if (library.loading && library.records.isEmpty)
              const Center(child: InlineLoading(width: 72, height: 72))
            else if (filtered.isEmpty)
              EmptyStateCard(
                icon: Icons.view_in_ar_outlined,
                title: l10n.spatialLibraryTitle,
                description: l10n.spatialLibraryEmpty,
              )
            else
              for (final record in filtered) ...<Widget>[
                _SpatialRecordCard(
                  record: record,
                  artworkTitle:
                      widget.artworkTitleResolver?.call(record.artworkId) ??
                          context
                              .watch<ArtworkProvider>()
                              .getArtworkById(record.artworkId)
                              ?.title,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SpatialLibraryDetailScreen(
                        localSpatialId: record.localSpatialId,
                        artworkTitleResolver: widget.artworkTitleResolver,
                        viewerNodeService: widget.viewerNodeService,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(SpatialLibraryRecord record) => switch (_filter) {
        _LibraryFilter.all => true,
        _LibraryFilter.captured => const <SpatialLibraryProcessingState>{
            SpatialLibraryProcessingState.capturedPrivate,
            SpatialLibraryProcessingState.waitingForProcessor,
            SpatialLibraryProcessingState.failedRetryable,
          }.contains(record.processingState),
        _LibraryFilter.processing => const <SpatialLibraryProcessingState>{
            SpatialLibraryProcessingState.uploading,
            SpatialLibraryProcessingState.queued,
            SpatialLibraryProcessingState.processing,
            SpatialLibraryProcessingState.downloadingResult,
            SpatialLibraryProcessingState.publishing,
          }.contains(record.processingState),
        _LibraryFilter.ready =>
          record.processingState == SpatialLibraryProcessingState.readyPrivate,
        _LibraryFilter.published =>
          record.publicationState == SpatialLibraryPublicationState.published,
      };

  static String _filterLabel(AppLocalizations l10n, _LibraryFilter filter) =>
      switch (filter) {
        _LibraryFilter.all => l10n.spatialLibraryFilterAll,
        _LibraryFilter.captured => l10n.spatialLibraryFilterCaptured,
        _LibraryFilter.processing => l10n.spatialLibraryFilterProcessing,
        _LibraryFilter.ready => l10n.spatialLibraryFilterReady,
        _LibraryFilter.published => l10n.spatialLibraryFilterPublished,
      };

  static IconData _filterIcon(_LibraryFilter filter) => switch (filter) {
        _LibraryFilter.all => Icons.grid_view_rounded,
        _LibraryFilter.captured => Icons.camera_alt_outlined,
        _LibraryFilter.processing => Icons.memory_rounded,
        _LibraryFilter.ready => Icons.check_circle_outline_rounded,
        _LibraryFilter.published => Icons.public_rounded,
      };
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.raw, required this.processed});

  final int raw;
  final int processed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 520
            ? (constraints.maxWidth - KubusSpacing.sm) / 2
            : (constraints.maxWidth - (KubusSpacing.sm * 2)) / 3;
        return Wrap(
          spacing: KubusSpacing.sm,
          runSpacing: KubusSpacing.sm,
          children: <Widget>[
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.spatialLibraryRawStorage,
                value: NodeStatePresentation.formatBytes(raw),
                icon: Icons.camera_alt_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.spatialLibraryProcessedStorage,
                value: NodeStatePresentation.formatBytes(processed),
                icon: Icons.view_in_ar_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.spatialLibraryTotalStorage,
                value: NodeStatePresentation.formatBytes(raw + processed),
                icon: Icons.storage_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpatialRecordCard extends StatelessWidget {
  const _SpatialRecordCard({
    required this.record,
    required this.artworkTitle,
    required this.onTap,
  });

  final SpatialLibraryRecord record;
  final String? artworkTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final thumbnail =
        record.thumbnailPath == null ? null : File(record.thumbnailPath!);
    return KubusCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            child: SizedBox(
              width: 76,
              height: 76,
              child: thumbnail != null && thumbnail.existsSync()
                  ? Image.file(thumbnail, fit: BoxFit.cover, cacheWidth: 240)
                  : ColoredBox(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.view_in_ar_outlined),
                    ),
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  artworkTitle ?? record.artworkId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: KubusSpacing.xxs),
                Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(record.capturedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: KubusSpacing.xs),
                Wrap(
                  spacing: KubusSpacing.xs,
                  runSpacing: KubusSpacing.xs,
                  children: <Widget>[
                    KubusBadge(
                        text: _statusLabel(l10n, record.processingState)),
                    KubusBadge(
                      text: record.publicationState ==
                              SpatialLibraryPublicationState.published
                          ? l10n.spatialLibraryPublic
                          : l10n.spatialLibraryPrivate,
                    ),
                    KubusBadge(
                      text:
                          NodeStatePresentation.formatBytes(record.totalBytes),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class SpatialLibraryDetailScreen extends StatefulWidget {
  const SpatialLibraryDetailScreen({
    required this.localSpatialId,
    this.artworkTitleResolver,
    this.viewerNodeService,
    super.key,
  });

  final String localSpatialId;
  final String? Function(String artworkId)? artworkTitleResolver;
  final KubusNodeService? viewerNodeService;

  @override
  State<SpatialLibraryDetailScreen> createState() =>
      _SpatialLibraryDetailScreenState();
}

class _SpatialLibraryDetailScreenState
    extends State<SpatialLibraryDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpatialLibraryProvider>();
    final record = provider.records
        .where((item) => item.localSpatialId == widget.localSpatialId)
        .firstOrNull;
    final l10n = AppLocalizations.of(context)!;
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.spatialLibraryTitle)),
        body: Center(child: Text(l10n.spatialLibraryEmpty)),
      );
    }
    final artworkTitle = widget.artworkTitleResolver?.call(record.artworkId) ??
        context
            .watch<ArtworkProvider>()
            .getArtworkById(record.artworkId)
            ?.title;
    return Scaffold(
      appBar: AppBar(title: Text(artworkTitle ?? l10n.spatialLibraryTitle)),
      body: ListView(
        padding: const EdgeInsets.all(KubusSpacing.md),
        children: <Widget>[
          if (record.hasLocalResult)
            SizedBox(
              height: 420,
              child: FutureBuilder<SpatialContent>(
                future: provider.loadLocalContent(record.localSpatialId),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return SpatialViewer(
                      content: snapshot.data!,
                      nodeService: widget.viewerNodeService ??
                          context.read<KubusNodeProvider>().service,
                    );
                  }
                  if (snapshot.hasError) {
                    return EmptyStateCard(
                      icon: Icons.broken_image_outlined,
                      title: l10n.spatialViewerUnavailable,
                      description: snapshot.error.toString(),
                    );
                  }
                  return const Center(
                      child: InlineLoading(width: 72, height: 72));
                },
              ),
            ),
          if (record.hasLocalResult) const SizedBox(height: KubusSpacing.md),
          KubusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _statusLabel(l10n, record.processingState),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: KubusSpacing.sm),
                _metric(l10n.spatialLibraryRawStorage,
                    NodeStatePresentation.formatBytes(record.sourceBytes)),
                _metric(l10n.spatialLibraryProcessedStorage,
                    NodeStatePresentation.formatBytes(record.resultBytes)),
                _metric(l10n.spatialLibraryTotalStorage,
                    NodeStatePresentation.formatBytes(record.totalBytes)),
                _metric(
                  l10n.spatialLibraryPublic,
                  record.publicationState ==
                          SpatialLibraryPublicationState.published
                      ? l10n.spatialLibraryPublic
                      : l10n.spatialLibraryPrivate,
                ),
                if (record.lastErrorCode != null)
                  _metric(
                      l10n.spatialLibraryStatusFailed, record.lastErrorCode!),
              ],
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: _actions(context, provider, record),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(value),
          ],
        ),
      );

  List<Widget> _actions(
    BuildContext context,
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final actions = <Widget>[];
    final available = spatialLibraryActionsFor(record);
    if (available.contains(SpatialLibraryAction.process)) {
      final retry = record.uploadedFiles > 0;
      actions.add(
        KubusButton(
          onPressed: _busy
              ? null
              : () => unawaited(_chooseProcessor(provider, record)),
          label: retry
              ? l10n.spatialLibraryRetryUpload
              : record.processingState ==
                      SpatialLibraryProcessingState.failedRetryable
                  ? l10n.spatialLibraryRetryProcessing
                  : l10n.spatialLibraryProcess,
          icon: Icons.memory_rounded,
          variant: KubusButtonVariant.accent,
        ),
      );
    }
    if (available.contains(SpatialLibraryAction.publish)) {
      actions.add(
        KubusButton(
          onPressed: _busy
              ? null
              : () => unawaited(
                  _run(() => provider.publish(record.localSpatialId))),
          label: l10n.spatialLibraryPublish,
          icon: Icons.public_rounded,
          variant: KubusButtonVariant.accent,
        ),
      );
    }
    if (available.contains(SpatialLibraryAction.share)) {
      actions.add(
        KubusButton(
          onPressed: _busy
              ? null
              : () => ShareService().showShareSheet(
                    context,
                    target: ShareTarget.artwork(artworkId: record.artworkId),
                    sourceScreen: 'spatial_library',
                  ),
          label: l10n.spatialLibraryShare,
          icon: Icons.share_rounded,
          variant: KubusButtonVariant.secondary,
        ),
      );
    }
    if (available.contains(SpatialLibraryAction.deleteRaw)) {
      actions.add(
        KubusButton(
          onPressed: _busy
              ? null
              : () => unawaited(
                  _run(() => provider.deleteRaw(record.localSpatialId))),
          label: l10n.spatialLibraryDeleteRaw,
          icon: Icons.delete_outline_rounded,
          variant: KubusButtonVariant.secondary,
        ),
      );
    }
    if (available.contains(SpatialLibraryAction.deleteProcessed)) {
      actions.add(
        KubusButton(
          onPressed: _busy
              ? null
              : () => unawaited(
                    _run(() => provider.deleteProcessed(record.localSpatialId)),
                  ),
          label: l10n.spatialLibraryDeleteProcessed,
          icon: Icons.delete_sweep_outlined,
          variant: KubusButtonVariant.secondary,
        ),
      );
    }
    actions.add(
      KubusButton(
        onPressed:
            _busy ? null : () => unawaited(_confirmDelete(provider, record)),
        label: l10n.spatialLibraryDeleteRecord,
        icon: Icons.delete_forever_outlined,
        variant: KubusButtonVariant.destructive,
      ),
    );
    return actions;
  }

  Future<void> _chooseProcessor(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final node = context.read<KubusNodeProvider>();
    if (!AppConfig.isFeatureEnabled('availabilityNodes') || !node.isPaired) {
      _showError(l10n.spatialLibraryProcessorUnavailable);
      return;
    }
    List<KubusComputeCandidate> candidates = const <KubusComputeCandidate>[];
    try {
      candidates = await provider.loadNetworkCandidates(record);
    } catch (_) {
      candidates = const <KubusComputeCandidate>[];
    }
    if (!mounted) return;
    final selection = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.spatialProcessTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: KubusSpacing.md),
              KubusButton(
                onPressed: () => Navigator.of(sheetContext).pop('ownNode'),
                label: l10n.spatialProcessLocalTitle,
                icon: Icons.computer_rounded,
                variant: KubusButtonVariant.accent,
                isFullWidth: true,
              ),
              if (candidates.isNotEmpty) ...<Widget>[
                const SizedBox(height: KubusSpacing.sm),
                KubusButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(candidates.first),
                  label: l10n.spatialProcessNetworkTitle,
                  icon: Icons.hub_rounded,
                  variant: KubusButtonVariant.secondary,
                  isFullWidth: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (selection is KubusComputeCandidate) {
      final consent = await showKubusDialog<bool>(
            context: context,
            builder: (dialogContext) => KubusAlertDialog(
              title: Text(l10n.spatialRemotePrivacyTitle),
              content: Text(l10n.spatialRemotePrivacyBody),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.spatialRemotePrivacyConfirm),
                ),
              ],
            ),
          ) ??
          false;
      if (!consent) return;
      await _run(
          () => provider.processWithNetwork(record.localSpatialId, selection));
      return;
    }
    await _run(() => provider.processWithOwnNode(record.localSpatialId));
  }

  Future<void> _confirmDelete(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showKubusDialog<bool>(
          context: context,
          builder: (dialogContext) => KubusAlertDialog(
            title: Text(l10n.spatialLibraryDeleteRecord),
            content: Text(l10n.spatialLibraryDeleteRecordWarning),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.spatialLibraryDeleteRecord),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _run(() => provider.deleteRecord(record.localSpatialId));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        _showError(AppLocalizations.of(context)!.spatialLibraryOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text(message)),
      tone: KubusSnackBarTone.error,
    );
  }
}

String _statusLabel(
  AppLocalizations l10n,
  SpatialLibraryProcessingState state,
) =>
    switch (state) {
      SpatialLibraryProcessingState.capturing ||
      SpatialLibraryProcessingState.capturedPrivate =>
        l10n.spatialLibraryStatusCaptured,
      SpatialLibraryProcessingState.waitingForProcessor =>
        l10n.spatialLibraryStatusWaiting,
      SpatialLibraryProcessingState.uploading =>
        l10n.spatialLibraryStatusUploading,
      SpatialLibraryProcessingState.queued => l10n.spatialLibraryStatusQueued,
      SpatialLibraryProcessingState.processing =>
        l10n.spatialLibraryStatusProcessing,
      SpatialLibraryProcessingState.downloadingResult =>
        l10n.spatialLibraryStatusDownloading,
      SpatialLibraryProcessingState.readyPrivate =>
        l10n.spatialLibraryStatusReady,
      SpatialLibraryProcessingState.publishing ||
      SpatialLibraryProcessingState.published =>
        l10n.spatialLibraryStatusPublished,
      SpatialLibraryProcessingState.failedRetryable =>
        l10n.spatialLibraryStatusFailed,
    };
