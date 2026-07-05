/// Reown-free contract for the external wallet (WalletConnect) modal.
///
/// `package:reown_appkit` is one of the largest dependencies in the web
/// bundle, yet it is only exercised when a user explicitly connects an
/// external wallet. [ExternalWalletSignerService] loads the concrete
/// implementation (`external_wallet_reown_connector.dart`) through a
/// `deferred` import, so dart2js can split the whole Reown stack out of
/// `main.dart.js`. This file must therefore never import reown types.
library;

import 'package:flutter/widgets.dart';

/// Deep-link scheme/host used for wallet-return callbacks. Shared here so
/// both the signer service and the deferred Reown implementation can
/// reference them without importing each other.
const String kExternalWalletCallbackScheme = 'artkubus';
const String kExternalWalletCallbackHost = 'walletconnect';
const String kExternalWalletCallbackUri =
    '$kExternalWalletCallbackScheme://$kExternalWalletCallbackHost';

/// Snapshot of the connected modal session (solana namespace).
class ExternalWalletModalSession {
  const ExternalWalletModalSession({
    required this.address,
    required this.walletName,
  });

  final String address;
  final String walletName;
}

/// Callbacks the modal implementation raises back into the signer service.
class ExternalWalletModalCallbacks {
  const ExternalWalletModalCallbacks({
    required this.onConnectOrUpdate,
    required this.onDisconnect,
    required this.onError,
  });

  final void Function() onConnectOrUpdate;
  final void Function() onDisconnect;
  final void Function(String? message) onError;
}

abstract class ExternalWalletModalConnector {
  /// Whether the underlying modal reports an active connection.
  bool get isConnected;

  /// Initializes the modal for [context]. Safe to call repeatedly; the
  /// implementation re-initializes only when the context changes.
  Future<void> initialize(
    BuildContext context,
    ExternalWalletModalCallbacks callbacks,
  );

  /// Current session details, or null when there is no usable session.
  ExternalWalletModalSession? currentSession();

  /// Opens the wallet-selection modal UI.
  Future<void> openModalView();

  Future<void> disconnect();

  /// Forwards a wallet deep-link return payload. Returns whether it was
  /// handled by the modal engine.
  Future<bool> dispatchEnvelope(String uri);

  /// Fully-qualified solana chain id (`solana:<cluster>`) derived from the
  /// modal's selected chain/session, or null when unknown.
  String? solanaChainId();

  /// Issues a solana JSON-RPC style request over the connected session.
  Future<dynamic> requestSolana({
    required String method,
    required Map<String, dynamic> params,
  });
}
