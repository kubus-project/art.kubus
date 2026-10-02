import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../models/spatial_capture_target.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../widgets/kubus_kit.dart';
import 'spatial_artwork_thumbnail.dart';
import 'spatial_marker_directory.dart';

/// Asks the user which artwork a spatial capture belongs to.
///
/// This exists because there is no defensible fallback. A capture filed under
/// "whichever artwork the provider happened to list first" is worse than no
/// capture: it silently attributes someone's scan to unrelated work, and the
/// mistake only surfaces long after the raw source is gone. So the target is
/// always an explicit answer to an explicit question.
class SpatialCaptureTargetPicker extends StatefulWidget {
  const SpatialCaptureTargetPicker({
    super.key,
    this.artworks,
    this.markerDirectory,
    this.initialArtworkId,
  });

  /// Injectable for tests. Null reads the live [ArtworkProvider].
  final List<Artwork>? artworks;

  /// Injectable for tests. Null builds one from the live providers.
  final SpatialMarkerDirectory? markerDirectory;

  /// Preselects an artwork when the picker is opened to change an existing
  /// association rather than to start from nothing.
  final String? initialArtworkId;

  /// Opens the picker and returns the chosen target, or null if dismissed.
  static Future<SpatialCaptureTarget?> show(
    BuildContext context, {
    List<Artwork>? artworks,
    SpatialMarkerDirectory? markerDirectory,
    String? initialArtworkId,
  }) =>
      showModalBottomSheet<SpatialCaptureTarget>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SpatialCaptureTargetPicker(
          artworks: artworks,
          markerDirectory: markerDirectory,
          initialArtworkId: initialArtworkId,
        ),
      );

  @override
  State<SpatialCaptureTargetPicker> createState() =>
      _SpatialCaptureTargetPickerState();
}

class _SpatialCaptureTargetPickerState
    extends State<SpatialCaptureTargetPicker> {
  final TextEditingController _search = TextEditingController();
  Artwork? _artwork;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final next = _search.text.trim();
      if (next == _query) return;
      setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Artwork> get _allArtworks =>
      widget.artworks ?? context.read<ArtworkProvider>().artworks;

  SpatialMarkerDirectory get _directory =>
      widget.markerDirectory ??
      SpatialMarkerDirectory(
        management: context.read<MarkerManagementProvider?>(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final artwork = _artwork;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: artwork == null
            ? _buildArtworkStep(context, l10n)
            : _buildMarkerStep(context, l10n, artwork),
      ),
    );
  }

  Widget _buildArtworkStep(BuildContext context, AppLocalizations l10n) {
    final query = _query.toLowerCase();
    final matches = _allArtworks.where((artwork) {
      if (query.isEmpty) return true;
      return artwork.title.toLowerCase().contains(query) ||
          artwork.artist.toLowerCase().contains(query);
    }).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SheetHeading(
          title: l10n.spatialTargetPickerTitle,
          subtitle: l10n.spatialTargetPickerSubtitle,
        ),
        const SizedBox(height: KubusSpacing.md),
        KubusSearchBar(
          controller: _search,
          hintText: l10n.spatialTargetSearchHint,
        ),
        const SizedBox(height: KubusSpacing.md),
        if (_allArtworks.isEmpty)
          EmptyStateCard(
            icon: Icons.image_not_supported_outlined,
            title: l10n.spatialTargetNoArtworksTitle,
            description: l10n.spatialTargetNoArtworksBody,
          )
        else if (matches.isEmpty)
          EmptyStateCard(
            icon: Icons.search_off_rounded,
            title: l10n.spatialTargetNoResultsTitle,
            description: l10n.spatialTargetNoResultsBody,
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: matches.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: KubusSpacing.sm),
              itemBuilder: (context, index) {
                final artwork = matches[index];
                return _ArtworkRow(
                  artwork: artwork,
                  selected: artwork.id == widget.initialArtworkId,
                  onTap: () => _chooseArtwork(context, artwork),
                );
              },
            ),
          ),
      ],
    );
  }

  void _chooseArtwork(BuildContext context, Artwork artwork) {
    final candidates = _directory.candidatesFor(artwork);
    if (candidates.isEmpty) {
      // Nothing to choose between: an extra step that offers one option is
      // friction, not clarity.
      Navigator.of(context).pop(SpatialCaptureTarget.fromArtwork(artwork));
      return;
    }
    setState(() => _artwork = artwork);
  }

  Widget _buildMarkerStep(
    BuildContext context,
    AppLocalizations l10n,
    Artwork artwork,
  ) {
    final candidates = _directory.candidatesFor(artwork);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SheetHeading(
          title: l10n.spatialTargetMarkerTitle,
          subtitle: l10n.spatialTargetMarkerSubtitle,
        ),
        const SizedBox(height: KubusSpacing.sm),
        _ArtworkRow(artwork: artwork, selected: true, onTap: null),
        const SizedBox(height: KubusSpacing.sm),
        TextButton.icon(
          onPressed: () => setState(() => _artwork = null),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: Text(l10n.spatialTargetChangeArtwork),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final marker in candidates) ...<Widget>[
                _MarkerRow(
                  marker: marker,
                  onTap: () => Navigator.of(context).pop(
                    SpatialCaptureTarget.fromArtwork(artwork, marker: marker),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
              ],
              // Explicit, never implicit: "no marker" is a choice the user
              // makes, not what happens when they do not answer.
              KubusCard(
                onTap: () => Navigator.of(context)
                    .pop(SpatialCaptureTarget.fromArtwork(artwork)),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.not_listed_location_outlined),
                    const SizedBox(width: KubusSpacing.md),
                    Expanded(child: Text(l10n.spatialTargetNoMarker)),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: KubusSizes.trailingChevron,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: KubusTextStyles.sheetTitle),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          subtitle,
          style: KubusTextStyles.sheetSubtitle.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ArtworkRow extends StatelessWidget {
  const _ArtworkRow({
    required this.artwork,
    required this.selected,
    required this.onTap,
  });

  final Artwork artwork;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    return KubusCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          SpatialArtworkThumbnail(
            artwork: artwork,
            size: KubusSizes.compactThumbnail,
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  artwork.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailCardTitle,
                ),
                const SizedBox(height: KubusSpacing.xxs),
                Text(
                  artwork.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: roles.positiveAction)
          else if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: KubusSizes.trailingChevron,
            ),
        ],
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.marker, required this.onTap});

  final ArtMarker marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final geographic = markerHasMapLocation(marker);
    return KubusCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(
            geographic ? Icons.place_outlined : Icons.qr_code_2_rounded,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  marker.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailCardTitle,
                ),
                const SizedBox(height: KubusSpacing.xxs),
                Text(
                  geographic
                      ? l10n.spatialMarkerKindLocation
                      : l10n.spatialMarkerKindConfiguration,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: KubusSizes.trailingChevron,
          ),
        ],
      ),
    );
  }
}
