import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/attestation.dart';
import '../providers/attestation_provider.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'glass_components.dart';

class AttestationBadgePanel extends StatelessWidget {
  const AttestationBadgePanel({
    super.key,
    required this.title,
    this.compact = false,
  });

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<AttestationProvider>(
      builder: (context, provider, _) {
        final l10n = AppLocalizations.of(context)!;
        final roles = KubusColorRoles.of(context);
        final scheme = Theme.of(context).colorScheme;

        Widget child;
        if (provider.isLoading && provider.attestations.isEmpty) {
          child = const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else {
          final badges = _buildBadges(context, provider);
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: KubusSpacing.sm,
                runSpacing: KubusSpacing.sm,
                children: badges,
              ),
              if (provider.lastError != null &&
                  provider.totalCount == 0) ...<Widget>[
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  l10n.attestationBadgePanelLoadFailed,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.error.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ],
          );
        }

        return LiquidGlassCard(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          padding: EdgeInsets.all(compact ? KubusSpacing.md : KubusSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.verified_outlined,
                    size: compact ? 18 : 20,
                    color: roles.statBlue,
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (provider.totalCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KubusSpacing.sm,
                        vertical: KubusSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: roles.statTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(KubusRadius.xl),
                        border: Border.all(
                          color: roles.statTeal.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Text(
                        '${provider.totalCount}',
                        style: KubusTextStyles.compactBadge.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KubusSpacing.sm),
              child,
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildBadges(
      BuildContext context, AttestationProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final badges = <Widget>[];

    void addBadge({
      required String label,
      required int count,
      required IconData icon,
      required Color color,
    }) {
      if (count <= 0) return;
      badges.add(_AttestationChip(
        label: '$label · $count',
        icon: icon,
        color: color,
      ));
    }

    addBadge(
      label: l10n.attestationBadgePanelAttendance,
      count: provider.countByType(AttestationType.attendance),
      icon: Icons.place_outlined,
      color: roles.statBlue,
    );
    addBadge(
      label: l10n.attestationBadgePanelParticipation,
      count: provider.countByType(AttestationType.participationProof),
      icon: Icons.event_available_outlined,
      color: roles.statTeal,
    );
    addBadge(
      label: l10n.attestationBadgePanelApproval,
      count: provider.countByType(AttestationType.approval),
      icon: Icons.task_alt,
      color: roles.positiveAction,
    );
    addBadge(
      label: l10n.attestationBadgePanelCuratorial,
      count: provider.countByType(AttestationType.curatorial),
      icon: Icons.auto_awesome_outlined,
      color: roles.statAmber,
    );
    addBadge(
      label: l10n.attestationBadgePanelInstitutional,
      count: provider.countByType(AttestationType.institutional),
      icon: Icons.account_balance_outlined,
      color: roles.web3InstitutionAccent,
    );
    addBadge(
      label: l10n.attestationBadgePanelCollectibleProof,
      count: provider.countByType(AttestationType.collectibleProof),
      icon: Icons.collections_bookmark_outlined,
      color: roles.web3MarketplaceAccent,
    );
    addBadge(
      label: l10n.attestationBadgePanelMinted,
      count: provider.mintedCount,
      icon: Icons.verified,
      color: roles.web3MarketplaceAccent,
    );

    if (badges.isEmpty) {
      return <Widget>[
        Text(
          l10n.attestationBadgePanelEmpty,
          style: KubusTextStyles.detailCaption.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ];
    }

    return badges;
  }
}

class _AttestationChip extends StatelessWidget {
  const _AttestationChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: KubusSpacing.xs),
          Text(
            label,
            style: KubusTextStyles.detailCaption.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
