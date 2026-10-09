import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/creator_workspace.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../dashboard/kubus_dashboard_chrome.dart';
import '../kubus_button.dart';

/// What a creator workspace is for and how it opens, shown to a viewer
/// without an account in place of the workspace's tools.
///
/// It describes the real journey (account, public profile, application,
/// governance review) and says plainly that a wallet is needed only to sign
/// the application. The one action starts that journey; it never opens a
/// wallet flow.
class CreatorWorkspaceDiscoveryPanel extends StatelessWidget {
  const CreatorWorkspaceDiscoveryPanel({
    super.key,
    required this.workspace,
    required this.onStart,
  });

  final CreatorWorkspace workspace;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final isArtist = workspace == CreatorWorkspace.artistStudio;

    final title = isArtist
        ? l10n.creatorWorkspaceArtistDiscoverTitle
        : l10n.creatorWorkspaceInstitutionDiscoverTitle;
    final points = isArtist
        ? <String>[
            l10n.creatorWorkspaceArtistDiscoverPoint1,
            l10n.creatorWorkspaceArtistDiscoverPoint2,
            l10n.creatorWorkspaceArtistDiscoverPoint3,
          ]
        : <String>[
            l10n.creatorWorkspaceInstitutionDiscoverPoint1,
            l10n.creatorWorkspaceInstitutionDiscoverPoint2,
            l10n.creatorWorkspaceInstitutionDiscoverPoint3,
          ];
    final steps = <String>[
      l10n.creatorWorkspaceStepAccount,
      l10n.creatorWorkspaceStepProfile,
      isArtist
          ? l10n.creatorWorkspaceStepArtistApplication
          : l10n.creatorWorkspaceStepInstitutionApplication,
      l10n.creatorWorkspaceStepReview,
    ];

    return Container(
      key: ValueKey<String>('creator_workspace_discovery_${workspace.name}'),
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: KubusTextStyles.detailSectionTitle.copyWith(
                color: roles.foreground,
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: roles.foregroundMuted,
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Expanded(
                    child: Text(
                      point,
                      style: KubusTextStyles.detailBody.copyWith(
                        color: roles.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: KubusSpacing.sm),
          Divider(height: 1, thickness: 1, color: roles.rule),
          const SizedBox(height: KubusSpacing.md),
          KubusNotionLabel(l10n.creatorWorkspaceStepsTitle),
          const SizedBox(height: KubusSpacing.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: KubusTextStyles.structuralLabel.copyWith(
                        color: roles.foregroundMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: KubusTextStyles.detailBody.copyWith(
                        color: roles.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: KubusSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: roles.foregroundMuted,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Text(
                  l10n.creatorWorkspaceWalletNote,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: roles.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          KubusButton(
            key: ValueKey<String>('creator_workspace_start_${workspace.name}'),
            onPressed: onStart,
            label: isArtist
                ? l10n.creatorWorkspaceArtistStartCta
                : l10n.creatorWorkspaceInstitutionStartCta,
            icon: Icons.arrow_forward_rounded,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}
