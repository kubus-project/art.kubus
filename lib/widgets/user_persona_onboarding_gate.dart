import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/profile_provider.dart';
import '../services/onboarding_state_service.dart';
import 'user_persona_onboarding_sheet.dart';

/// Presents the persona onboarding sheet once per wallet when needed.
///
/// This is a UI hinting mechanism (it does not block access).
class UserPersonaOnboardingGate extends StatefulWidget {
  final Widget child;

  const UserPersonaOnboardingGate({super.key, required this.child});

  @override
  State<UserPersonaOnboardingGate> createState() => _UserPersonaOnboardingGateState();
}

class _UserPersonaOnboardingGateState extends State<UserPersonaOnboardingGate> {
  bool _isShowing = false;
  bool _isChecking = false;
  String? _lastWallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_maybeShow());
  }

  @override
  void didUpdateWidget(covariant UserPersonaOnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_isShowing || _isChecking) return;
    _isChecking = true;

    try {
      final profile = context.read<ProfileProvider>();
      final wallet = profile.currentUser?.walletAddress;
      if (wallet == null || wallet.isEmpty) return;

      if (_lastWallet != wallet) {
        _lastWallet = wallet;
      }

      if (!profile.needsPersonaOnboarding) return;

      final prefs = await SharedPreferences.getInstance();
      final flowScopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
        walletAddress: wallet,
        userId: (prefs.getString('user_id') ?? '').trim(),
      );
      if (OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: flowScopeKey,
      )) {
        return;
      }

      _isShowing = true;
      // Persist that we already surfaced this onboarding prompt so it doesn't
      // repeatedly re-open if the user dismisses it.
      unawaited(profile.markPersonaOnboardingSeen(walletAddress: wallet));
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const UserPersonaOnboardingSheet(),
          );
        } finally {
          if (mounted) {
            setState(() => _isShowing = false);
          } else {
            _isShowing = false;
          }
        }
      });
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
