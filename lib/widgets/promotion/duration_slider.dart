import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

/// A slider for selecting promotion duration with quick pick chips
class DurationSlider extends StatelessWidget {
  const DurationSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.discountPercent = 0,
    this.quickPicks = const [3, 7, 14, 30],
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final double discountPercent;
  final List<int> quickPicks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.promotionBuilderDurationTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _DurationBadge(
              days: value,
              discountPercent: discountPercent,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Quick pick chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: quickPicks.where((d) => d >= min && d <= max).map((days) {
              final isSelected = value == days;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _QuickPickChip(
                  days: days,
                  isSelected: isSelected,
                  onTap: () => onChanged(days),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            activeTrackColor: colors.primary,
            inactiveTrackColor: colors.surfaceContainerHighest,
            thumbColor: colors.primary,
            overlayColor: colors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        // Min/Max labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.promotionBuilderDurationDays(min),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                l10n.promotionBuilderDurationDays(max),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({
    required this.days,
    required this.discountPercent,
  });

  final int days;
  final double discountPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            l10n.promotionBuilderDurationDays(days),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        if (discountPercent > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_offer,
                  size: 14,
                  color: colors.onTertiaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.promotionBuilderDiscountBadge(
                    discountPercent.toStringAsFixed(0),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip({
    required this.days,
    required this.isSelected,
    required this.onTap,
  });

  final int days;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final label = days == 7
        ? l10n.promotionBuilderQuickPick1Week
        : days == 14
            ? l10n.promotionBuilderQuickPick2Weeks
            : days == 30
                ? l10n.promotionBuilderQuickPick1Month
                : days == 3
                    ? l10n.promotionBuilderQuickPick3Days
                    : l10n.promotionBuilderDurationDays(days);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
