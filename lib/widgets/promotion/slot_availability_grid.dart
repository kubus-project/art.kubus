import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../models/promotion.dart';

/// A visual grid showing slot availability for premium tier promotions
class SlotAvailabilityGrid extends StatelessWidget {
  const SlotAvailabilityGrid({
    super.key,
    required this.availability,
    required this.selectedSlot,
    required this.onSlotSelected,
    this.alternatives,
    this.onAlternativeSelected,
  });

  final SlotAvailability availability;
  final int? selectedSlot;
  final ValueChanged<int> onSlotSelected;
  final AlternativeDatesResponse? alternatives;
  final ValueChanged<AlternativeDate>? onAlternativeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (!availability.isSlotBased || availability.slots == null) {
      return const SizedBox.shrink();
    }

    final slots = availability.slots!;
    final hasUnavailableSelected = selectedSlot != null &&
        slots.any((s) => s.slotIndex == selectedSlot && !s.isAvailable);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.promotionBuilderSelectSlotTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.promotionBuilderPremiumSlotsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: slots.map((slot) {
            final isSelected = selectedSlot == slot.slotIndex;
            final isAvailable = slot.isAvailable;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: slot.slotIndex < slots.length ? 8 : 0,
                ),
                child: _SlotCard(
                  slotIndex: slot.slotIndex,
                  isSelected: isSelected,
                  isAvailable: isAvailable,
                  bookings: slot.bookings,
                  onTap: () => onSlotSelected(slot.slotIndex),
                ),
              ),
            );
          }).toList(),
        ),
        if (hasUnavailableSelected && alternatives != null) ...[
          const SizedBox(height: 16),
          _AlternativeDatesSection(
            alternatives: alternatives!,
            onSelected: onAlternativeSelected,
          ),
        ],
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slotIndex,
    required this.isSelected,
    required this.isAvailable,
    required this.bookings,
    required this.onTap,
  });

  final int slotIndex;
  final bool isSelected;
  final bool isAvailable;
  final List<SlotBooking> bookings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final borderColor = isSelected
        ? (isAvailable ? colors.primary : colors.error)
        : colors.outline.withValues(alpha: 0.3);

    final backgroundColor = isAvailable
        ? (isSelected
            ? colors.primaryContainer.withValues(alpha: 0.5)
            : colors.surfaceContainerHighest.withValues(alpha: 0.5))
        : colors.errorContainer.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isAvailable ? Icons.check_circle_outline : Icons.block,
              color: isAvailable
                  ? (isSelected ? colors.primary : colors.onSurfaceVariant)
                  : colors.error,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.promotionBuilderSlotLabel(slotIndex),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isAvailable ? colors.onSurface : colors.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAvailable
                  ? l10n.promotionBuilderSlotAvailable
                  : l10n.promotionBuilderSlotBookedUntil(
                      _formatBookingDate(context, bookings),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isAvailable ? colors.secondary : colors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBookingDate(BuildContext context, List<SlotBooking> bookings) {
    if (bookings.isEmpty) return '';
    return MaterialLocalizations.of(context).formatMediumDate(
      bookings.first.endsAt,
    );
  }
}

class _AlternativeDatesSection extends StatelessWidget {
  const _AlternativeDatesSection({
    required this.alternatives,
    this.onSelected,
  });

  final AlternativeDatesResponse alternatives;
  final ValueChanged<AlternativeDate>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (alternatives.alternatives.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.promotionBuilderNoAlternativeDates,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: colors.secondary,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.promotionBuilderAlternativeDates,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: alternatives.alternatives.map((alt) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _AlternativeDateChip(
                  alternative: alt,
                  onTap: onSelected != null ? () => onSelected!(alt) : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _AlternativeDateChip extends StatelessWidget {
  const _AlternativeDateChip({
    required this.alternative,
    this.onTap,
  });

  final AlternativeDate alternative;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final daysLabel = alternative.daysUntilStart == 0
        ? l10n.promotionBuilderStartImmediately
        : l10n.promotionBuilderDurationDays(alternative.daysUntilStart);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(context, alternative.startDate),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              daysLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
