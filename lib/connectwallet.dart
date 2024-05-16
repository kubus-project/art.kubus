import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

class ConnectWallet extends StatefulWidget {
  const ConnectWallet({super.key});

  @override
  State <ConnectWallet> createState() => _ConnectWalletState();
}

class _ConnectWalletState extends State<ConnectWallet> {
  EthereumAddress? _walletAddress; // Add a field for the wallet address

  Future<void> _connectWallet() async {
    // TODO: Connect to the user's wallet and get the wallet address
    // For example, you could use the flutter_web3 package to connect to the wallet

    // For demonstration purposes, show a snackbar with a connected message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet connected'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Connect Wallet',
          style: TextStyle(fontFamily: 'Sofia Sans', color: Colors.white),
        ),
      ),
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _connectWallet,
              child: const Text(
                'Connect Wallet',
                style: TextStyle(fontFamily: 'Sofia Sans'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
