import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../features/spatial/spatial_marker_directory.dart';
import '../../features/spatial/spatial_record_card.dart';
import '../../l10n/app_localizations.dart';
import '../../models/artwork.dart';
import '../../models/kubus_node_models.dart';
import '../../models/spatial_capture_target.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/kubus_node_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/spatial_library_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/spatial_library_store.dart';
import '../inline_loading.dart';
import '../../screens/spatial/artwork_spatial_upload_screen.dart';
import '../../screens/spatial/spatial_capture_launch.dart';
import '../../screens/spatial/spatial_library_detail_screen.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../common/kubus_reading_surface.dart';
import '../kubus_button.dart';
import '../../utils/kubus_color_roles.dart';
import 'spatial_lazy_reveal.dart';
import 'spatial_viewer.dart';

/// The artwork's spatial presence, on the artwork's own screen.
///
/// Spatial content that only exists inside the Spatial Library is a service,
/// not a feature. This is where it becomes part of the artwork: the published
/// archive and its history, the owner's own unpublished drafts, and the one
/// action that continues the archive rather than starting a parallel one.
class ArtworkSpatialArchiveSection extends StatefulWidget {
  const ArtworkSpatialArchiveSection({
    required this.artwork,
    this.contextMarkerId,
    super.key,
  });

  final Artwork artwork;

  /// The marker this screen was opened from, when it was opened from one.
  ///
  /// Preferred over the artwork's own AR marker so a capture launched from a
  /// specific map pin is filed against that pin, not against whichever marker
  /// the artwork happens to name.
  final String? contextMarkerId;

  @override
  State<ArtworkSpatialArchiveSection> createState() =>
      _ArtworkSpatialArchiveSectionState();
}

