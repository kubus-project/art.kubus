import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/creator_workspace.dart';
import '../screens/desktop/desktop_shell_scope.dart';
import '../screens/web3/artist/artist_studio.dart';
import '../screens/web3/institution/institution_hub.dart';
import '../services/contextual_auth_gate.dart';

/// One way into the creator workspaces, shared by mobile home, desktop
/// navigation and the workspaces themselves.
///
/// Opening a workspace never asks for anything: Artist Studio and Institution
/// Hub explain themselves to every viewer, guests included. What a viewer then
/// acquires is decided by [CreatorWorkspaceStage] and requested one step at a
/// time through [ContextualAuthGate], always returning to the workspace.
class CreatorWorkspaceNavigation {
  const CreatorWorkspaceNavigation._();

  /// Opens [workspace] inside the desktop shell when there is one, otherwise
  /// as a named page so the browser URL, a refresh and a shared link all name
  /// the workspace.
  static Future<void> open(
    BuildContext context,
    CreatorWorkspace workspace,
  ) async {
    final shell = DesktopShellScope.of(context);
    if (shell != null) {
      shell.navigateToRoute(workspace.desktopShellRoute);
      return;
    }
    await Navigator.of(context).push(pageRoute(workspace));
  }

  /// The mobile page for [workspace], named with its canonical route.
  static Route<void> pageRoute(CreatorWorkspace workspace) {
    return MaterialPageRoute<void>(
      builder: (_) => switch (workspace) {
        CreatorWorkspace.artistStudio => const ArtistStudio(),
        CreatorWorkspace.institutionHub => const InstitutionHub(),
      },
      settings: RouteSettings(name: workspace.route),
    );
  }

  /// The capability the next step of [stage] needs, or null when the step is
  /// taken inside the workspace (applying) or there is none.
  ///
  /// The account and the public profile come first. A wallet is requested only
  /// at the application, which the backend accepts as a wallet-signed request;
  /// opening the workspace, reading it and being reviewed need none.
  static ProtectedActionRequirements? requirementsFor(
    CreatorWorkspaceStage stage,
  ) {
    switch (stage) {
      case CreatorWorkspaceStage.discover:
      case CreatorWorkspaceStage.completeProfile:
        return ProtectedActionRequirements.participant;
      case CreatorWorkspaceStage.linkWalletToApply:
        return const ProtectedActionRequirements(
          requiresProfile: true,
          requiresWallet: true,
        );
      case CreatorWorkspaceStage.apply:
      case CreatorWorkspaceStage.pending:
      case CreatorWorkspaceStage.rejected:
      case CreatorWorkspaceStage.otherRoleReview:
      case CreatorWorkspaceStage.open:
        return null;
    }
  }

  /// Takes the viewer through the capability [stage] is missing and back to
  /// [workspace]. Nothing is replayed: the workspace re-reads the viewer's
  /// state when the journey returns, and the next step is offered there.
  static Future<void> acquireNextCapability(
    BuildContext context, {
    required CreatorWorkspace workspace,
    required CreatorWorkspaceStage stage,
  }) async {
    final requirements = requirementsFor(stage);
    if (requirements == null) return;
    final l10n = AppLocalizations.of(context)!;
    await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: switch (workspace) {
        CreatorWorkspace.artistStudio => l10n.creatorWorkspaceArtistStartCta,
        CreatorWorkspace.institutionHub =>
          l10n.creatorWorkspaceInstitutionStartCta,
      },
      // `contribute` names the funnel (and the gate's headline) without a
      // target id, so no replayable intent is captured.
      actionType: PendingActionType.contribute,
      returnRoute: workspace.route,
      sourceScreen: workspace.telemetrySource,
      requirements: requirements,
      copy: switch (workspace) {
        CreatorWorkspace.artistStudio => ActivationGateCopy(
            title: l10n.creatorWorkspaceArtistGateTitle,
            body: l10n.creatorWorkspaceArtistGateBody,
            hint: l10n.creatorWorkspaceGateHint,
          ),
        CreatorWorkspace.institutionHub => ActivationGateCopy(
            title: l10n.creatorWorkspaceInstitutionGateTitle,
            body: l10n.creatorWorkspaceInstitutionGateBody,
            hint: l10n.creatorWorkspaceGateHint,
          ),
      },
    );
  }
}
