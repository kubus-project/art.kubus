import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../features/map/detail/marker_info_detail_presentation.dart';
import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../models/event.dart';
import '../../models/exhibition.dart';
import '../../providers/themeprovider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/common/kubus_cached_image.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/map/panels/marker_info_detail_view.dart';

/// Mobile full-detail page for a map marker whose canonical linked entity is
/// absent, orphaned, or unreachable.
///
/// Mirrors the desktop [MarkerInfoDetailPanel] section-for-section (both render
/// [MarkerInfoDetailSections]) so mobile and desktop present the same marker
/// information. Replaces the obsolete marker-info alert dialog.
class MarkerInfoDetailScreen extends StatelessWidget {
  const MarkerInfoDetailScreen({
    super.key,
    required this.marker,
    this.artwork,
    this.event,
    this.exhibition,
    this.distanceLabel,
    this.linkedSubjectUnavailable = true,
    this.sourceScreen = 'map_marker_info',
  });

  final ArtMarker marker;
  final Artwork? artwork;
  final KubusEvent? event;
  final Exhibition? exhibition;
  final String? distanceLabel;
  final bool linkedSubjectUnavailable;
  final String sourceScreen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final detail = resolveMarkerInfoDetail(
      marker: marker,
      l10n: l10n,
      artwork: artwork,
      event: event,
      exhibition: exhibition,
      distanceLabel: distanceLabel,
      linkedSubjectUnavailable: linkedSubjectUnavailable,
    );
    final accent = AppColorUtils.markerSubjectColor(
      markerType: marker.type.name,
      metadata: marker.metadata,
      scheme: scheme,
      roles: KubusColorRoles.of(context),
    );
    final coverUrl = MediaUrlResolver.resolve(detail.coverUrl);

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            detail.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KubusTypography.inter(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              key: const ValueKey<String>('marker_info_detail_screen_body'),
              padding: const EdgeInsets.fromLTRB(
                DetailSpacing.lg,
                0,
                DetailSpacing.lg,
                DetailSpacing.xl,
              ),
              children: [
                if (coverUrl != null && coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KubusRadius.lg),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: KubusCachedImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        cacheVersion: KubusCachedImage.versionTokenFromDate(
                          detail.coverUpdatedAt,
                        ),
                        errorBuilder: (_, __, ___) => _CoverFallback(
                          accent: accent,
                          markerType: marker.type,
                        ),
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KubusRadius.lg),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _CoverFallback(
                        accent: accent,
                        markerType: marker.type,
                      ),
                    ),
                  ),
                MarkerInfoDetailSections(
                  detail: detail,
                  artwork: artwork,
                  padding: const EdgeInsets.only(top: DetailSpacing.lg),
                  actions: <MarkerInfoDetailAction>[
                    if (marker.hasValidPosition)
                      MarkerInfoDetailAction(
                        icon: Icons.map_outlined,
                        label: l10n.commonOpenOnMap,
                        onTap: () => Navigator.of(context).pop(),
                        tooltip: l10n.commonOpenOnMap,
                        semanticsLabel: 'marker_info_open_on_map',
                      ),
                    MarkerInfoDetailAction(
                      icon: Icons.share_outlined,
                      label: l10n.commonShare,
                      onTap: () => _shareMarker(context),
                      tooltip: l10n.commonShare,
                      semanticsLabel: 'marker_info_share',
                      activeColor: themeProvider.accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shareMarker(BuildContext context) {
    ShareService().showShareSheet(
      context,
      target: ShareTarget.marker(markerId: marker.id, title: marker.name),
      sourceScreen: sourceScreen,
    );
  }

  /// Position helper kept for callers that focus the map after returning.
  LatLng get position => marker.position;
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.accent, required this.markerType});

  final Color accent;
  final ArtMarkerType markerType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.25),
            accent.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          AppColorUtils.markerSubjectIcon(markerType.name),
          color: scheme.onPrimary,
          size: 48,
        ),
      ),
    );
  }
}
