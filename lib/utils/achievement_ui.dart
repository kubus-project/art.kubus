import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../services/achievement_service.dart' as achievement_svc;
import '../models/achievements.dart' as backend_achievements;
import 'app_color_utils.dart';
import 'category_accent_color.dart';

class AchievementUi {
  const AchievementUi._();

  static IconData iconForPreview({
    required String code,
    required String category,
    bool isPoap = false,
  }) {
    if (isPoap) return Icons.verified;
    final normalizedCategory = category.toLowerCase();
    final normalizedCode = code.toLowerCase();
    switch (normalizedCategory) {
      case 'discovery':
        return Icons.explore_outlined;
      case 'ar':
        return Icons.view_in_ar;
      case 'nft':
        return Icons.token;
      case 'community':
        if (normalizedCode.contains('comment')) {
          return Icons.chat_bubble_outline;
        }
        if (normalizedCode.contains('like')) return Icons.favorite_border;
        return Icons.forum_outlined;
      case 'street_art':
        return AppColorUtils.streetArtIcon;
      case 'events':
        return Icons.event_available;
      case 'trading':
        return Icons.swap_horiz;
    }
    return Icons.emoji_events_outlined;
  }

  static Color accentForPreview(
    BuildContext context, {
    required String category,
    required String rarity,
  }) {
    final normalizedCategory = category.trim().isEmpty ? rarity : category;
    return CategoryAccentColor.resolve(context, normalizedCategory);
  }

  static IconData iconFor(Object achievement) {
    if (achievement is backend_achievements.AchievementDefinition) {
      return iconForPreview(
        code: achievement.code,
        category: achievement.category,
        isPoap: achievement.isPoap,
      );
    }
    final typed = achievement as achievement_svc.AchievementDefinition;
    if (typed.isPOAP) return Icons.verified;
    switch (typed.type) {
      case achievement_svc.AchievementType.firstDiscovery:
      case achievement_svc.AchievementType.artExplorer:
      case achievement_svc.AchievementType.artMaster:
      case achievement_svc.AchievementType.artLegend:
        return Icons.explore_outlined;
      case achievement_svc.AchievementType.firstARView:
      case achievement_svc.AchievementType.arEnthusiast:
      case achievement_svc.AchievementType.arPro:
        return Icons.view_in_ar;
      case achievement_svc.AchievementType.firstNFTMint:
      case achievement_svc.AchievementType.nftCollector:
      case achievement_svc.AchievementType.nftTrader:
        return Icons.token;
      case achievement_svc.AchievementType.firstPost:
      case achievement_svc.AchievementType.influencer:
      case achievement_svc.AchievementType.communityBuilder:
        return Icons.forum_outlined;
      case achievement_svc.AchievementType.firstLike:
      case achievement_svc.AchievementType.popularCreator:
        return Icons.favorite_border;
      case achievement_svc.AchievementType.firstComment:
      case achievement_svc.AchievementType.commentator:
        return Icons.chat_bubble_outline;
      case achievement_svc.AchievementType.firstTrade:
      case achievement_svc.AchievementType.smartTrader:
      case achievement_svc.AchievementType.marketMaster:
        return Icons.swap_horiz;
      case achievement_svc.AchievementType.earlyAdopter:
      case achievement_svc.AchievementType.betaTester:
      case achievement_svc.AchievementType.artSupporter:
        return Icons.auto_awesome;
      case achievement_svc.AchievementType.eventAttendee:
      case achievement_svc.AchievementType.galleryVisitor:
      case achievement_svc.AchievementType.workshopParticipant:
        return Icons.event_available;
      case achievement_svc.AchievementType.streetArtSpotter:
      case achievement_svc.AchievementType.streetArtScout:
      case achievement_svc.AchievementType.streetArtCurator:
      case achievement_svc.AchievementType.streetArtPatron:
        return AppColorUtils.streetArtIcon;
    }
  }

  static String categoryLabelFor(
    Object achievement,
    AppLocalizations l10n,
  ) {
    if (achievement is backend_achievements.AchievementDefinition) {
      if (achievement.isPoap) return l10n.userProfileAchievementCategoryEvents;
      switch (achievement.category.toLowerCase()) {
        case 'discovery':
          return l10n.userProfileAchievementCategoryDiscovery;
        case 'ar':
          return l10n.userProfileAchievementCategoryAr;
        case 'nft':
          return l10n.userProfileAchievementCategoryNft;
        case 'community':
          return l10n.userProfileAchievementCategoryCommunity;
        case 'street_art':
          return l10n.userProfileAchievementCategoryStreetArt;
        case 'events':
          return l10n.userProfileAchievementCategoryEvents;
        case 'trading':
          return l10n.userProfileAchievementCategoryTrading;
      }
      return achievement.category;
    }
    final typed = achievement as achievement_svc.AchievementDefinition;
    if (typed.isPOAP) return l10n.userProfileAchievementCategoryEvents;
    switch (typed.type) {
      case achievement_svc.AchievementType.firstDiscovery:
      case achievement_svc.AchievementType.artExplorer:
      case achievement_svc.AchievementType.artMaster:
      case achievement_svc.AchievementType.artLegend:
        return l10n.userProfileAchievementCategoryDiscovery;
      case achievement_svc.AchievementType.firstARView:
      case achievement_svc.AchievementType.arEnthusiast:
      case achievement_svc.AchievementType.arPro:
        return l10n.userProfileAchievementCategoryAr;
      case achievement_svc.AchievementType.firstNFTMint:
      case achievement_svc.AchievementType.nftCollector:
      case achievement_svc.AchievementType.nftTrader:
        return l10n.userProfileAchievementCategoryNft;
      case achievement_svc.AchievementType.firstPost:
      case achievement_svc.AchievementType.influencer:
      case achievement_svc.AchievementType.communityBuilder:
        return l10n.userProfileAchievementCategoryCommunity;
      case achievement_svc.AchievementType.firstLike:
      case achievement_svc.AchievementType.popularCreator:
      case achievement_svc.AchievementType.firstComment:
      case achievement_svc.AchievementType.commentator:
        return l10n.userProfileAchievementCategorySocial;
      case achievement_svc.AchievementType.firstTrade:
      case achievement_svc.AchievementType.smartTrader:
      case achievement_svc.AchievementType.marketMaster:
        return l10n.userProfileAchievementCategoryTrading;
      case achievement_svc.AchievementType.earlyAdopter:
      case achievement_svc.AchievementType.betaTester:
      case achievement_svc.AchievementType.artSupporter:
        return l10n.userProfileAchievementCategorySpecial;
      case achievement_svc.AchievementType.eventAttendee:
      case achievement_svc.AchievementType.galleryVisitor:
      case achievement_svc.AchievementType.workshopParticipant:
        return l10n.userProfileAchievementCategoryEvents;
      case achievement_svc.AchievementType.streetArtSpotter:
      case achievement_svc.AchievementType.streetArtScout:
      case achievement_svc.AchievementType.streetArtCurator:
      case achievement_svc.AchievementType.streetArtPatron:
        return l10n.userProfileAchievementCategoryStreetArt;
    }
  }

  static Color accentFor(
    BuildContext context,
    Object achievement,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final category = categoryLabelFor(achievement, l10n);
    return CategoryAccentColor.resolve(context, category);
  }
}
