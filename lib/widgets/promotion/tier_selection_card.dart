import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../models/promotion.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_flat_panel.dart';

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
    // Tiers are identified by name and icon, not by per-tier accent colours.
    final tierColor = roles.foreground;

    return KubusFlatSelectable(
      onTap: onTap,
      selected: isSelected,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(KubusChromeMetrics.compactCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(tierIcon, color: roles.foregroundMuted, size: 24),
                ),
                const SizedBox(width: KubusSpacing.md),
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
            const SizedBox(height: KubusSpacing.md),
            Text(
              _tierDescription(l10n, tier),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (rateCard.isSlotBased) ...[
              const SizedBox(height: KubusSpacing.sm),
              _SlotIndicator(
                slotCount: rateCard.slotCount ?? 3,
                tierColor: tierColor,
              ),
            ],
            if (rateCard.volumeDiscounts.isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.sm),
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
      spacing: KubusSpacing.xs + KubusSpacing.xxs,
      runSpacing: KubusSpacing.xxs,
      children: discounts.map((discount) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.sm,
            vertical: KubusSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(KubusRadius.md),
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
