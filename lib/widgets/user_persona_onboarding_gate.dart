import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
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
  String? _lastWallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeShow();
  }

  @override
  void didUpdateWidget(covariant UserPersonaOnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeShow();
  }

  void _maybeShow() {
    if (_isShowing) return;

    final profile = context.read<ProfileProvider>();
    final wallet = profile.currentUser?.walletAddress;
    if (wallet == null || wallet.isEmpty) return;

    if (_lastWallet != wallet) {
      _lastWallet = wallet;
    }

    if (!profile.needsPersonaOnboarding) return;

    _isShowing = true;
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
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