class _ArtworkSpatialArchiveSectionState
    extends State<ArtworkSpatialArchiveSection> {
  /// While the fullscreen dialog is open the inline viewer is unmounted, so a
  /// page never holds two WebGL contexts (and two downloads) for one piece.
  bool _dialogOpen = false;
  (String, int)? _uploadCheck;
  bool _canUpload = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb) {
      _checkUploadAccess(
          context.watch<ProfileProvider?>()?.isSignedIn ?? false);
    }
  }

  void _checkUploadAccess(bool signedIn) {
    final api = BackendApiService();
    final check = signedIn ? (widget.artwork.id, api.authSessionEpoch) : null;
    if (_uploadCheck == check) return;
    _uploadCheck = check;
    _canUpload = false;
    if (check == null) return;
    unawaited(_loadUploadAccess(api, check));
  }

  Future<void> _loadUploadAccess(
    BackendApiService api,
    (String, int) check,
  ) async {
    try {
      await api.getSpatialUploadDraft(check.$1);
    } on Exception {
      return;
    }
    if (!mounted || _uploadCheck != check || api.authSessionEpoch != check.$2) {
      return;
    }
    setState(() => _canUpload = true);
  }

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
    if (kIsWeb) {
      _checkUploadAccess(context.read<ProfileProvider?>()?.isSignedIn ?? false);
    }
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
    final l10n = AppLocalizations.of(context)!;

    // Drafts are resolved from each record's own artworkId, and shown only on
    // the device that holds them: a private capture is not part of the public
    // record until its owner publishes it.
    final drafts = (context
                .watch<SpatialLibraryProvider?>()
                ?.recordsForArtwork(widget.artwork.id) ??
            const <SpatialLibraryRecord>[])
        .where((record) => !record.isPublished)
        .toList(growable: false);

    final hasPublic = history != null && history.history.isNotEmpty;
    final canCapture = _canCapture(context);

    if (!hasPublic &&
        knownCount == 0 &&
        drafts.isEmpty &&
        !canCapture &&
        !_canUpload &&
        history == null) {
      return const SizedBox.shrink();
    }

    final showHistoryError =
        !hasPublic && knownCount > 0 && error != null && drafts.isEmpty;
    final historyError = showHistoryError
        ? Row(
            children: <Widget>[
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
          )
        : null;
    if (historyError != null && !_canUpload) {
      return KubusReadingSurface(child: historyError);
    }

    return KubusReadingSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.view_in_ar_outlined),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Text(
                  l10n.spatialArchiveTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (hasPublic)
                Text(l10n.spatialCaptureCount(history.history.length)),
            ],
          ),
          if (historyError != null) historyError,
          if (!hasPublic && history != null && knownCount == 0) ...<Widget>[
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.subjectSpatialArchiveEmpty,
              style: KubusTextStyles.bodySmall.copyWith(
                color: KubusColorRoles.of(context).foregroundMuted,
              ),
            ),
          ],
          if (!hasPublic && provider.isSpatialHistoryLoading(widget.artwork.id))
            const Padding(
              padding: EdgeInsets.only(top: KubusSpacing.sm),
              child: InlineLoading(height: 2, tileSize: 1),
            ),
          if (hasPublic) ...<Widget>[
            const SizedBox(height: KubusSpacing.sm),
            _PublicArchiveSummary(history: history),
            if (kIsWeb) ...<Widget>[
              const SizedBox(height: KubusSpacing.md),
              _InlineArchiveViewer(
                key: const ValueKey<String>('spatial-inline-viewer'),
                content: history.current!.content,
                suspended: _dialogOpen,
                posterUrl: _posterUrl,
              ),
            ],
            const SizedBox(height: KubusSpacing.md),
            FilledButton.icon(
              onPressed: () => _openArchive(context, history),
              icon: const Icon(Icons.threed_rotation_rounded),
              label: Text(l10n.spatialViewIn3d),
            ),
          ],
          if (drafts.isNotEmpty) ...<Widget>[
            const SizedBox(height: KubusSpacing.lg),
            Text(
              l10n.spatialArtworkDraftsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: KubusSpacing.xxs),
            Text(
              l10n.spatialArtworkDraftsSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            for (final record in drafts) ...<Widget>[
              SpatialRecordCard(
                key: ValueKey<String>(record.localSpatialId),
                record: record,
                artworkOverride: widget.artwork,
                markerDirectory: SpatialMarkerDirectory(
                  management: context.read<MarkerManagementProvider?>(),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SpatialLibraryDetailScreen(
                      localSpatialId: record.localSpatialId,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KubusSpacing.sm),
            ],
          ],
          if (_canUpload &&
              widget.artwork.id ==
                  ArtworkSpatialUploadScreen.pilotArtworkId) ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            KubusButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ArtworkSpatialUploadScreen(
                    artworkId: widget.artwork.id,
                    posterUrl: _posterUrl,
                  ),
                ),
              ),
              label: l10n.spatialDraftUploadTitle,
              icon: Icons.upload_file_outlined,
              variant: KubusButtonVariant.secondary,
              isFullWidth: true,
            ),
          ],
          if (canCapture) ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            KubusButton(
              onPressed: () => unawaited(_startCapture(context, hasPublic)),
              // Continuing a public archive is a different intent from making
              // the first one, and the label says which.
              label: hasPublic
                  ? l10n.spatialArtworkAddUpdate
                  : l10n.spatialArtworkCaptureCta,
              icon: Icons.center_focus_strong,
              variant: KubusButtonVariant.secondary,
              isFullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  /// Whether this viewer may capture spatial data for this artwork.
  ///
  /// No profile means no permission, which is also the right answer when the
  /// section renders somewhere the profile graph is not mounted.
  bool _canCapture(BuildContext context) {
    if (!AppConfig.isFeatureEnabled('availabilityNodes')) return false;
    final profile = context.watch<ProfileProvider?>()?.currentUser;
    if (profile == null) return false;
    return profile.isArtist || profile.isInstitution;
  }

  /// Opens AR with this artwork already chosen.
  ///
  /// The target travels with the navigation, so the capture that comes back
  /// is filed under the artwork the user was actually looking at.
  Future<void> _startCapture(BuildContext context, bool hasPublic) async {
    final marker = SpatialMarkerDirectory(
      management: context.read<MarkerManagementProvider?>(),
    ).resolve(widget.contextMarkerId ?? widget.artwork.arMarkerId);
    await openArSpatialCapture(
      context,
      SpatialCaptureLaunchRequest.newCapture(
        target: SpatialCaptureTarget.fromArtwork(
          widget.artwork,
          marker: marker,
        ),
      ),
    );
  }

  /// The artwork's cover, shown where the viewer cannot show the model.
  String? get _posterUrl =>
      MediaUrlResolver.resolveDisplayUrl(widget.artwork.imageUrl);

  Future<void> _openArchive(
    BuildContext context,
    ArtworkSpatialHistory history,
  ) async {
    setState(() => _dialogOpen = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _SpatialArchiveDialog(history: history, posterUrl: _posterUrl),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }
}

/// The viewer inline on the artwork screen (web).
///
/// Created when it scrolls into view, not on page load. Its height follows the
/// available width so it reads the same in the desktop column and on a phone.
class _InlineArchiveViewer extends StatelessWidget {
  const _InlineArchiveViewer({
    required this.content,
    required this.suspended,
    this.posterUrl,
    super.key,
  });

  final SpatialContent content;
  final bool suspended;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nodeService = context.read<KubusNodeProvider>().service;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth ? constraints.maxWidth : 640.0;
        final height = (width * 0.75).clamp(260.0, 460.0);
        // The live viewer is its canvas plus a 36 px control row. The stand-in
        // that replaces it while the fullscreen dialog is open has the same
        // total height, so the page does not jump when the dialog opens/closes.
        final liveHeight = height + 36;
        final placeholder = ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.view_in_ar_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: suspended
              ? SizedBox(height: liveHeight, child: placeholder)
              : SpatialLazyReveal(
                  height: liveHeight,
                  placeholder: placeholder,
                  child: SpatialViewer(
                    key: ValueKey<String>('inline-${content.id}'),
                    content: content,
                    nodeService: nodeService,
                    posterUrl: posterUrl,
                  ),
                ),
        );
      },
    );
  }
}

/// The public archive's current version and when it was captured.
class _PublicArchiveSummary extends StatelessWidget {
  const _PublicArchiveSummary({required this.history});

  final ArtworkSpatialHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final current = history.current!;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(current.capturedAt.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.public_rounded, color: roles.positiveAction, size: 18),
            const SizedBox(width: KubusSpacing.xs),
            Text(
              l10n.spatialLibraryCurrentPublicVersion,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            Text(
              l10n.spatialLibraryVersionLabel(current.version),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          l10n.spatialCapturedOn(date),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _SpatialArchiveDialog extends StatefulWidget {
  const _SpatialArchiveDialog({required this.history, this.posterUrl});

  final ArtworkSpatialHistory history;
  final String? posterUrl;

  @override
  State<_SpatialArchiveDialog> createState() => _SpatialArchiveDialogState();
}

class _SpatialArchiveDialogState extends State<_SpatialArchiveDialog> {
  late ArtworkSpatialCapture selected = widget.history.current!;

  /// Escape inside the web viewer closes this dialog, and only this dialog:
  /// while another route (the archive-consent prompt) is above it, it is not
  /// the current route and the key is ignored.
  void _closeOnEscape() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).maybePop();
    }
  }

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
                    posterUrl: widget.posterUrl,
                    onEscape: _closeOnEscape,
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
                                  l10n.spatialLibraryVersionLabel(
                                    capture.version,
                                  ),
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
