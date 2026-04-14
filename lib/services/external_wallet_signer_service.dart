import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../config/api_keys.dart';
import '../config/config.dart';
import '../utils/wallet_utils.dart';

class ExternalWalletConnectionResult {
  const ExternalWalletConnectionResult({
    required this.address,
    required this.walletName,
  });

  final String address;
  final String walletName;
}

class ExternalWalletSignerService {
  ExternalWalletSignerService._();

  static final ExternalWalletSignerService instance =
      ExternalWalletSignerService._();

  static const String callbackScheme = 'artkubus';
  static const String callbackHost = 'walletconnect';
  static const String callbackUri = '$callbackScheme://$callbackHost';
  static const String _solanaNamespace = 'solana';

  ReownAppKitModal? _modal;
  BuildContext? _context;
  ReownAppKitModal? _subscribedModal;
  String? _connectedAddress;
  String? _connectedWalletName;
  Completer<ExternalWalletConnectionResult>? _pendingConnection;

  String? get connectedAddress => _connectedAddress;
  String? get connectedWalletName => _connectedWalletName;
  bool get isConnected =>
      (_modal?.isConnected ?? false) &&
      (_connectedAddress ?? '').trim().isNotEmpty;

  Future<void> initialize(BuildContext context) async {
    final existing = _modal;
    if (existing != null && identical(_context, context)) {
      return;
    }

    _context = context;
    final projectId = ApiKeys.walletConnectProjectId.trim();
    if (projectId.isEmpty || projectId == 'YOUR_WALLETCONNECT_PROJECT_ID') {
      throw StateError('WalletConnect project ID is not configured.');
    }

    final modal = ReownAppKitModal(
      context: context,
      projectId: projectId,
      metadata: const PairingMetadata(
        name: 'art.kubus',
        description: 'Noncustodial art.kubus wallet signing',
        url: 'https://app.kubus.site',
        icons: ['https://app.kubus.site/icons/Icon-512.png'],
        redirect: Redirect(
          native: callbackUri,
          universal: 'https://app.kubus.site/walletconnect',
        ),
      ),
      optionalNamespaces: {
        _solanaNamespace: RequiredNamespace(
          chains: ReownAppKitModalNetworks.getAllSupportedNetworks(
            namespace: _solanaNamespace,
          ).map((network) => network.chainId).toList(),
          methods: NetworkUtils.defaultNetworkMethods[_solanaNamespace] ??
              const <String>[
                'solana_signMessage',
                'solana_signTransaction',
                'solana_signAllTransactions',
                'solana_signAndSendTransaction',
              ],
          events: NetworkUtils.defaultNetworkEvents[_solanaNamespace] ??
              const <String>[],
        ),
      },
      logLevel: kDebugMode ? LogLevel.error : LogLevel.nothing,
      enableAnalytics: AppConfig.enableAnalytics,
    );
    _modal = modal;
    await modal.init();
    _subscribe(modal);
    _syncFromModal(modal);
  }

  void _subscribe(ReownAppKitModal modal) {
    if (identical(_subscribedModal, modal)) return;
    _subscribedModal = modal;
    modal.onModalConnect.subscribe(_handleModalConnect);
    modal.onModalUpdate.subscribe(_handleModalConnect);
    modal.onModalDisconnect.subscribe(_handleModalDisconnect);
    modal.onModalError.subscribe(_handleModalError);
  }

