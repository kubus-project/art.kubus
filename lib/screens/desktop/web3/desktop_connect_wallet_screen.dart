import 'package:flutter/material.dart';

import '../../web3/wallet/connectwallet_screen.dart';

/// Desktop-friendly wrapper for the shared wallet connect/create/import flow.
class DesktopConnectWalletScreen extends StatelessWidget {
  final int initialStep;
  final String? telemetryAuthFlow;
  final String? requiredWalletAddress;

  const DesktopConnectWalletScreen({
    super.key,
    this.initialStep = 0,
    this.telemetryAuthFlow,
    this.requiredWalletAddress,
  });

  @override
  Widget build(BuildContext context) {
    return ConnectWallet(
      initialStep: initialStep,
      telemetryAuthFlow: telemetryAuthFlow,
      requiredWalletAddress: requiredWalletAddress,
    );
  }
}
