import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../models/promotion.dart';
import '../../utils/kubus_color_roles.dart';
import '../glass_components.dart';

/// A card showing the price breakdown for a promotion quote
class PriceSummaryCard extends StatelessWidget {
  const PriceSummaryCard({
    super.key,
    required this.quote,
    required this.selectedPaymentMethod,
    required this.onPaymentMethodChanged,
    this.kub8Balance = 0,
  });

  final PriceQuote quote;
  final PromotionPaymentMethod selectedPaymentMethod;
  final ValueChanged<PromotionPaymentMethod> onPaymentMethodChanged;
  final double kub8Balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;

    final pricing = quote.pricing;
    final isFiat = selectedPaymentMethod == PromotionPaymentMethod.fiatCard;

    final basePrice = isFiat ? pricing.baseFiatPrice : pricing.baseKub8Price;
    final finalPrice = isFiat ? pricing.finalFiatPrice : pricing.finalKub8Price;
    final pricePerDay =
        isFiat ? pricing.fiatPricePerDay : pricing.kub8PricePerDay;
    final currencySymbol = isFiat ? '€' : '';
    final currencySuffix = isFiat ? '' : ' KUB8';

    final hasDiscount = pricing.discountPercent > 0;
    final insufficientKub8 = !isFiat && kub8Balance < pricing.finalKub8Price;
    final perDayLabel = l10n.promotionBuilderPerDay(
      '$currencySymbol${pricePerDay.toStringAsFixed(2)}$currencySuffix',
    );

    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment method toggle
          _PaymentMethodToggle(
            selectedMethod: selectedPaymentMethod,
            onChanged: onPaymentMethodChanged,
          ),
          const SizedBox(height: 16),

          // Price breakdown
          _PriceRow(
            label:
                '${l10n.promotionBuilderDurationDays(quote.durationDays)} × $perDayLabel',
            value:
                '$currencySymbol${basePrice.toStringAsFixed(2)}$currencySuffix',
            isSubtotal: true,
          ),

          if (hasDiscount) ...[
            const SizedBox(height: 8),
            _PriceRow(
              label:
                  '${l10n.promotionBuilderPriceDiscount} (${pricing.discountPercent.toStringAsFixed(0)}%)',
              value:
                  '-$currencySymbol${(basePrice - finalPrice).toStringAsFixed(2)}$currencySuffix',
              isDiscount: true,
              discountColor: roles.positiveAction,
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.promotionBuilderPriceTotal,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$currencySymbol${finalPrice.toStringAsFixed(2)}$currencySuffix',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isFiat ? roles.lockedFeature : roles.positiveAction,
                ),
              ),
            ],
          ),

          // KUB8 balance warning
          if (insufficientKub8) ...[
            const SizedBox(height: 12),
            FrostedContainer(
              backgroundColor: colors.errorContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: colors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.promotionBuilderInsufficientKub8Balance(
                        kub8Balance.toStringAsFixed(2),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: roles.negativeAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Refund policy
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                quote.isRefundable ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: quote.isRefundable
                    ? roles.positiveAction
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quote.isRefundable
                      ? l10n.promotionBuilderCancellationNote
                      : l10n.promotionBuilderNoRefundNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: quote.isRefundable
                        ? roles.positiveAction
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          // Schedule info
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_formatDate(context, quote.schedule.startDate)} → ${_formatDate(context, quote.schedule.endDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return MaterialLocalizations.of(context).formatMediumDate(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _PaymentMethodToggle extends StatelessWidget {
  const _PaymentMethodToggle({
    required this.selectedMethod,
    required this.onChanged,
  });

  final PromotionPaymentMethod selectedMethod;
  final ValueChanged<PromotionPaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<PromotionPaymentMethod>(
      segments: <ButtonSegment<PromotionPaymentMethod>>[
        ButtonSegment<PromotionPaymentMethod>(
          value: PromotionPaymentMethod.fiatCard,
          label: Text(l10n.promotionBuilderPaymentFiat),
          icon: const Icon(Icons.credit_card, size: 18),
        ),
        ButtonSegment<PromotionPaymentMethod>(
          value: PromotionPaymentMethod.kub8Balance,
          label: Text(l10n.promotionBuilderPaymentKub8),
          icon: const Icon(Icons.token, size: 18),
        ),
      ],
      selected: <PromotionPaymentMethod>{selectedMethod},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isSubtotal = false,
    this.isDiscount = false,
    this.discountColor,
  });

  final String label;
  final String value;
  final bool isSubtotal;
  final bool isDiscount;
  final Color? discountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDiscount
                  ? (discountColor ?? colors.secondary)
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSubtotal ? FontWeight.w500 : FontWeight.normal,
            color: isDiscount
                ? (discountColor ?? colors.secondary)
                : colors.onSurface,
          ),
        ),
      ],
    );
  }
}
