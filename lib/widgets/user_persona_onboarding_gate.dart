import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_persona.dart';
import '../providers/account_verification_provider.dart';
import '../providers/profile_provider.dart';

/// Quietly reconciles the persona of established accounts. It never shows UI.
///
/// Account creation does not imply a role: a visitor who signs up to save, like,
/// follow or comment must land back where they were, not in a role picker. A
/// role is requested only by an action that needs one (the creator capability
/// scope in `OnboardingFlowScreen`) or by the user choosing to complete their
/// profile from settings.
///
/// What remains here is the silent half of the old behaviour: an account that is
/// already a verified artist, or a member of an institution, has the matching
/// persona saved without asking. The persona is only a preference; the standing
/// itself is the server's answer for the account.
class UserPersonaOnboardingGate extends StatefulWidget {
  final Widget child;

  const UserPersonaOnboardingGate({super.key, required this.child});

  @override
  State<UserPersonaOnboardingGate> createState() =>
      _UserPersonaOnboardingGateState();
}

class _UserPersonaOnboardingGateState extends State<UserPersonaOnboardingGate> {
  bool _isChecking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_inferPersonaFromVerification());
  }

  @override
  void didUpdateWidget(covariant UserPersonaOnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_inferPersonaFromVerification());
  }

  Future<void> _inferPersonaFromVerification() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final profile = context.read<ProfileProvider>();
      if (!profile.isSignedIn) return;
      if (!profile.needsPersonaOnboarding) return;

      AccountVerificationProvider? verification;
      try {
        // Listening, so the persona follows the standing once it is read.
        verification = Provider.of<AccountVerificationProvider>(context);
      } catch (_) {
        verification = null; // Not registered in some embeddings/tests.
      }
      if (verification == null || !verification.isReady) return;

      final UserPersona? inferred = verification.isArtist
          ? UserPersona.creator
          : verification.hasInstitutionAccess
              ? UserPersona.institution
              : null;
      if (inferred == null) return;

      unawaited(profile.setUserPersona(inferred));
      unawaited(profile.markPersonaOnboardingSeen(
        walletAddress: profile.currentUser?.walletAddress,
      ));
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
