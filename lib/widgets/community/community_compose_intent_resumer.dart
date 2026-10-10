import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/community_hub_provider.dart';
import '../../services/contextual_auth_gate.dart';

/// Reopens a Community creation surface that a guest requested before they
/// went through sign-in.
///
/// The request is remembered by `ContextualAuthGate.onAuthJourneyStarted` in
/// [CommunityHubProvider]. Once [isSignedIn] becomes true, the intent is taken
/// exactly once and handed to [onResume] after the current frame, so the
/// composer or group form opens over the settled Community screen. Mobile and
/// desktop Community share this so their resume behaviour cannot drift.
class CommunityComposeIntentResumer extends StatelessWidget {
  const CommunityComposeIntentResumer({
    super.key,
    required this.isSignedIn,
    required this.onResume,
    required this.child,
  });

  final bool isSignedIn;
  final ValueChanged<CommunityComposeIntent> onResume;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasPending = context.select<CommunityHubProvider, bool>(
      (hub) => hub.hasPendingComposeIntent,
    );
    if (isSignedIn && hasPending) {
      final intent = context.read<CommunityHubProvider>().takeComposeIntent();
      if (intent != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          onResume(intent);
        });
      }
    }
    return child;
  }
}

/// Asks a guest for an account before a Community composer opens, the same on
/// mobile and desktop. A signed-in visitor with a usable profile passes
/// straight through. When they continue into sign-in, the requested surface is
/// remembered on [CommunityHubProvider] and reopened by
/// [CommunityComposeIntentResumer] once the account exists.
Future<bool> ensureCommunityComposeAccess(
  BuildContext context, {
  required CommunityComposeIntent intent,
  required String actionLabel,
  required String sourceScreen,
}) {
  final hub = context.read<CommunityHubProvider>();
  return const ContextualAuthGate().ensureAuthenticated(
    context,
    requirements: ProtectedActionRequirements.participant,
    actionLabel: actionLabel,
    returnRoute: '/community',
    sourceScreen: sourceScreen,
    onAuthJourneyStarted: () => hub.rememberComposeIntentForAuth(intent),
  );
}
