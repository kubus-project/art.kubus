import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/spatial/spatial_artwork_thumbnail.dart';
import '../../features/spatial/spatial_capture_target_picker.dart';
import '../../features/spatial/spatial_detail_sections.dart';
import '../../features/spatial/spatial_linked_entities.dart';
import '../../features/spatial/spatial_marker_directory.dart';
import '../../features/spatial/spatial_metadata_sheet.dart';
import '../../features/spatial/spatial_process_sheet.dart';
import '../../features/spatial/spatial_record_actions.dart';
import '../../features/spatial/spatial_record_presentation.dart';
import '../../features/spatial/spatial_status_presentation.dart';
import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../models/kubus_node_models.dart';
import '../../models/spatial_capture_target.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/kubus_node_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../providers/spatial_library_provider.dart';
import '../../services/kubus_node_service.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../services/spatial_library_store.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/kubus_kit.dart';
import '../../widgets/spatial/spatial_viewer.dart';
import '../node/node_pairing_screen.dart';
import 'spatial_capture_launch.dart';

/// The management surface for one capture.
///
/// Structured as sections — what it is linked to, what was captured, what has
/// been done to it, and where it stands publicly — each ending in the action
/// that section actually enables. The single primary action lives at the top,
/// and everything destructive lives behind the overflow, so the screen reads
/// as a task rather than a control panel.
class SpatialLibraryDetailScreen extends StatefulWidget {
  const SpatialLibraryDetailScreen({
    required this.localSpatialId,
    this.viewerNodeService,
    this.markerDirectory,
    super.key,
  });

  final String localSpatialId;

  @visibleForTesting
  final KubusNodeService? viewerNodeService;

  @visibleForTesting
  final SpatialMarkerDirectory? markerDirectory;

  @override
  State<SpatialLibraryDetailScreen> createState() =>
      _SpatialLibraryDetailScreenState();
}

