import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/auth/security_setup_screen.dart';

class PostAuthSecuritySetupService {
  const PostAuthSecuritySetupService();

  bool shouldEnforceOnThisDevice() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> ensurePostAuthSecuritySetup({
    required NavigatorState navigator,
    required WalletProvider walletProvider,
    required SecurityGateProvider securityGateProvider,
  }) async {
    if (!shouldEnforceOnThisDevice()) return true;
    try {
      await securityGateProvider.reloadSettings();
    } catch (_) {}
    final hasPin = await walletProvider.hasPin();
    if (!navigator.mounted) return false;
    if (hasPin) return true;

    final result = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => const SecuritySetupScreen(),
        settings: const RouteSettings(name: '/security-setup'),
      ),
    );

    if (!navigator.mounted) return false;
    return result == true;
  }
}
