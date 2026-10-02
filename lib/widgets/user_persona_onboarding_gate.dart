import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dao.dart';
import '../models/user_persona.dart';
import '../providers/dao_provider.dart';
import '../providers/profile_provider.dart';

/// Quietly reconciles the persona of established accounts. It never shows UI.
///
/// Account creation does not imply a role: a visitor who signs up to save, like,
/// follow or comment must land back where they were, not in a role picker. A
/// role is requested only by an action that needs one (the creator capability
/// scope in `OnboardingFlowScreen`) or by the user choosing to complete their
/// profile from settings.
///
/// What remains here is the silent half of the old behaviour: older accounts
/// may carry their artist/institution role only as an approved DAO review, not
/// on the profile flags, so the matching persona is persisted without asking.
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
    unawaited(_inferPersonaFromApprovedReview());
  }

  @override
  void didUpdateWidget(covariant UserPersonaOnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_inferPersonaFromApprovedReview());
  }

  Future<void> _inferPersonaFromApprovedReview() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final profile = context.read<ProfileProvider>();
      final wallet = profile.currentUser?.walletAddress;
      if (wallet == null || wallet.isEmpty) return;
      if (!profile.needsPersonaOnboarding) return;

      DAOProvider? daoProvider;
      try {
        daoProvider = context.read<DAOProvider>();
      } catch (_) {
        daoProvider = null; // Not registered in some embeddings/tests.
      }
      final review = daoProvider?.findReviewForWallet(wallet);
      if (review == null || !review.isApproved) return;

      final inferred = review.isInstitutionApplication
          ? UserPersona.institution
          : review.isArtistApplication
              ? UserPersona.creator
              : null;
      if (inferred == null) return;

      unawaited(profile.setUserPersona(inferred));
      unawaited(profile.markPersonaOnboardingSeen(walletAddress: wallet));
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
