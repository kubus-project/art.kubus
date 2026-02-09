import 'dart:math' as math;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../features/map/nearby/nearby_art_controller.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../artwork_creator_byline.dart';
import '../../glass_components.dart';
import '../../map_overlay_blocker.dart';

enum KubusNearbyArtPanelLayout {
  mobileBottomSheet,
  desktopSidePanel,
}

enum KubusNearbyArtSort {
  nearest,
  newest,
  rewards,
  popular,
}

extension KubusNearbyArtSortLabel on KubusNearbyArtSort {
  String label(AppLocalizations l10n) {
    switch (this) {
      case KubusNearbyArtSort.nearest:
        return l10n.mapSortNearest;
      case KubusNearbyArtSort.newest:
        return l10n.mapSortNewest;
      case KubusNearbyArtSort.rewards:
        return l10n.mapSortHighestRewards;
      case KubusNearbyArtSort.popular:
        return l10n.mapSortMostViewed;
    }
  }
}

/// Shared nearby art UI used in:
/// - mobile map bottom sheet
/// - desktop map explore nearby side panel
///
/// Important constraints:
/// - must intercept pointer/scroll so map doesn't scroll/zoom underneath
/// - must not perform async work or side-effects in build
class KubusNearbyArtPanel extends StatefulWidget {
  const KubusNearbyArtPanel({
    super.key,
    required this.controller,
    required this.layout,
    required this.artworks,
    required this.markers,
    required this.basePosition,
    required this.isLoading,
    required this.travelModeEnabled,
    required this.radiusKm,
    this.titleKey,
    this.discoveryProgress,
    this.onClose,
    this.onRadiusTap,
    this.scrollController,
    this.onInteractingChanged,
  });

  final NearbyArtController controller;
  final KubusNearbyArtPanelLayout layout;

  /// Artworks already filtered by the parent map screen (search/filter chips).
  final List<Artwork> artworks;

  /// Markers currently loaded on the map.
  final List<ArtMarker> markers;

  /// Base position for distance sorting and labels.
  final LatLng? basePosition;

  final bool isLoading;
  final bool travelModeEnabled;
  final double radiusKm;

  /// Optional key for the title text (used by the mobile map tutorial overlay).
  final Key? titleKey;

  /// Optional overall discovery progress (0..1) for mobile header.
  final double? discoveryProgress;

  final VoidCallback? onClose;
  final VoidCallback? onRadiusTap;

  /// Mobile sheet passes the DraggableScrollableSheet controller here.
  final ScrollController? scrollController;

  /// Used by mobile map screen to temporarily disable map gestures while the
  /// user is interacting with the panel.
  final ValueChanged<bool>? onInteractingChanged;

  @override
  State<KubusNearbyArtPanel> createState() => _KubusNearbyArtPanelState();
}

class _KubusNearbyArtPanelState extends State<KubusNearbyArtPanel> {
  KubusNearbyArtSort _sort = KubusNearbyArtSort.nearest;
  bool _useGrid = false;

  late final ScrollController _internalScrollController;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController;

  @override
  void initState() {
    super.initState();
    _internalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _internalScrollController.dispose();
    super.dispose();
  }

  void _setInteracting(bool value) {
    widget.onInteractingChanged?.call(value);
  }

