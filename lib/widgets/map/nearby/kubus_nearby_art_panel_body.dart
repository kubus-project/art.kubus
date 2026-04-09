import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../features/map/nearby/nearby_art_controller.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import 'kubus_nearby_art_panel_header.dart';
import 'kubus_nearby_art_panel_items.dart';
import 'kubus_nearby_art_panel_states.dart';
import 'kubus_nearby_art_panel_types.dart';

class KubusNearbyArtPanelBody extends StatelessWidget {
  const KubusNearbyArtPanelBody({
    super.key,
    required this.controller,
    required this.layout,
    required this.artworks,
    required this.markers,
    required this.basePosition,
    required this.isLoading,
    required this.travelModeEnabled,
    required this.radiusKm,
    required this.titleKey,
    required this.discoveryProgress,
    required this.sort,
    required this.useGrid,
    required this.accentColor,
    required this.onClose,
    required this.onRadiusTap,
    required this.scrollController,
    required this.onSortChanged,
    required this.onToggleGrid,
  });

  final NearbyArtController controller;
  final KubusNearbyArtPanelLayout layout;
  final List<Artwork> artworks;
  final List<ArtMarker> markers;
  final LatLng? basePosition;
  final bool isLoading;
  final bool travelModeEnabled;
  final double radiusKm;
  final Key? titleKey;
  final double? discoveryProgress;
  final KubusNearbyArtSort sort;
  final bool useGrid;
  final Color accentColor;
  final VoidCallback? onClose;
  final VoidCallback? onRadiusTap;
  final ScrollController scrollController;
  final ValueChanged<KubusNearbyArtSort> onSortChanged;
  final VoidCallback onToggleGrid;

  List<Artwork> _sorted(List<Artwork> input, LatLng? base) {
    if (input.isEmpty) return input;

    final list = List<Artwork>.of(input);

    switch (sort) {
      case KubusNearbyArtSort.nearest:
        if (base != null) {
          list.sort((a, b) =>
              a.getDistanceFrom(base).compareTo(b.getDistanceFrom(base)));
        }
        break;
      case KubusNearbyArtSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case KubusNearbyArtSort.rewards:
        list.sort((a, b) => b.rewards.compareTo(a.rewards));
        break;
      case KubusNearbyArtSort.popular:
        list.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
    }

    return list;
  }

  Color _subjectColorFor(
    BuildContext context,
    Artwork artwork,
    ArtMarker? marker,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);

    if (marker != null) {
      return AppColorUtils.markerSubjectColor(
        markerType: marker.type.name,
        metadata: marker.metadata,
        scheme: scheme,
        roles: roles,
      );
    }

    return AppColorUtils.markerSubjectColor(
      markerType: ArtMarkerType.artwork.name,
      metadata: <String, dynamic>{
        if (artwork.metadata != null) ...artwork.metadata!,
        'subjectCategory': artwork.category,
      },
      scheme: scheme,
      roles: roles,
    );
  }

  Future<void> _handlePrimaryTap(
    Artwork artwork,
    LatLng fallback,
  ) async {
    await controller.handleArtworkTap(
      artwork: artwork,
      markers: markers,
      fallbackPosition: fallback,
      minZoom: 15.0,
      compositionYOffsetPx:
          layout == KubusNearbyArtPanelLayout.mobileBottomSheet ? 0.0 : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = layout == KubusNearbyArtPanelLayout.mobileBottomSheet;
    final sorted = _sorted(artworks, basePosition);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: KubusNearbyArtPanelHeader(
            layout: layout,
            titleKey: titleKey,
            artworkCount: artworks.length,
            discoveryProgress: discoveryProgress,
            travelModeEnabled: travelModeEnabled,
            radiusKm: radiusKm,
            useGrid: useGrid,
            sort: sort,
            accentColor: accentColor,
            onClose: onClose,
            onRadiusTap: onRadiusTap,
            onToggleGrid: onToggleGrid,
            onSortChanged: onSortChanged,
          ),
        ),
        if (isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: KubusNearbyArtLoadingState(),
          )
        else if (sorted.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: KubusNearbyArtEmptyState(),
          )
        else if (isMobile && useGrid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final artwork = sorted[index];
                  final marker = controller.findMarkerForArtwork(
                    artwork,
                    markers,
                  );
                  final resolvedBase = basePosition ?? artwork.position;
                  final meters = controller.distanceMeters(
                    from: resolvedBase,
                    to: artwork.position,
                  );
                  final distanceText = controller.formatDistance(meters);
                  final accent = _subjectColorFor(context, artwork, marker);

                  return KubusNearbyArtArtworkGridItem(
                    artwork: artwork,
                    distanceText: distanceText,
                    accentColor: accent,
                    onTap: () => _handlePrimaryTap(artwork, artwork.position),
                  );
                },
                childCount: sorted.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: KubusSpacing.md,
                crossAxisSpacing: KubusSpacing.md,
                childAspectRatio: 0.92,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              KubusSpacing.md,
              isMobile ? 0 : KubusSpacing.sm,
              KubusSpacing.md,
              isMobile ? KubusSpacing.lg : KubusSpacing.md,
            ),
            sliver: SliverList.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
              itemBuilder: (context, index) {
                final artwork = sorted[index];
                final marker = controller.findMarkerForArtwork(
                  artwork,
                  markers,
                );
                final resolvedBase = basePosition ?? artwork.position;
                final meters = controller.distanceMeters(
                  from: resolvedBase,
                  to: artwork.position,
                );
                final distanceText = controller.formatDistance(meters);
                final accent = _subjectColorFor(context, artwork, marker);

                return KubusNearbyArtArtworkListItem(
                  artwork: artwork,
                  distanceText: distanceText,
                  accentColor: accent,
                  onTap: () => _handlePrimaryTap(artwork, artwork.position),
                );
              },
            ),
          ),
        if (isMobile)
          SliverToBoxAdapter(
            child: SizedBox(
              height: KubusLayout.mainBottomNavBarHeight +
                  MediaQuery.of(context).padding.bottom,
            ),
          ),
      ],
    );
  }
}
