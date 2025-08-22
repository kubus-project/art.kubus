import 'package:flutter/material.dart';
import 'wallet/wallet_home.dart';

class Wallet extends StatelessWidget {
  const Wallet({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to the enhanced Wallet Home
    return const WalletHome();
  }
}