  void _handleModalConnect(ModalConnect? event) {
    final modal = _modal;
    if (modal == null) return;
    final result = _syncFromModal(modal);
    if (result == null) return;
    final pending = _pendingConnection;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
    }
  }

  void _handleModalDisconnect(ModalDisconnect? event) {
    _connectedAddress = null;
    _connectedWalletName = null;
    final pending = _pendingConnection;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('External wallet disconnected.'));
    }
  }

  void _handleModalError(ModalError? event) {
    final pending = _pendingConnection;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        StateError(event?.message ?? 'External wallet connection failed.'),
      );
    }
  }

  ExternalWalletConnectionResult? _syncFromModal(ReownAppKitModal modal) {
    final session = modal.session;
    if (session == null) return null;

    final address = (session.getAddress(_solanaNamespace) ?? '').trim();
    if (address.isEmpty) return null;
    final walletName = (session.connectedWalletName ??
            modal.selectedWallet?.listing.name ??
            '')
        .trim();

    _connectedAddress = address;
    _connectedWalletName = walletName.isEmpty ? 'External wallet' : walletName;
    return ExternalWalletConnectionResult(
      address: address,
      walletName: _connectedWalletName!,
    );
  }

  Future<ExternalWalletConnectionResult> connect(BuildContext context) async {
    await initialize(context);
    final modal = _modal;
    if (modal == null) {
      throw StateError('External wallet signer is not initialized.');
    }

    final existing = _syncFromModal(modal);
    if (existing != null) return existing;

    final completer = Completer<ExternalWalletConnectionResult>();
    _pendingConnection = completer;
    await modal.openModalView();
    return completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        throw TimeoutException('External wallet approval timed out.');
      },
    );
  }

  Future<void> disconnect() async {
    final modal = _modal;
    _connectedAddress = null;
    _connectedWalletName = null;
    if (modal != null && modal.isConnected) {
      await modal.disconnect();
    }
  }

  Future<bool> dispatchEnvelope(Uri uri) async {
    if (!isWalletReturnUri(uri)) return false;
    final modal = _modal;
    if (modal == null) return false;
    final handled = await modal.dispatchEnvelope(uri.toString());
    _syncFromModal(modal);
    return handled;
  }

  bool isWalletReturnUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != callbackScheme) return false;
    final host = uri.host.toLowerCase();
    return host.isEmpty || host == callbackHost;
  }

  Future<String> signMessageBase64(String messageBase64) async {
    final modal = _requireConnectedModal();
    final chainId = _solanaChainId(modal);
    final result = await modal.request(
      topic: modal.session!.topic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'solana_signMessage',
        params: {
          'message': messageBase64,
          'pubkey': _connectedAddress,
        },
      ),
    );
    return _extractSignature(result);
  }

  Future<String> signTransactionBase64(String transactionBase64) async {
    final modal = _requireConnectedModal();
    final chainId = _solanaChainId(modal);
    final result = await modal.request(
      topic: modal.session!.topic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'solana_signTransaction',
        params: {
          'transaction': transactionBase64,
          'pubkey': _connectedAddress,
          'feePayer': _connectedAddress,
        },
      ),
    );
    return _extractTransaction(result);
  }

  Future<String> signAndSendTransactionBase64(String transactionBase64) async {
    final modal = _requireConnectedModal();
    final chainId = _solanaChainId(modal);
    final result = await modal.request(
      topic: modal.session!.topic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'solana_signAndSendTransaction',
        params: {
          'transaction': transactionBase64,
          'pubkey': _connectedAddress,
          'feePayer': _connectedAddress,
        },
      ),
    );
    return _extractSignature(result);
  }

  ReownAppKitModal _requireConnectedModal() {
    final modal = _modal;
    if (modal == null || modal.session == null || !isConnected) {
      throw StateError('External wallet signer is not connected.');
    }
    return modal;
  }

  String _solanaChainId(ReownAppKitModal modal) {
    final selected = (modal.selectedChain?.chainId ?? '').trim();
    if (selected.contains(':')) return selected;
    if (selected.isNotEmpty) return '$_solanaNamespace:$selected';

    final sessionChain = (modal.session?.chainId ?? '').trim();
    if (sessionChain.contains(':')) return sessionChain;
    if (sessionChain.isNotEmpty) return '$_solanaNamespace:$sessionChain';

    final currentNetwork = ApiKeys.defaultSolanaNetwork.toLowerCase();
    final cluster = switch (currentNetwork) {
      'mainnet' || 'mainnet-beta' => '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp',
      'testnet' => '4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z',
      _ => 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
    };
    return '$_solanaNamespace:$cluster';
  }

  String _extractSignature(dynamic result) {
    final parsed = _extractStringValue(
      result,
      const ['signature', 'txid', 'hash', 'result'],
    );
    if (parsed != null) return parsed;
    if (result is String && result.trim().isNotEmpty) return result.trim();
    throw StateError('External wallet did not return a signature.');
  }

  String _extractTransaction(dynamic result) {
    final parsed = _extractStringValue(
      result,
      const [
        'transaction',
        'signedTransaction',
        'signed_transaction',
        'result'
      ],
    );
    if (parsed != null) return parsed;
    if (result is String && result.trim().isNotEmpty) return result.trim();
    throw StateError('External wallet did not return a signed transaction.');
  }

  String? _extractStringValue(dynamic result, List<String> keys) {
    if (result is Map) {
      for (final key in keys) {
        final value = result[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      final data = result['data'];
      if (data is Map) {
        return _extractStringValue(data, keys);
      }
    }
    if (result is List && result.isNotEmpty) {
      return _extractStringValue(result.first, keys);
    }
    if (result is String) {
      final trimmed = result.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return _extractStringValue(jsonDecode(trimmed), keys);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  bool matchesCanonicalWallet(String? canonicalWallet) {
    final expected = (canonicalWallet ?? '').trim();
    final connected = (_connectedAddress ?? '').trim();
    if (expected.isEmpty || connected.isEmpty) return false;
    return WalletUtils.equals(expected, connected);
  }
}
