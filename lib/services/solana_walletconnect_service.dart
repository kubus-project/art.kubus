import 'package:flutter/foundation.dart';

import 'external_wallet_signer_service.dart';

/// Compatibility wrapper for older WalletConnect call sites.
///
/// The app no longer acts as a wallet-side WalletKit signer. External wallet
/// readiness is owned by [ExternalWalletSignerService] and then bound into
/// WalletProvider as an external signer.
class SolanaWalletConnectService {
  SolanaWalletConnectService._internal();

  static final SolanaWalletConnectService instance =
      SolanaWalletConnectService._internal();

  final ExternalWalletSignerService _externalSigner =
      ExternalWalletSignerService.instance;

  Function(String address)? onConnected;
  Function(String? reason)? onDisconnected;
  Function(String error)? onError;

  bool get isInitialized => true;
  bool get isConnected => _externalSigner.isConnected;
  String? get connectedAddress => _externalSigner.connectedAddress;

  void updateActiveWalletAddress(String? address) {
    // External wallet state is address-bound by WalletProvider. This method is
    // retained so older wallet identity updates do not create signer semantics.
  }

  Future<void> initialize() async {
    // Initialization requires a BuildContext and is triggered by WalletProvider
    // during the external-wallet connect flow.
  }

  Future<void> pair(String uri) async {
    final trimmed = uri.trim();
    if (trimmed.isEmpty) {
      onError?.call('WalletConnect URI is empty.');
      return;
    }
    if (kDebugMode) {
      debugPrint(
        'SolanaWalletConnectService: pasted WalletConnect URI ignored; use external wallet connect flow.',
      );
    }
    onError?.call('Use Connect external wallet to open a signer prompt.');
  }

  Future<void> disconnect() async {
    await _externalSigner.disconnect();
    onDisconnected?.call('External wallet disconnected');
  }
}
