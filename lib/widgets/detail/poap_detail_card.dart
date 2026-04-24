
import 'package:flutter/material.dart';

import '../../utils/media_url_resolver.dart';
import 'detail_shell_components.dart';

class PoapDetailCard extends StatelessWidget {
  final String title;
  final String? description;
  final String? code;
  final String? iconUrl;
  final String? rarityLabel;
  final String? rewardLabel;
  final String? stateLabel;
  final String? eligibilityLabel;
  final String? eligibilityHint;
  final String? signedOutHint;
  final List<DetailContextItem> contextItems;
  final bool isClaimed;
  final bool canClaim;
  final bool isClaiming;
  final VoidCallback? onClaim;
  final String claimActionLabel;
  final String claimingActionLabel;

  const PoapDetailCard({
    super.key,
    required this.title,
    this.description,
    this.code,
    this.iconUrl,
    this.rarityLabel,
    this.rewardLabel,
    this.stateLabel,
    this.eligibilityLabel,
    this.eligibilityHint,
    this.signedOutHint,
    this.contextItems = const <DetailContextItem>[],
    this.isClaimed = false,
    this.canClaim = false,
    this.isClaiming = false,
    this.onClaim,
    required this.claimActionLabel,
    required this.claimingActionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badges = <Widget>[];

    void addBadge(String? label, {Color? color}) {
      final value = (label ?? '').trim();
      if (value.isEmpty) return;
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DetailSpacing.sm,
            vertical: DetailSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color ?? scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(DetailRadius.xl),
            border: Border.all(
              color: (color ?? scheme.outlineVariant).withValues(alpha: 0.28),
            ),
          ),
          child: Text(
            value,
            style: DetailTypography.caption(context).copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
      );
    }

    addBadge(stateLabel, color: isClaimed ? scheme.primary.withValues(alpha: 0.14) : null);
    addBadge(eligibilityLabel);
    addBadge(rarityLabel);
    if (rewardLabel != null && rewardLabel!.trim().isNotEmpty) {
      addBadge(rewardLabel);
    }

    return DetailCard(
      borderRadius: DetailRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBlock(iconUrl: iconUrl),
              const SizedBox(width: DetailSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DetailTypography.cardTitle(context),
                    ),
                    if (code != null && code!.trim().isNotEmpty) ...[
                      const SizedBox(height: DetailSpacing.xs),
                      Text(
                        code!.trim(),
                        style: DetailTypography.caption(context).copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: DetailSpacing.sm),
                      Wrap(
                        spacing: DetailSpacing.xs,
                        runSpacing: DetailSpacing.xs,
                        children: badges,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if ((description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: DetailSpacing.md),
            Text(
              description!.trim(),
              style: DetailTypography.body(context),
            ),
          ],
          if ((eligibilityHint ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: DetailSpacing.sm),
            Text(
              eligibilityHint!.trim(),
              style: DetailTypography.caption(context),
            ),
          ],
          if ((signedOutHint ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: DetailSpacing.sm),
            Text(
              signedOutHint!.trim(),
              style: DetailTypography.caption(context),
            ),
          ],
          if (contextItems.where((item) => item.value.trim().isNotEmpty).isNotEmpty) ...[
            const SizedBox(height: DetailSpacing.md),
            DetailContextCluster(
              compact: true,
              items: contextItems,
            ),
          ],
          if (canClaim && onClaim != null) ...[
            const SizedBox(height: DetailSpacing.md),
            DetailPrimaryCtaButton(
              icon: isClaiming ? Icons.hourglass_top : Icons.verified,
              label: isClaiming ? claimingActionLabel : claimActionLabel,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              onPressed: isClaiming ? null : onClaim,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBlock extends StatelessWidget {
  const _IconBlock({this.iconUrl});

  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = MediaUrlResolver.resolve(iconUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(DetailRadius.sm),
      child: Container(
        width: 72,
        height: 72,
        color: scheme.surfaceContainerHighest,
        child: resolved != null && resolved.trim().isNotEmpty
            ? Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackIcon(context),
              )
            : _fallbackIcon(context),
      ),
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        Icons.confirmation_number_outlined,
        size: 32,
        color: scheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }
}
