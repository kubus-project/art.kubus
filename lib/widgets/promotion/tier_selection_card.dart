import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../models/promotion.dart';
import '../../utils/kubus_color_roles.dart';

/// A visual card for selecting a promotion tier (Premium, Featured, Boost)
class TierSelectionCard extends StatelessWidget {
  const TierSelectionCard({
    super.key,
    required this.rateCard,
    required this.isSelected,
    required this.onTap,
  });

  final PromotionRateCard rateCard;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tier = rateCard.placementTier;

    final tierIcon = _iconForTier(tier);
    final tierColor = _colorForTier(tier, colors, roles);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? tierColor.withValues(alpha: 0.15)
              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? tierColor : colors.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    tierIcon,
                    color: tierColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tierDisplayName(l10n, tier).toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tierColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.promotionBuilderPerDay(
                          '€${rateCard.fiatPricePerDay.toStringAsFixed(2)}',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: tierColor,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _tierDescription(l10n, tier),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (rateCard.isSlotBased) ...[
              const SizedBox(height: 8),
              _SlotIndicator(
                slotCount: rateCard.slotCount ?? 3,
                tierColor: tierColor,
              ),
            ],
            if (rateCard.volumeDiscounts.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DiscountBadges(
                discounts: rateCard.volumeDiscounts,
                tierColor: tierColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForTier(PromotionPlacementTier tier) {
    switch (tier) {
      case PromotionPlacementTier.premium:
        return Icons.local_fire_department;
      case PromotionPlacementTier.featured:
        return Icons.star;
      case PromotionPlacementTier.boost:
        return Icons.rocket_launch;
    }
  }

  Color _colorForTier(
    PromotionPlacementTier tier,
    ColorScheme colors,
    KubusColorRoles roles,
  ) {
    switch (tier) {
      case PromotionPlacementTier.premium:
        return roles.achievementGold;
      case PromotionPlacementTier.featured:
        return roles.statTeal;
      case PromotionPlacementTier.boost:
        return colors.primary;
    }
  }

  String _tierDisplayName(
    AppLocalizations l10n,
    PromotionPlacementTier tier,
  ) {
    switch (tier) {
      case PromotionPlacementTier.premium:
        return l10n.promotionBuilderTierPremium;
      case PromotionPlacementTier.featured:
        return l10n.promotionBuilderTierFeatured;
      case PromotionPlacementTier.boost:
        return l10n.promotionBuilderTierBoost;
    }
  }

  String _tierDescription(
    AppLocalizations l10n,
    PromotionPlacementTier tier,
  ) {
    switch (tier) {
      case PromotionPlacementTier.premium:
        return l10n.promotionBuilderTierPremiumDesc;
      case PromotionPlacementTier.featured:
        return l10n.promotionBuilderTierFeaturedDesc;
      case PromotionPlacementTier.boost:
        return l10n.promotionBuilderTierBoostDesc;
    }
  }
}

class _SlotIndicator extends StatelessWidget {
  const _SlotIndicator({
    required this.slotCount,
    required this.tierColor,
  });

  final int slotCount;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(
          Icons.grid_view_rounded,
          size: 14,
          color: tierColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          l10n.promotionBuilderGuaranteedSlots(slotCount),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tierColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _DiscountBadges extends StatelessWidget {
  const _DiscountBadges({
    required this.discounts,
    required this.tierColor,
  });

  final List<VolumeDiscount> discounts;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: discounts.map((discount) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${l10n.promotionBuilderDiscountBadge(discount.discountPercent.toStringAsFixed(0))} • ${l10n.promotionBuilderDurationDays(discount.minDays)}+',
            style: theme.textTheme.labelSmall?.copyWith(
              color: tierColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}
