import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dao.dart';
import '../../models/user_persona.dart';
import '../../providers/dao_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../../screens/map_markers/marker_editor_screen.dart';
import '../../screens/web3/artist/artist_studio.dart';
import '../../screens/web3/institution/institution_hub.dart';
import '../../services/contextual_auth_gate.dart';
import '../../utils/creator_shell_navigation.dart';
import '../../utils/dao_role_verification.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/wallet_utils.dart';
import '../common/kubus_action_tile.dart';

enum ContributionCardAction { join, document, artwork, exhibition, application }

ContributionCardAction? resolveContributionCardAction({
  required bool signedIn,
  required String walletAddress,
  required UserPersona? persona,
  required DAOReview? review,
  required bool streetArtEnabled,
  required bool exhibitionsEnabled,
}) {
  if (!signedIn) {
    return ContributionCardAction.join;
  }
  // A persona is a preference, never publishing authority.
  final matched =
      review != null && WalletUtils.equals(walletAddress, review.walletAddress)
          ? review
          : null;
  final verification =
      DaoRoleVerification(walletAddress: walletAddress, review: matched);
  if (!verification.hasWallet) {
    return null;
  }
  if (verification.isPendingFor(DaoRoleType.artist) ||
      verification.isPendingFor(DaoRoleType.institution)) {
    return ContributionCardAction.application;
  }
  if (verification.isApprovedFor(DaoRoleType.artist)) {
    return ContributionCardAction.artwork;
  }
  if (exhibitionsEnabled &&
      verification.isApprovedFor(DaoRoleType.institution)) {
    return ContributionCardAction.exhibition;
  }
  if (persona == UserPersona.lover && streetArtEnabled) {
    return ContributionCardAction.document;
  }
  return null;
}

/// One contextual contribution entry. Unavailable 0.9 account-only publishing
/// is deliberately not advertised as a current capability.
class ContextualContributionCard extends StatefulWidget {
  const ContextualContributionCard({super.key, required this.returnRoute});
  final String returnRoute;
  @override
  State<ContextualContributionCard> createState() =>
      _ContextualContributionCardState();
}

class _ContextualContributionCardState
    extends State<ContextualContributionCard> {
  bool _busy = false;
  bool _resumeContribution = false;
  bool _readReturnArguments = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readReturnArguments) {
      _readReturnArguments = true;
      final arguments = ModalRoute.of(context)?.settings.arguments;
      _resumeContribution =
          arguments is Map && arguments['resumeContribution'] == 'true';
    }
  }

  ContributionCardAction? _action(BuildContext context) {
    final profile = context.read<ProfileProvider>();
    final wallet = context.read<WalletProvider>().currentWalletAddress ?? '';
    final dao = context.read<DAOProvider>();
    if (profile.isSignedIn && wallet.isNotEmpty) {
      // Use the provider's existing deferred hydration, never a widget-owned
      // role request or persona-derived authority.
      dao.reviews;
    }
    return resolveContributionCardAction(
      signedIn: profile.isSignedIn,
      walletAddress: wallet,
      persona: profile.userPersona,
      review: dao.findReviewForWallet(wallet),
      streetArtEnabled: AppConfig.isFeatureEnabled('streetArtMarkers'),
      exhibitionsEnabled: AppConfig.isFeatureEnabled('exhibitions'),
    );
  }

  String _label(AppLocalizations l10n, ContributionCardAction action) =>
      switch (action) {
        ContributionCardAction.join => l10n.contributionJoin,
        ContributionCardAction.document => l10n.contributionDocument,
        ContributionCardAction.artwork => l10n.contributionArtwork,
        ContributionCardAction.exhibition => l10n.contributionExhibition,
        ContributionCardAction.application => l10n.contributionApplication,
      };

  Future<void> _activate() async {
    if (_busy) return;
    final action = _action(context);
    if (action == null) return;
    setState(() => _busy = true);
    var journeyStarted = false;
    try {
      final allowed = await const ContextualAuthGate().ensureAuthenticated(
        context,
        actionLabel: _label(AppLocalizations.of(context)!, action),
        returnRoute: widget.returnRoute,
        onAuthJourneyStarted: () => journeyStarted = true,
        returnArguments: action == ContributionCardAction.join
            ? const <String, String>{'resumeContribution': 'true'}
            : const <String, String>{},
        requirements: action == ContributionCardAction.document ||
                action == ContributionCardAction.join
            ? ProtectedActionRequirements.participant
            : ProtectedActionRequirements.creator,
      );
      if (!mounted) return;
      if (!allowed) {
        // The existing journey can pop back to this same route rather than
        // recreate it with completion arguments. Resume only a completed Join
        // attempt, and re-run the gate before opening any contribution form.
        _resumeContribution = action == ContributionCardAction.join &&
            journeyStarted &&
            _action(context) != null &&
            _action(context) != ContributionCardAction.join;
        return;
      }
      // Recheck after the asynchronous gate; no stale role or wallet authority.
      final current = _action(context);
      switch (current) {
        case ContributionCardAction.artwork:
          await CreatorShellNavigation.openArtworkCreatorWorkspace(context);
        case ContributionCardAction.exhibition:
          await CreatorShellNavigation.openExhibitionCreatorWorkspace(context);
        case ContributionCardAction.document:
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const MarkerEditorScreen(marker: null, isNew: true),
          ));
        case ContributionCardAction.application:
          final wallet =
              context.read<WalletProvider>().currentWalletAddress ?? '';
          final review =
              context.read<DAOProvider>().findReviewForWallet(wallet);
          final shell = DesktopShellScope.of(context);
          final Widget screen = review?.isInstitutionApplication == true
              ? InstitutionHub(embedded: shell != null)
              : ArtistStudio(embedded: shell != null);
          if (shell != null) {
            shell.pushScreen(screen);
          } else {
            await Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => screen));
          }
        case ContributionCardAction.join:
        case null:
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProfileProvider>();
    context.watch<WalletProvider>();
    context.watch<DAOProvider>();
    final action = _action(context);
    if (_resumeContribution &&
        action != null &&
        action != ContributionCardAction.join &&
        ModalRoute.of(context)?.isCurrent == true) {
      _resumeContribution = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activate();
      });
    }
    if (action == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.contributionHeadline,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: KubusSpacing.xs),
        Text(l10n.contributionBody,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: roles.foregroundMuted)),
        const SizedBox(height: KubusSpacing.sm),
        KubusActionTile(
            title: _label(l10n, action),
            icon: Icons.add,
            accent: roles.active,
            layout: KubusActionTileLayout.compact,
            loading: _busy,
            onTap: _activate),
      ]),
    );
  }
}
