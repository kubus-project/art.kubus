import 'dart:async';

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
import '../../services/spatial_library_store.dart';
import '../../screens/spatial/spatial_capture_launch.dart';
import '../../screens/spatial/spatial_library_detail_screen.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_reading_surface.dart';
import '../kubus_button.dart';
import '../../utils/kubus_color_roles.dart';
import 'spatial_viewer.dart';

/// The artwork's spatial presence, on the artwork's own screen.
///
/// Spatial content that only exists inside the Spatial Library is a service,
/// not a feature. This is where it becomes part of the artwork: the published
/// archive and its history, the owner's own unpublished drafts, and the one
/// action that continues the archive rather than starting a parallel one.
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

    if (!hasPublic && knownCount == 0 && drafts.isEmpty && !canCapture) {
      return const SizedBox.shrink();
    }

    if (!hasPublic && knownCount > 0 && error != null && drafts.isEmpty) {
      return KubusReadingSurface(
        child: Row(
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
        ),
      );
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
          if (hasPublic) ...<Widget>[
            const SizedBox(height: KubusSpacing.sm),
            _PublicArchiveSummary(history: history),
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
    ).resolve(widget.artwork.arMarkerId);
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

  Future<void> _openArchive(
    BuildContext context,
    ArtworkSpatialHistory history,
  ) =>
      showDialog<void>(
        context: context,
        builder: (_) => _SpatialArchiveDialog(history: history),
      );
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
