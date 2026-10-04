import 'package:flutter/material.dart';

import '../../models/profile_identity_data.dart';
import '../../models/promotion.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/kubus_entity_semantics.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/common/kubus_entity_card.dart';
import '../../widgets/staggered_fade_slide.dart';

typedef HomePromotionSubtitleBuilder = Widget? Function(
  BuildContext context,
  HomeRailItem item,
);

typedef HomePromotionTapHandler = void Function(HomeRailItem item);

typedef HomePromotionIconBuilder = IconData Function(
    PromotionEntityType entityType);

/// Which rail entities are previewed as an identity rather than as a cultural
/// object.
///
/// An artist rail and an institution rail are both rails of *who*, so they get
/// the same identity-led composition. Giving the dedicated composition to
/// profiles alone left institutions reading as anonymous media cards.
bool homeRailItemIsIdentity(PromotionEntityType entityType) =>
    entityType == PromotionEntityType.profile ||
    entityType == PromotionEntityType.institution;

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
    this.profileAvatarRadius = 28,
    this.enableHover = false,
    this.onItemTap,
    this.subtitleBuilder,
  });

  final List<HomeRailItem> items;
  final Animation<double>? animation;
  final int animationOffset;
  final double height;
  final double cardWidth;
  final double cardSpacing;
  final double horizontalPadding;
  final double profileAvatarRadius;
  final bool enableHover;
  final HomePromotionTapHandler? onItemTap;
  final HomePromotionSubtitleBuilder? subtitleBuilder;
  final HomePromotionIconBuilder placeholderIconBuilder;
  final String profileFallbackLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // The hover lift and the contextual shadow live outside the card's own
        // box; clipping here would shave them off at the rail edge.
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
                  profileAvatarRadius: profileAvatarRadius,
                  enableHover: enableHover,
                  onTap: onItemTap == null ? null : () => onItemTap!(item),
                  subtitle: subtitleBuilder?.call(context, item),
                  placeholderIcon: placeholderIconBuilder.call(item.entityType),
                  profileFallbackLabel: profileFallbackLabel,
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

/// One rail entry, composed through the shared [KubusEntityCard] so a Home
/// rail card, a profile portfolio card and a studio gallery card are one
/// system rather than three unrelated ones.
class _HomePromotionRailCard extends StatelessWidget {
  const _HomePromotionRailCard({
    required this.item,
    required this.width,
    required this.profileAvatarRadius,
    required this.enableHover,
    required this.placeholderIcon,
    required this.profileFallbackLabel,
    this.onTap,
    this.subtitle,
  });

  final HomeRailItem item;
  final double width;
  final double profileAvatarRadius;
  final bool enableHover;
  final VoidCallback? onTap;
  final Widget? subtitle;
  final IconData placeholderIcon;
  final String profileFallbackLabel;

  @override
  Widget build(BuildContext context) {
    // Entity-semantic kind shared with the section header, the profile
    // portfolio and the studio gallery via the single KubusEntitySemantics
    // resolver; the card derives its accent and no-media glyph from it.
    final kind = KubusEntitySemantics.fromPromotion(item.entityType);
    final identity = homeRailItemIsIdentity(item.entityType);

    if (identity) {
      final data = ProfileIdentityData.fromHomeRailItem(
        item,
        fallbackLabel: profileFallbackLabel,
      );
      final isPerson = item.entityType == PromotionEntityType.profile;
      final hasMark = (data.avatarUrl ?? '').trim().isNotEmpty;
      return KubusEntityCard(
        variant: KubusEntityCardVariant.identity,
        kind: kind,
        title: data.label,
        subtitle: data.handle,
        // The rail owns its own placeholder glyph vocabulary (person,
        // apartment), which is what the surrounding section header already
        // uses, so it overrides the kind's default.
        fallbackGlyph: placeholderIcon,
        imageUrl: resolveHomeRailIdentityCover(item),
        // An institution without a logo gets no mark at all rather than a
        // fabricated person-shaped one: the role field already says what it
        // is. A person always gets one, fabricated from their wallet if the
        // account has not set a picture.
        leading: isPerson || hasMark
            ? AvatarWidget(
                wallet: data.walletSeed,
                avatarUrl: data.avatarUrl,
                radius: profileAvatarRadius,
                borderWidth: 0,
                allowFabricatedFallback: isPerson,
                enableProfileNavigation: false,
                showStatusIndicator: false,
              )
            : null,
        badge: item.promotion.isPromoted ? const _PromotedMark() : null,
        onTap: onTap,
        width: width,
        enableHover: enableHover,
        titleMaxLines: 1,
      );
    }

    return KubusEntityCard(
      variant: KubusEntityCardVariant.media,
      kind: kind,
      title: item.title,
      subtitleWidget: subtitle,
      fallbackGlyph: placeholderIcon,
      imageUrl: item.imageUrl,
      badge: item.promotion.isPromoted ? const _PromotedMark() : null,
      onTap: onTap,
      width: width,
      enableHover: enableHover,
    );
  }
}

/// The promotion mark over a card's media. Decorative: the rail's own
/// semantics already say what the card is.
class _PromotedMark extends StatelessWidget {
  const _PromotedMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Icon(
        Icons.star,
        color: KubusColorRoles.of(context).achievementGold,
        size: KubusSizes.trailingChevron + 2,
      ),
    );
  }
}

/// The cover an identity rail card paints behind its avatar or logo.
///
/// The backend home-rail query already carries `avatar_url` and
/// `cover_image_url` for profiles, under several historical spellings. Nothing
/// here invents a field — it reads the ones the payload actually uses.
///
/// A logo is deliberately **not** a cover fallback: an institution's logo is
/// already the card's leading mark (see
/// [ProfileIdentityData.fromHomeRailItem]), so using it behind itself would
/// print the same image twice. With no real cover the card falls through to
/// the authored role field instead, which is a designed surface rather than an
/// anonymous gradient.
String? resolveHomeRailIdentityCover(HomeRailItem item) {
  for (final key in const <String>[
    'coverImage',
    'coverImageUrl',
    'cover_image_url',
    'cover_image',
    'coverUrl',
    'cover_url',
    'banner',
    'bannerUrl',
    'banner_url',
  ]) {
    final raw = item.raw[key]?.toString().trim();
    if (raw == null || raw.isEmpty) continue;
    final resolved = MediaUrlResolver.resolveDisplayUrl(raw) ??
        MediaUrlResolver.resolve(raw);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
  }
  return null;
}