  List<Artwork> _sorted(List<Artwork> input, LatLng? base) {
    if (input.isEmpty) return input;

    final list = List<Artwork>.of(input);

    switch (_sort) {
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
    ThemeProvider themeProvider,
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
    ArtMarker? marker,
    LatLng fallback,
  ) async {
    // No side effects in build; this runs from a gesture callback.
    await widget.controller.handleArtworkTap(
      artwork: artwork,
      markers: widget.markers,
      fallbackPosition: fallback,
      // Keep overlays visible; both screens already apply additional focus
      // effects when selection changes.
      minZoom: 15.0,
      compositionYOffsetPx:
          widget.layout == KubusNearbyArtPanelLayout.mobileBottomSheet
              ? 0.0
              : null,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeProvider themeProvider,
    ColorScheme scheme,
  ) {
    final l10n = AppLocalizations.of(context)!;

    final isMobile =
        widget.layout == KubusNearbyArtPanelLayout.mobileBottomSheet;
    final title =
        isMobile ? l10n.mapNearbyArtTitle : l10n.arNearbyArtworksTitle;

    final subtitle = (() {
      final count = widget.artworks.length;
      if (widget.travelModeEnabled) {
        return isMobile
            ? '${l10n.mapResultsDiscoveredLabel(count, ((widget.discoveryProgress ?? 0) * 100).round())} ${l10n.mapTravelModeStatusTravelling}'
            : l10n.mapTravelModeStatusTravelling;
      }

      if (isMobile && widget.discoveryProgress != null) {
        return l10n.mapResultsDiscoveredLabel(
          count,
          ((widget.discoveryProgress ?? 0) * 100).round(),
        );
      }

      return '${l10n.mapNearbyRadiusTitle}: ${widget.radiusKm.toStringAsFixed(1)} km';
    })();

    final headerRow = Row(
      children: [
        if (!isMobile) ...[
          Icon(Icons.auto_awesome, color: themeProvider.accentColor, size: 18),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: widget.titleKey,
                style: KubusTypography.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: KubusTypography.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isMobile) ...[
          _glassIconButton(
            context,
            icon: Icons.radar,
            tooltip: widget.travelModeEnabled
                ? l10n.mapTravelModeStatusTravellingTooltip
                : l10n.mapNearbyRadiusTooltip(widget.radiusKm.toInt()),
            onTap: widget.travelModeEnabled ? null : widget.onRadiusTap,
          ),
          const SizedBox(width: 8),
          _glassIconButton(
            context,
            icon: _useGrid ? Icons.view_list : Icons.grid_view,
            tooltip: _useGrid
                ? l10n.mapShowListViewTooltip
                : l10n.mapShowGridViewTooltip,
            onTap: () => setState(() => _useGrid = !_useGrid),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<KubusNearbyArtSort>(
            tooltip: l10n.mapSortResultsTooltip,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final s in KubusNearbyArtSort.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Expanded(child: Text(s.label(l10n))),
                      if (s == _sort) Icon(Icons.check, color: scheme.primary),
                    ],
                  ),
                ),
            ],
            child: _glassIconButton(
              context,
              icon: Icons.sort,
              tooltip: l10n.mapSortResultsTooltip,
              onTap: null,
            ),
          ),
        ] else ...[
          IconButton(
            tooltip: l10n.commonClose,
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Semantics(
                label: 'nearby_art_handle',
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            headerRow,
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: headerRow,
    );
  }

  Widget _glassIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.30),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      ),
    );

    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final teal = roles.statTeal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
            borderRadius: KubusRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.explore_outlined, size: 38, color: teal),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.mapEmptyNoArtworksTitle,
                style: KubusTypography.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.mapEmptyNoArtworksDescription,
                textAlign: TextAlign.center,
                style: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkCard(
    BuildContext context,
    ThemeProvider themeProvider,
    Artwork artwork,
    ArtMarker? marker,
    LatLng basePosition,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final cover = ArtworkMediaResolver.resolveCover(artwork: artwork);

    final meters = widget.controller
        .distanceMeters(from: basePosition, to: artwork.position);
    final distanceText = widget.controller.formatDistance(meters);

    final accent = _subjectColorFor(context, themeProvider, artwork, marker);

    final textOnAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? KubusColors.textPrimaryDark
            : KubusColors.textPrimaryLight;

    return LiquidGlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(14),
      showBorder: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePrimaryTap(artwork, marker, artwork.position),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: Stack(
                  children: [
                    _ArtworkThumbnail(
                      url: cover,
                      width: 88,
                      height: 66,
                      borderRadius: 10,
                      iconSize: 24,
                    ),
                    if (artwork.arMarkerId != null &&
                        artwork.arMarkerId!.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.view_in_ar,
                              size: 12, color: textOnAccent),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    ArtworkCreatorByline(
                      artwork: artwork,
                      includeByPrefix: false,
                      showUsername: true,
                      linkToProfile: false,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            distanceText,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${artwork.rewards} KUB8',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkGridCard(
    BuildContext context,
    ThemeProvider themeProvider,
    Artwork artwork,
    ArtMarker? marker,
    LatLng basePosition,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final cover = ArtworkMediaResolver.resolveCover(artwork: artwork);

    final meters = widget.controller.distanceMeters(
      from: basePosition,
      to: artwork.position,
    );
    final distanceText = widget.controller.formatDistance(meters);
    final accent = _subjectColorFor(context, themeProvider, artwork, marker);

    return LiquidGlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(16),
      showBorder: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePrimaryTap(artwork, marker, artwork.position),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _ArtworkThumbnail(
                    url: cover,
                    width: double.infinity,
                    height: 120,
                    borderRadius: 12,
                    iconSize: 28,
                  ),
                  if (artwork.arMarkerId != null &&
                      artwork.arMarkerId!.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.view_in_ar,
                          size: 14,
                          color: ThemeData.estimateBrightnessForColor(accent) ==
                                  Brightness.dark
                              ? KubusColors.textPrimaryDark
                              : KubusColors.textPrimaryLight,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                artwork.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 2),
              ArtworkCreatorByline(
                artwork: artwork,
                includeByPrefix: false,
                showUsername: false,
                linkToProfile: false,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      distanceText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${artwork.rewards} KUB8',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isMobile =
        widget.layout == KubusNearbyArtPanelLayout.mobileBottomSheet;
    // Desktop panel spans the full height of the viewport, so no top/bottom
    // rounding is needed.  Only the left edge gets a subtle radius.
    final radius = isMobile
        ? const BorderRadius.vertical(top: Radius.circular(KubusRadius.xl))
        : BorderRadius.zero;

    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.56);

    final base = widget.basePosition;
    final sorted = _sorted(widget.artworks, base);

    Widget content = CustomScrollView(
      controller: _effectiveScrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(context, themeProvider, scheme),
        ),
        if (widget.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (sorted.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context, scheme),
          )
        else if (isMobile && _useGrid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final artwork = sorted[index];
                  final marker = widget.controller
                      .findMarkerForArtwork(artwork, widget.markers);
                  final basePosition = base ?? artwork.position;
                  return _buildArtworkGridCard(
                    context,
                    themeProvider,
                    artwork,
                    marker,
                    basePosition,
                  );
                },
                childCount: sorted.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              isMobile ? 0 : 8,
              16,
              isMobile ? 24 : 16,
            ),
            sliver: SliverList.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final artwork = sorted[index];
                final marker = widget.controller
                    .findMarkerForArtwork(artwork, widget.markers);
                final basePosition = base ?? artwork.position;
                return _buildArtworkCard(
                  context,
                  themeProvider,
                  artwork,
                  marker,
                  basePosition,
                );
              },
            ),
          ),
        if (isMobile)
          const SliverToBoxAdapter(
            child: SizedBox(height: KubusLayout.mainBottomNavBarHeight),
          ),
      ],
    );

    // Panel surface (glass + borders).
    content = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: isMobile
            ? Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              )
            : Border(
                left: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.30),
                ),
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.30),
                ),
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.30),
                ),
              ),
        boxShadow: isMobile
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ]
            : [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(-4, 0),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: LiquidGlassPanel(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.zero,
          showBorder: false,
          backgroundColor: glassTint,
          child: content,
        ),
      ),
    );

    // Interception + interaction tracking.
    return MapOverlayBlocker(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _setInteracting(true),
        onPointerUp: (_) => _setInteracting(false),
        onPointerCancel: (_) => _setInteracting(false),
        onPointerSignal: (_) {},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: isMobile ? (_) {} : null,
          onHorizontalDragUpdate: isMobile ? (_) {} : null,
          onHorizontalDragEnd: isMobile ? (_) {} : null,
          child: content,
        ),
      ),
    );
  }
}

class _ArtworkThumbnail extends StatelessWidget {
  const _ArtworkThumbnail({
    required this.url,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.iconSize,
  });

  final String? url;
  final double width;
  final double height;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = (url ?? '').trim();

    Widget child;
    if (resolved.isEmpty) {
      child = ColoredBox(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: scheme.onSurfaceVariant,
            size: iconSize,
          ),
        ),
      );
    } else {
      child = Image.network(
        resolved,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
                size: iconSize,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            child: Center(
              child: SizedBox(
                width: math.max(16.0, iconSize - 8),
                height: math.max(16.0, iconSize - 8),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}