class _SpatialLibraryDetailScreenState
    extends State<SpatialLibraryDetailScreen> {
  bool _busy = false;

  /// The viewer's content future, memoized against the identity of the result
  /// it renders. Rebuilding this on every provider notification — a Node
  /// status poll, an unrelated record changing — tore down and re-created the
  /// whole 3D surface while the user was looking at it.
  Future<SpatialContent>? _contentFuture;
  String? _contentKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<SpatialLibraryProvider>();
    final record = provider.recordFor(widget.localSpatialId);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.spatialLibraryTitle)),
        body: Center(
          child: EmptyStateCard(
            icon: Icons.view_in_ar_outlined,
            title: l10n.spatialLibraryTitle,
            description: l10n.spatialLibraryEmpty,
          ),
        ),
      );
    }

    final artwork = context.select<ArtworkProvider, Artwork?>(
      (p) => p.getArtworkById(record.artworkId),
    );
    final directory = widget.markerDirectory ??
        SpatialMarkerDirectory(
          management: context.read<MarkerManagementProvider?>(),
        );
    final ArtMarker? marker = (record.markerId ?? '').isEmpty
        ? null
        : directory.resolve(record.markerId);
    final display = SpatialRecordDisplay.resolve(
      l10n,
      record,
      artwork: artwork,
      marker: marker,
    );
    final actions = SpatialRecordActions.of(record);
    final lineage = provider.lineageOf(record);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(display.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (actions.overflow.isNotEmpty)
            IconButton(
              tooltip: l10n.spatialLibraryMoreActions,
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: _busy
                  ? null
                  : () => unawaited(
                        _showOverflow(provider, record, actions.overflow),
                      ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(KubusSpacing.md),
        children: <Widget>[
          _Hero(record: record, display: display, artwork: artwork),
          if (record.hasLocalResult) ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            _viewer(context, provider, record, l10n),
          ],
          if (actions.primary != null) ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            _primaryButton(context, provider, record, actions.primary!),
          ],
          const SizedBox(height: KubusSpacing.md),
          SpatialLinkedEntities(
            display: display,
            artworkId: record.artworkId,
            artwork: artwork,
            marker: marker,
          ),
          const SizedBox(height: KubusSpacing.md),
          SpatialDetailSection(
            title: l10n.spatialLibrarySectionCapture,
            children: <Widget>[
              SpatialCaptureQuality(record: record),
              ..._sectionActions(context, provider, record,
                  actions, const <SpatialLibraryAction>[
                SpatialLibraryAction.continueCapture,
                SpatialLibraryAction.newRevision,
                SpatialLibraryAction.editAssociation,
                SpatialLibraryAction.editMetadata,
              ]),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          SpatialDetailSection(
            title: l10n.spatialLibrarySectionProcessing,
            children: <Widget>[
              SpatialProcessingStatus(record: record),
              ..._sectionActions(context, provider, record,
                  actions, const <SpatialLibraryAction>[
                SpatialLibraryAction.process,
                SpatialLibraryAction.retryProcessing,
                SpatialLibraryAction.changeProcessor,
                SpatialLibraryAction.cancelProcessingRequest,
              ]),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          SpatialDetailSection(
            title: l10n.spatialLibrarySectionArchive,
            children: <Widget>[
              _archiveSummary(context, record, l10n),
              ..._sectionActions(context, provider, record,
                  actions, const <SpatialLibraryAction>[
                SpatialLibraryAction.publish,
                SpatialLibraryAction.viewPublicArchive,
                SpatialLibraryAction.share,
                // `viewResult` is deliberately absent: the scene is rendered
                // above, so a button for it would do nothing visible.
              ]),
            ],
          ),
          if (lineage.length > 1) ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            _VersionHistory(lineage: lineage, current: record),
          ],
          const SizedBox(height: KubusSpacing.xl),
        ],
      ),
    );
  }

  Widget _viewer(
    BuildContext context,
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
    AppLocalizations l10n,
  ) {
    // The identity of the *result*, not of the record: only a new result is a
    // reason to reload the scene.
    final key = '${record.localSpatialId}:'
        '${record.resultManifestCid ?? record.resultManifestPath ?? ''}';
    if (_contentKey != key) {
      _contentKey = key;
      _contentFuture = provider.loadLocalContent(record.localSpatialId);
    }
    return SizedBox(
      height: KubusSizes.detailPreviewHeight,
      child: FutureBuilder<SpatialContent>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return SpatialViewer(
              key: ValueKey<String>(key),
              content: snapshot.data!,
              nodeService: widget.viewerNodeService ??
                  context.read<KubusNodeProvider>().service,
            );
          }
          if (snapshot.hasError) {
            return EmptyStateCard(
              icon: Icons.broken_image_outlined,
              title: l10n.spatialViewerUnavailable,
              description: l10n.spatialLibraryOperationFailed,
            );
          }
          return const Center(child: InlineLoading(width: 72, height: 72));
        },
      ),
    );
  }

  Widget _archiveSummary(
    BuildContext context,
    SpatialLibraryRecord record,
    AppLocalizations l10n,
  ) {
    final publication = SpatialStatusPresentation.forPublication(l10n, record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        KubusBadge(
          text: publication.label,
          icon: publication.icon,
          variant: KubusBadgeVariant.status,
          accent: publication.accent(context),
        ),
        const SizedBox(height: KubusSpacing.sm),
        if (record.resultBytes > 0)
          SpatialDetailMetric(
            label: l10n.spatialLibraryProcessedStorage,
            value: NodeStatePresentation.formatBytes(record.resultBytes),
          ),
        if (record.publishedAt != null)
          SpatialDetailMetric(
            label: l10n.spatialLibraryStatusPublished,
            value: MaterialLocalizations.of(context)
                .formatMediumDate(record.publishedAt!.toLocal()),
          ),
      ],
    );
  }

  List<Widget> _sectionActions(
    BuildContext context,
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
    SpatialRecordActions actions,
    List<SpatialLibraryAction> wanted,
  ) {
    final available =
        wanted.where(actions.secondary.contains).toList(growable: false);
    if (available.isEmpty) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: KubusSpacing.sm),
      for (final action in available)
        Padding(
          padding: const EdgeInsets.only(top: KubusSpacing.xs),
          child: KubusButton(
            onPressed:
                _busy ? null : () => _invoke(context, provider, record, action),
            label: _label(AppLocalizations.of(context)!, action),
            icon: _icon(action),
            variant: KubusButtonVariant.secondary,
            isFullWidth: true,
          ),
        ),
    ];
  }

  Widget _primaryButton(
    BuildContext context,
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
    SpatialLibraryAction action,
  ) =>
      KubusButton(
        onPressed:
            _busy ? null : () => _invoke(context, provider, record, action),
        label: _label(AppLocalizations.of(context)!, action),
        icon: _icon(action),
        variant: KubusButtonVariant.accent,
        isFullWidth: true,
        isLoading: _busy,
      );

  Future<void> _showOverflow(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
    List<SpatialLibraryAction> overflow,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final choice = await showModalBottomSheet<SpatialLibraryAction>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(KubusSpacing.md),
              child: Row(
                children: <Widget>[
                  Text(
                    l10n.spatialLibraryStorageTitle,
                    style: KubusTextStyles.sheetTitle,
                  ),
                ],
              ),
            ),
            for (final action in overflow)
              ListTile(
                leading: Icon(_icon(action), color: roles.negativeAction),
                title: Text(_label(l10n, action)),
                onTap: () => Navigator.of(sheetContext).pop(action),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    await _invoke(context, provider, record, choice);
  }

  Future<void> _invoke(
    BuildContext context,
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
    SpatialLibraryAction action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case SpatialLibraryAction.continueCapture:
        await _continueCapture(record);
      case SpatialLibraryAction.newRevision:
        await _createRevision(provider, record);
      case SpatialLibraryAction.editAssociation:
        await _editAssociation(provider, record);
      case SpatialLibraryAction.editMetadata:
        await _editMetadata(provider, record);
      case SpatialLibraryAction.process:
      case SpatialLibraryAction.retryProcessing:
      case SpatialLibraryAction.changeProcessor:
        await _chooseProcessor(provider, record);
      case SpatialLibraryAction.cancelProcessingRequest:
        await _run(() => provider.cancelNetworkRequest(record.localSpatialId));
      case SpatialLibraryAction.viewResult:
        // The scene is already rendered at the top of this screen.
        break;
      case SpatialLibraryAction.viewPublicArchive:
        // The public archive lives on the artwork, with its full version
        // history, rather than being duplicated here.
        await openArtwork(context, record.artworkId, source: 'spatial_library');
      case SpatialLibraryAction.publish:
        await _run(() => provider.publish(record.localSpatialId));
      case SpatialLibraryAction.share:
        ShareService().showShareSheet(
          context,
          target: ShareTarget.artwork(artworkId: record.artworkId),
          sourceScreen: 'spatial_library',
        );
      case SpatialLibraryAction.deleteRaw:
        await _run(() => provider.deleteRaw(record.localSpatialId));
      case SpatialLibraryAction.deleteProcessed:
        await _run(() => provider.deleteProcessed(record.localSpatialId));
      case SpatialLibraryAction.deleteLocalRecord:
        await _confirmDeleteRecord(provider, record, l10n);
    }
  }

  Future<void> _continueCapture(SpatialLibraryRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    if (!record.rawPresent) {
      _showError(l10n.spatialCaptureSourceUnavailable);
      return;
    }
    await openArSpatialCapture(
      context,
      SpatialCaptureLaunchRequest.continueCapture(
        localSpatialId: record.localSpatialId,
        target: SpatialCaptureTarget(
          artworkId: record.artworkId,
          markerId: record.markerId,
          artworkTitleSnapshot: record.artworkTitleSnapshot,
          artistNameSnapshot: record.artistNameSnapshot,
          markerLabelSnapshot: record.markerLabelSnapshot,
        ),
      ),
    );
  }

  Future<void> _createRevision(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
  ) async {
    final created = await _run(
      () => provider.createRevision(record.localSpatialId),
    );
    if (!mounted || created is! SpatialLibraryRecord) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SpatialLibraryDetailScreen(
          localSpatialId: created.localSpatialId,
          viewerNodeService: widget.viewerNodeService,
          markerDirectory: widget.markerDirectory,
        ),
      ),
    );
  }

  Future<void> _editAssociation(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (record.hasLocalResult) {
      final proceed = await showKubusDialog<bool>(
            context: context,
            builder: (dialogContext) => KubusAlertDialog(
              title: Text(l10n.spatialEditAssociationTitle),
              content: Text(l10n.spatialEditAssociationProcessedWarning),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.spatialEditAssociationConfirm),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted || !proceed) return;
    }
    final target = await SpatialCaptureTargetPicker.show(
      context,
      initialArtworkId: record.artworkId,
    );
    if (!mounted || target == null) return;
    await _run(
      () => provider.updateAssociation(record.localSpatialId, target),
    );
  }

  Future<void> _editMetadata(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final artwork = context.read<ArtworkProvider>().getArtworkById(
          record.artworkId,
        );
    final fallback = artwork?.title.trim().isNotEmpty == true
        ? artwork!.title
        : record.artworkTitleSnapshot ?? l10n.spatialLibraryTitle;
    final edit = await SpatialMetadataSheet.show(
      context,
      initialDisplayName: record.displayName,
      initialNote: record.note,
      fallbackName: fallback,
    );
    if (!mounted || edit == null) return;
    await _run(
      () => provider.updateMetadata(
        record.localSpatialId,
        displayName: edit.displayName,
        note: edit.note,
      ),
    );
  }

  Future<void> _chooseProcessor(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // Discovery is informational only. It decides what the sheet *says*, never
    // what it offers. The KUBUS Network is reachable regardless of whether
    // this device has a Node of its own paired — owning a Node is never the
    // gate on processing.
    var providersAvailableNow = false;
    try {
      providersAvailableNow =
          (await provider.loadNetworkCandidates(record)).isNotEmpty;
    } catch (_) {
      providersAvailableNow = false;
    }
    if (!mounted) return;
    final choice = await SpatialProcessSheet.show(
      context,
      ownNode: provider.ownNodeReachability,
      providersAvailableNow: providersAvailableNow,
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case SpatialProcessorChoice.connectOwnNode:
        // Pairing is reachable from the point of need — not a detour through
        // Settings. On success, drop straight back into the same processing
        // flow with the Node's freshly paired state already reflected.
        final paired = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const NodePairingScreen()),
        );
        if (!mounted || paired != true) return;
        await _chooseProcessor(provider, record);
      case SpatialProcessorChoice.ownNode:
        // The user's own Node needs no third-party privacy consent: the data
        // never leaves their own hardware.
        await _run(() => provider.processWithOwnNode(record.localSpatialId));
      case SpatialProcessorChoice.kubusNetwork:
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
        if (!mounted || !consent) return;
        await _run(
          () => provider.requestNetworkProcessing(record.localSpatialId),
        );
    }
  }

  Future<void> _confirmDeleteRecord(
    SpatialLibraryProvider provider,
    SpatialLibraryRecord record,
    AppLocalizations l10n,
  ) async {
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
    if (!mounted || !confirmed) return;
    await _run(() => provider.deleteRecord(record.localSpatialId));
    if (mounted) Navigator.of(context).pop();
  }

  Future<Object?> _run(Future<Object?> Function() action) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await action();
    } catch (_) {
      if (mounted) {
        _showError(AppLocalizations.of(context)!.spatialLibraryOperationFailed);
      }
      return null;
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

  static String _label(AppLocalizations l10n, SpatialLibraryAction action) =>
      switch (action) {
        SpatialLibraryAction.continueCapture =>
          l10n.spatialLibraryContinueCapture,
        SpatialLibraryAction.newRevision => l10n.spatialLibraryNewRevision,
        SpatialLibraryAction.editAssociation =>
          l10n.spatialLibraryEditAssociation,
        SpatialLibraryAction.editMetadata => l10n.spatialLibraryEditMetadata,
        SpatialLibraryAction.process => l10n.spatialLibraryProcessScene,
        SpatialLibraryAction.cancelProcessingRequest =>
          l10n.spatialLibraryCancelRequest,
        SpatialLibraryAction.retryProcessing =>
          l10n.spatialLibraryRetryProcessing,
        SpatialLibraryAction.changeProcessor =>
          l10n.spatialLibraryChangeProcessor,
        SpatialLibraryAction.viewResult => l10n.spatialLibraryViewResult,
        SpatialLibraryAction.publish => l10n.spatialLibraryPublish,
        SpatialLibraryAction.viewPublicArchive =>
          l10n.spatialLibraryViewPublicArchive,
        SpatialLibraryAction.share => l10n.spatialLibraryShare,
        SpatialLibraryAction.deleteRaw => l10n.spatialLibraryDeleteRaw,
        SpatialLibraryAction.deleteProcessed =>
          l10n.spatialLibraryDeleteProcessed,
        SpatialLibraryAction.deleteLocalRecord =>
          l10n.spatialLibraryDeleteRecord,
      };

  static IconData _icon(SpatialLibraryAction action) => switch (action) {
        SpatialLibraryAction.continueCapture => Icons.center_focus_strong,
        SpatialLibraryAction.newRevision => Icons.layers_outlined,
        SpatialLibraryAction.editAssociation => Icons.link_rounded,
        SpatialLibraryAction.editMetadata => Icons.edit_outlined,
        SpatialLibraryAction.process => Icons.memory_rounded,
        SpatialLibraryAction.cancelProcessingRequest => Icons.cancel_outlined,
        SpatialLibraryAction.retryProcessing => Icons.refresh_rounded,
        SpatialLibraryAction.changeProcessor => Icons.swap_horiz_rounded,
        SpatialLibraryAction.viewResult => Icons.threed_rotation_rounded,
        SpatialLibraryAction.publish => Icons.public_rounded,
        SpatialLibraryAction.viewPublicArchive => Icons.travel_explore_rounded,
        SpatialLibraryAction.share => Icons.share_rounded,
        SpatialLibraryAction.deleteRaw => Icons.delete_outline_rounded,
        SpatialLibraryAction.deleteProcessed => Icons.delete_sweep_outlined,
        SpatialLibraryAction.deleteLocalRecord => Icons.delete_forever_outlined,
      };
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.record,
    required this.display,
    required this.artwork,
  });

  final SpatialLibraryRecord record;
  final SpatialRecordDisplay display;
  final Artwork? artwork;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final status = SpatialStatusPresentation.forRecord(l10n, record);
    final publication = SpatialStatusPresentation.forPublication(l10n, record);
    return KubusCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpatialArtworkThumbnail(
            capturePath: display.thumbnailPath,
            artwork: artwork,
            semanticLabel: display.artworkLabel,
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  display.title,
                  maxLines: 3,
                  style: KubusTextStyles.detailCardTitle,
                ),
                if (display.subtitle != null) ...<Widget>[
                  const SizedBox(height: KubusSpacing.xxs),
                  Text(
                    display.subtitle!,
                    maxLines: 2,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (record.note != null) ...<Widget>[
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    record.note!,
                    maxLines: 3,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: KubusSpacing.sm),
                Wrap(
                  spacing: KubusSpacing.xs,
                  runSpacing: KubusSpacing.xs,
                  children: <Widget>[
                    KubusBadge(
                      text: status.label,
                      icon: status.icon,
                      variant: KubusBadgeVariant.status,
                      accent: status.accent(context),
                      compact: true,
                    ),
                    KubusBadge(
                      text: publication.label,
                      icon: publication.icon,
                      variant: KubusBadgeVariant.status,
                      accent: publication.accent(context),
                      compact: true,
                    ),
                    if (record.revision > 1)
                      KubusBadge(
                        text: l10n.spatialLibraryRevisionOf(record.revision),
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionHistory extends StatelessWidget {
  const _VersionHistory({required this.lineage, required this.current});

  final List<SpatialLibraryRecord> lineage;
  final SpatialLibraryRecord current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final publicCurrent = lineage.lastWhere(
      (item) => item.isPublished,
      orElse: () => lineage.first,
    );
    return SpatialDetailSection(
      title: l10n.spatialLibraryVersionsTitle,
      children: <Widget>[
        if (publicCurrent.isPublished && publicCurrent.version != null)
          SpatialDetailMetric(
            label: l10n.spatialLibraryCurrentPublicVersion,
            value: l10n.spatialLibraryVersionLabel(publicCurrent.version!),
          ),
        const SizedBox(height: KubusSpacing.xs),
        for (final item in lineage.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
            child: Row(
              children: <Widget>[
                Icon(
                  item.isPublished
                      ? Icons.public_rounded
                      : Icons.edit_note_rounded,
                  size: KubusSizes.trailingChevron,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.spatialLibraryRevisionOf(item.revision),
                    style: KubusTextStyles.detailBody.copyWith(
                      fontWeight: item.localSpatialId == current.localSpatialId
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  item.isPublished
                      ? l10n.spatialLibraryStatusPublished
                      : l10n.spatialLibraryLocalDraft,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
