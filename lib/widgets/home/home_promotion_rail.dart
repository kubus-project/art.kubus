import 'package:flutter/material.dart';

import '../../models/promotion.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/profile_identity_summary.dart';
import '../../widgets/staggered_fade_slide.dart';

typedef HomePromotionSubtitleBuilder = Widget? Function(
  BuildContext context,
  HomeRailItem item,
);

typedef HomePromotionTapHandler = void Function(HomeRailItem item);

typedef HomePromotionIconBuilder = IconData Function(PromotionEntityType entityType);

class HomePromotionRailList extends StatelessWidget {
  const HomePromotionRailList({
    super.key,
    required this.items,
    required this.placeholderIconBuilder,
    required this.profileFallbackLabel,
    this.animation,
    this.animationOffset = 0,
    this.height = 196,
    this.cardWidth = 176,
    this.cardSpacing = 16,
    this.horizontalPadding = 0,
    this.imageHeight = 108,
    this.profileAvatarRadius = 28,
    this.enableHover = false,
    this.onItemTap,
    this.subtitleBuilder,
    this.titleStyle,
    this.subtitleStyle,
  });

  final List<HomeRailItem> items;
  final Animation<double>? animation;
  final int animationOffset;
  final double height;
  final double cardWidth;
  final double cardSpacing;
  final double horizontalPadding;
  final double imageHeight;
  final double profileAvatarRadius;
  final bool enableHover;
  final HomePromotionTapHandler? onItemTap;
  final HomePromotionSubtitleBuilder? subtitleBuilder;
  final HomePromotionIconBuilder placeholderIconBuilder;
  final String profileFallbackLabel;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: List<Widget>.generate(items.length, (index) {
              final item = items[index];
              final card = Padding(
                padding: EdgeInsets.only(
                  right: index == items.length - 1 ? 0 : cardSpacing,
                ),
                child: _HomePromotionRailCard(
                  item: item,
                  width: cardWidth,
                  imageHeight: imageHeight,
                  profileAvatarRadius: profileAvatarRadius,
                  enableHover: enableHover,
                  onTap: onItemTap == null ? null : () => onItemTap!(item),
                  subtitle: subtitleBuilder?.call(context, item),
                  placeholderIcon:
                      placeholderIconBuilder.call(item.entityType),
                  profileFallbackLabel: profileFallbackLabel,
                  titleStyle: titleStyle,
                  subtitleStyle: subtitleStyle,
                ),
              );

              if (animation == null) {
                return card;
              }

              return StaggeredFadeSlide(
                animation: animation!,
                position: animationOffset + index,
                axis: Axis.horizontal,
                offset: 0.08,
                intervalExtent: 0.08,
                child: card,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _HomePromotionRailCard extends StatefulWidget {
  const _HomePromotionRailCard({
    required this.item,
    required this.width,
    required this.imageHeight,
    required this.profileAvatarRadius,
    required this.enableHover,
    required this.placeholderIcon,
    required this.profileFallbackLabel,
    this.onTap,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
  });

  final HomeRailItem item;
  final double width;
  final double imageHeight;
  final double profileAvatarRadius;
  final bool enableHover;
  final VoidCallback? onTap;
  final Widget? subtitle;
  final IconData placeholderIcon;
  final String profileFallbackLabel;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  State<_HomePromotionRailCard> createState() => _HomePromotionRailCardState();
}

class _HomePromotionRailCardState extends State<_HomePromotionRailCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );
    final borderRadius = BorderRadius.circular(18);

    final cardChild = widget.item.entityType == PromotionEntityType.profile
        ? _buildProfileCard(context)
        : _buildMediaCard(context);

    final decorated = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: widget.width,
      transform: _isHovered
          ? Matrix4.translationValues(0, -2, 0)
          : Matrix4.identity(),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: _isHovered && widget.enableHover
              ? scheme.primary.withValues(alpha: 0.22)
              : scheme.outline.withValues(alpha: 0.14),
          width: _isHovered && widget.enableHover ? 1.25 : 1,
        ),
        boxShadow: _isHovered && widget.enableHover
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: scheme.shadow.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.10 : 0.07,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: LiquidGlassCard(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: borderRadius,
        showBorder: false,
        blurSigma: style.blurSigma,
        backgroundColor: style.tintColor,
        fallbackMinOpacity: style.fallbackMinOpacity,
        child: cardChild,
      ),
    );

    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: decorated,
      ),
    );
  }

  Widget _buildMediaCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.imageHeight,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CardImageSurface(
                  imageUrl: widget.item.imageUrl,
                  placeholderIcon: widget.placeholderIcon,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.surfaceTint.withValues(alpha: 0.10),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                if (widget.item.promotion.isPromoted)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: Icon(Icons.star, color: Colors.amber, size: 18),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.titleStyle ??
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  widget.subtitle!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final identity = ProfileIdentityData.fromHomeRailItem(
      widget.item,
      fallbackLabel: widget.profileFallbackLabel,
    );
    final backgroundUrl = _resolveProfileCover(widget.item);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CardImageSurface(
            imageUrl: backgroundUrl,
            placeholderIcon: widget.placeholderIcon,
            alignPlaceholderToTop: false,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.64),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          if (widget.item.promotion.isPromoted)
            const Positioned(
              top: 12,
              left: 12,
              child: Icon(Icons.star, color: Colors.amber, size: 18),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ProfileIdentitySummary(
                  identity: identity,
                  layout: ProfileIdentityLayout.stacked,
                  avatarRadius: widget.profileAvatarRadius,
                  allowFabricatedFallback: true,
                  titleStyle: widget.titleStyle ??
                      theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                  subtitleStyle: widget.subtitleStyle ??
                      theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardImageSurface extends StatelessWidget {
  const _CardImageSurface({
    required this.imageUrl,
    required this.placeholderIcon,
    this.alignPlaceholderToTop = true,
  });

  final String? imageUrl;
  final IconData placeholderIcon;
  final bool alignPlaceholderToTop;

  @override
  Widget build(BuildContext context) {
    final resolvedImage = MediaUrlResolver.resolveDisplayUrl(imageUrl) ??
        MediaUrlResolver.resolve(imageUrl);

    if (resolvedImage != null && resolvedImage.isNotEmpty) {
      return Image.network(
        resolvedImage,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildPlaceholder(context, alignToTop: alignPlaceholderToTop),
      );
    }

    return _buildPlaceholder(context, alignToTop: alignPlaceholderToTop);
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required bool alignToTop,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.22),
            scheme.secondary.withValues(alpha: 0.18),
            scheme.surfaceContainerHigh.withValues(alpha: 0.28),
          ],
        ),
      ),
      child: Align(
        alignment: alignToTop ? Alignment.center : Alignment.center,
        child: Icon(
          placeholderIcon,
          color: scheme.onSurface.withValues(alpha: 0.64),
          size: 30,
        ),
      ),
    );
  }
}

String? _resolveProfileCover(HomeRailItem item) {
  String? pickRaw(List<String> keys) {
    for (final key in keys) {
      final value = item.raw[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  final rawCover = pickRaw(const <String>[
    'coverImage',
    'coverImageUrl',
    'cover_image_url',
    'cover_image',
    'coverUrl',
    'cover_url',
    'banner',
    'bannerUrl',
    'banner_url',
    'imageUrl',
    'image_url',
  ]);
  final resolved = MediaUrlResolver.resolveDisplayUrl(rawCover) ??
      MediaUrlResolver.resolve(rawCover);
  if (resolved != null && resolved.isNotEmpty) {
    return resolved;
  }
  return MediaUrlResolver.resolveDisplayUrl(item.imageUrl) ??
      MediaUrlResolver.resolve(item.imageUrl);
}
