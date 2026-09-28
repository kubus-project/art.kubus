import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../models/collectible.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/marketplace_value_formatter.dart';
import '../common/kubus_cached_image.dart';
import '../dashboard/kubus_dashboard_chrome.dart';

/// PRODUCT v5 marketplace listing.
///
/// A listing has two layers that must never blur:
///
/// * the CULTURAL object: artwork image, title, creator ("by …"), taken from
///   the artwork record;
/// * the ECONOMIC listing: which value this is (listing price, last sale, or
///   edition price, from [MarketplaceDisplayValue.source]), the amount and
///   its currency, the listing state, and edition supply.
///
/// Creator is the artwork's artist. Sellers/owners are per edition and are
/// shown in the detail view with each token, never merged into the byline.
/// KUB8 appears only as a real price unit. No rarity gradients, no accent
/// borders, no reward-style decoration.

/// Where the displayed amount comes from, in words.
String marketplaceValueSourceLabel(
  AppLocalizations l10n,
  MarketplaceDisplayValue? value,
) {
  switch (value?.source) {
    case MarketplaceValueSource.listing:
    case MarketplaceValueSource.artworkListing:
      return l10n.marketplaceListedForLabel;
    case MarketplaceValueSource.lastSale:
      return l10n.marketplaceValueLastSaleLabel;
    case MarketplaceValueSource.mint:
      return l10n.marketplaceValueMintPriceLabel;
    case null:
      return l10n.marketplaceValueNotListedLabel;
  }
}

/// The listing state as text (never colour alone).
String marketplaceListingStateLabel(
  AppLocalizations l10n,
  MarketplaceArtworkEntry entry,
) {
  if (entry.isSoldOut) return l10n.marketplaceSoldOutBadgeLabel;
  if (entry.isListed) return l10n.commonForSale;
  return l10n.marketplaceValueNotListedLabel;
}

/// The economic block: value source, amount + currency, state, supply.
class MarketplaceListingSummary extends StatelessWidget {
  const MarketplaceListingSummary({
    super.key,
    required this.entry,
    this.dense = false,
  });

  final MarketplaceArtworkEntry entry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final value = entry.displayValue;
    final hasAmount = value?.hasAmount ?? false;
    final sourceLabel = marketplaceValueSourceLabel(l10n, value);
    final stateLabel = marketplaceListingStateLabel(l10n, entry);
    final supply = (entry.mintedCount != null && entry.totalSupply != null)
        ? '${entry.mintedCount}/${entry.totalSupply}'
        : null;

    final amountStyle =
        (dense ? KubusTextStyles.detailCardTitle : KubusTextStyles.statValue)
            .copyWith(color: roles.foreground, fontWeight: FontWeight.w700);

    return Semantics(
      container: true,
      label: hasAmount
          ? l10n.marketplaceListingValueSemantic(
              sourceLabel,
              MarketplaceValueFormatter.formatAmount(value!.amount!),
              value.currency,
              stateLabel,
            )
          : stateLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAmount) ...[
            Text(
              sourceLabel,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: MarketplaceValueFormatter.formatAmount(
                      value!.amount!,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: value.currency,
                    style: KubusTextStyles.machineValue.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: amountStyle,
            ),
            const SizedBox(height: KubusSpacing.xs),
          ],
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KubusStatusText(
                label: stateLabel,
                tone: entry.isSoldOut
                    ? KubusStatusTone.neutral
                    : (entry.isListed
                        ? KubusStatusTone.positive
                        : KubusStatusTone.neutral),
              ),
              if (supply != null)
                Text(
                  supply,
                  style: KubusTextStyles.machineValue.copyWith(
                    color: roles.foregroundMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Flat listing card: image, then the cultural identity, then a rule and
/// the economic summary. The whole card opens the details.
class MarketplaceListingCard extends StatelessWidget {
  const MarketplaceListingCard({
    super.key,
    required this.entry,
    required this.onOpen,
    this.creatorLine,
    this.imageHeight,
  });

  final MarketplaceArtworkEntry entry;
  final VoidCallback onOpen;

  /// Creator byline widget (defaults to `commonByArtist`).
  final Widget? creatorLine;

  /// Fixed media height; when null the image takes the remaining flex.
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final radius = BorderRadius.circular(KubusRadius.surface);

    final media = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: roles.surfaceRaised),
        if ((entry.coverUrl ?? '').trim().isNotEmpty)
          KubusCachedImage(imageUrl: entry.coverUrl, semanticLabel: entry.title)
        else
          Center(
            child: Icon(
              entry.requiresArInteraction
                  ? Icons.view_in_ar_outlined
                  : Icons.image_outlined,
              size: 36,
              color: roles.foregroundSubtle,
            ),
          ),
        if (entry.requiresArInteraction)
          Positioned(
            top: KubusSpacing.sm,
            right: KubusSpacing.sm,
            child: _MediaTag(label: l10n.marketplaceArBadgeLabel),
          ),
      ],
    );

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: KubusTextStyles.detailCardTitle.copyWith(
            color: roles.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: KubusSpacing.xxs),
        creatorLine ??
            Text(
              l10n.commonByArtist(entry.artistName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
      ],
    );

    return Semantics(
      button: true,
      label: l10n.marketplaceOpenSeriesDetailsSemantic(entry.title),
      child: Material(
        color: roles.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: roles.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          focusColor: roles.focus.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageHeight != null)
                SizedBox(height: imageHeight, child: media)
              else
                Expanded(flex: 5, child: media),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KubusSpacing.sm + KubusSpacing.xs,
                  KubusSpacing.sm + KubusSpacing.xs,
                  KubusSpacing.sm + KubusSpacing.xs,
                  KubusSpacing.sm,
                ),
                child: identity,
              ),
              Divider(height: 1, thickness: 1, color: roles.rule),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KubusSpacing.sm + KubusSpacing.xs,
                  KubusSpacing.sm,
                  KubusSpacing.sm + KubusSpacing.xs,
                  KubusSpacing.sm + KubusSpacing.xs,
                ),
                child: MarketplaceListingSummary(entry: entry, dense: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaTag extends StatelessWidget {
  const _MediaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.xs + KubusSpacing.xxs,
        vertical: KubusSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.control),
        border: Border.all(color: roles.rule),
      ),
      child: Text(
        label,
        style: KubusTextStyles.machineValue.copyWith(
          color: roles.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
