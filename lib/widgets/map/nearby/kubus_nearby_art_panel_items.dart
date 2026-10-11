import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../inline_loading.dart';

import '../../../models/artwork.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../artwork_creator_byline.dart';
import '../../common/kubus_cached_image.dart';
import '../kubus_map_glass_surface.dart';

class _SpatialArchiveBadge extends StatelessWidget {
  const _SpatialArchiveBadge({
    required this.accentColor,
    required this.iconColor,
  });

  final Color accentColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.threed_rotation_rounded, size: 15, color: iconColor),
      );
}

class KubusNearbyArtArtworkListItem extends StatefulWidget {
  const KubusNearbyArtArtworkListItem({
    super.key,
    required this.artwork,
    required this.distanceText,
    required this.accentColor,
    required this.onTap,
  });

  final Artwork artwork;
  final String distanceText;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<KubusNearbyArtArtworkListItem> createState() =>
      _KubusNearbyArtArtworkListItemState();
}

class _KubusNearbyArtArtworkListItemState
    extends State<KubusNearbyArtArtworkListItem>
    with AutomaticKeepAliveClientMixin<KubusNearbyArtArtworkListItem> {
  // Owned by the row, not by its InkWell: the glass surface around the row can
  // be rebuilt while a card is open, which replaces the InkWell's focus node.
  // This node stays valid across that, so closing the card can return focus.
  final FocusNode _focusNode = FocusNode(debugLabel: 'nearby-art-row');

  // A row that opened a card is kept built while the card is open (bounded), so
  // closing the card can return focus to it. A lazy list would otherwise release
  // it once the sheet or the list re-sorts and the row scrolls out of view.
  bool _keepAlive = false;
  Timer? _keepAliveTimer;

  @override
  bool get wantKeepAlive => _keepAlive;

  void _markActivated() {
    _keepAliveTimer?.cancel();
    _keepAlive = true;
    updateKeepAlive();
    _keepAliveTimer = Timer(const Duration(minutes: 2), () {
      if (!mounted) return;
      _keepAlive = false;
      updateKeepAlive();
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final row = widget;
    return _nearbyListRow(
      context,
      artwork: row.artwork,
      distanceText: row.distanceText,
      accentColor: row.accentColor,
      onTap: () {
        _markActivated();
        row.onTap();
      },
      focusNode: _focusNode,
    );
  }
}

/// One nearby row body; [focusNode] is the row's keyboard target.
Widget _nearbyListRow(
  BuildContext context, {
  required Artwork artwork,
  required String distanceText,
  required Color accentColor,
  required VoidCallback onTap,
  required FocusNode focusNode,
}) {
  final scheme = Theme.of(context).colorScheme;
  final textOnAccent =
      ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
          ? KubusColors.textPrimaryDark
          : KubusColors.textPrimaryLight;

  return buildKubusMapGlassSurface(
    context: context,
    kind: KubusMapGlassSurfaceKind.card,
    borderRadius: BorderRadius.circular(KubusRadius.md),
    tintBase: scheme.surface,
    padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xxs),
    onTap: onTap,
    focusNode: focusNode,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Stack(
            children: [
              _ArtworkThumbnail(
                url: ArtworkMediaResolver.resolveCover(artwork: artwork),
                cacheVersion: KubusCachedImage.versionTokenFromDate(
                  artwork.updatedAt ?? artwork.createdAt,
                ),
                width: 88,
                height: 66,
                borderRadius: 10,
                iconSize: 24,
              ),
              if (artwork.spatialCaptureCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Semantics(
                    label: AppLocalizations.of(context)!.mapSpatialAvailable,
                    child: _SpatialArchiveBadge(
                      accentColor: accentColor,
                      iconColor: textOnAccent,
                    ),
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
                      fontSize: KubusHeaderMetrics.sectionSubtitle,
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
                      fontSize: KubusTextStyles.sectionSubtitle.fontSize,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      distanceText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize:
                                KubusTypography.textTheme.labelMedium?.fontSize,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                    ),
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

class KubusNearbyArtArtworkGridItem extends StatefulWidget {
  const KubusNearbyArtArtworkGridItem({
    super.key,
    required this.artwork,
    required this.distanceText,
    required this.accentColor,
    required this.onTap,
  });

  final Artwork artwork;
  final String distanceText;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<KubusNearbyArtArtworkGridItem> createState() =>
      _KubusNearbyArtArtworkGridItemState();
}

class _KubusNearbyArtArtworkGridItemState
    extends State<KubusNearbyArtArtworkGridItem>
    with AutomaticKeepAliveClientMixin<KubusNearbyArtArtworkGridItem> {
  // Owned by the row, not by its InkWell: the glass surface around the row can
  // be rebuilt while a card is open, which replaces the InkWell's focus node.
  // This node stays valid across that, so closing the card can return focus.
  final FocusNode _focusNode = FocusNode(debugLabel: 'nearby-art-row');

  // A row that opened a card is kept built while the card is open (bounded), so
  // closing the card can return focus to it. A lazy list would otherwise release
  // it once the sheet or the list re-sorts and the row scrolls out of view.
  bool _keepAlive = false;
  Timer? _keepAliveTimer;

  @override
  bool get wantKeepAlive => _keepAlive;

  void _markActivated() {
    _keepAliveTimer?.cancel();
    _keepAlive = true;
    updateKeepAlive();
    _keepAliveTimer = Timer(const Duration(minutes: 2), () {
      if (!mounted) return;
      _keepAlive = false;
      updateKeepAlive();
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final row = widget;
    return _nearbyGridRow(
      context,
      artwork: row.artwork,
      distanceText: row.distanceText,
      accentColor: row.accentColor,
      onTap: () {
        _markActivated();
        row.onTap();
      },
      focusNode: _focusNode,
    );
  }
}

/// One nearby row body; [focusNode] is the row's keyboard target.
Widget _nearbyGridRow(
  BuildContext context, {
  required Artwork artwork,
  required String distanceText,
  required Color accentColor,
  required VoidCallback onTap,
  required FocusNode focusNode,
}) {
  final scheme = Theme.of(context).colorScheme;
  final textOnAccent =
      ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
          ? KubusColors.textPrimaryDark
          : KubusColors.textPrimaryLight;

  return buildKubusMapGlassSurface(
    context: context,
    kind: KubusMapGlassSurfaceKind.card,
    borderRadius: BorderRadius.circular(KubusRadius.lg),
    tintBase: scheme.surface,
    padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xxs),
    onTap: onTap,
    focusNode: focusNode,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _ArtworkThumbnail(
              url: ArtworkMediaResolver.resolveCover(artwork: artwork),
              cacheVersion: KubusCachedImage.versionTokenFromDate(
                artwork.updatedAt ?? artwork.createdAt,
              ),
              width: double.infinity,
              height: 120,
              borderRadius: 12,
              iconSize: 28,
            ),
            if (artwork.spatialCaptureCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: _SpatialArchiveBadge(
                  accentColor: accentColor,
                  iconColor: textOnAccent,
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
                fontSize: KubusHeaderMetrics.sectionSubtitle,
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
                fontSize: KubusTextStyles.sectionSubtitle.fontSize,
                color: scheme.onSurfaceVariant,
              ),
        ),
        const Spacer(),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                distanceText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: KubusTypography.textTheme.labelMedium?.fontSize,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ArtworkThumbnail extends StatelessWidget {
  const _ArtworkThumbnail({
    required this.url,
    this.cacheVersion,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.iconSize,
  });

  final String? url;
  final String? cacheVersion;
  final double width;
  final double height;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheWidth = width.isFinite && width > 0
        ? (width * dpr).clamp(64.0, 1024.0).round()
        : null;
    final cacheHeight = height.isFinite && height > 0
        ? (height * dpr).clamp(64.0, 1024.0).round()
        : null;
    final resolved =
        MediaUrlResolver.resolveDisplayUrl(url, maxWidth: cacheWidth) ??
            (url ?? '').trim();

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
      child = KubusCachedImage(
        imageUrl: resolved,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        maxDisplayWidth: cacheWidth,
        cacheVersion: cacheVersion,
        placeholderBuilder: (context) => ColoredBox(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          child: Center(
            child: SizedBox(
              width: math.max(16.0, iconSize - 8),
              height: math.max(16.0, iconSize - 8),
              child: const InlineLoading(tileSize: 4),
            ),
          ),
        ),
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
              size: iconSize,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}
