import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/api_keys.dart';
import '../utils/wallet_utils.dart';
import 'browser_solana_wallet_service.dart';
import 'external_wallet_modal_connector.dart';
import 'external_wallet_reown_connector.dart' deferred as reown_connector;

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

  static const String callbackScheme = kExternalWalletCallbackScheme;
  static const String callbackHost = kExternalWalletCallbackHost;
  static const String callbackUri = kExternalWalletCallbackUri;
  static const String _solanaNamespace = 'solana';

  BrowserSolanaWalletService _browserWalletService =
      createBrowserSolanaWalletService();

  // The Reown/WalletConnect stack is by far the largest optional dependency
  // in the web bundle, but it is only needed once a user connects an
  // external wallet. It lives behind a deferred import so dart2js splits it
  // out of main.dart.js; [_loadModalConnector] pulls the part in on demand.
  ExternalWalletModalConnector? _modalConnector;
  Future<void>? _connectorLibraryLoad;
  BuildContext? _context;
  String? _connectedAddress;
  String? _connectedWalletName;
  Completer<ExternalWalletConnectionResult>? _pendingConnection;
  _ExternalWalletConnectorMode _connectorMode =
      _ExternalWalletConnectorMode.none;

  String? get connectedAddress => _connectedAddress;
  String? get connectedWalletName => _connectedWalletName;
  bool get isConnected {
    final connectedAddress = (_connectedAddress ?? '').trim();
    if (connectedAddress.isEmpty) return false;
    if (_connectorMode == _ExternalWalletConnectorMode.browserInjected) {
      return true;
    }
    return _modalConnector?.isConnected ?? false;
  }

  @visibleForTesting
  void replaceBrowserWalletService(BrowserSolanaWalletService service) {
    _browserWalletService = service;
    _connectedAddress = null;
    _connectedWalletName = null;
    _connectorMode = _ExternalWalletConnectorMode.none;
  }

  @visibleForTesting
  void resetBrowserWalletService() {
    _browserWalletService = createBrowserSolanaWalletService();
    _connectedAddress = null;
    _connectedWalletName = null;
    _connectorMode = _ExternalWalletConnectorMode.none;
  }

  Future<ExternalWalletModalConnector> _loadModalConnector() async {
    final existing = _modalConnector;
    if (existing != null) return existing;
    try {
      await (_connectorLibraryLoad ??= reown_connector.loadLibrary());
    } catch (e) {
      _connectorLibraryLoad = null;
      throw StateError('Wallet connector failed to load: $e');
    }
    return _modalConnector ??= reown_connector.createReownConnector();
  }

  Future<void> initialize(BuildContext context) async {
    if (_modalConnector != null && identical(_context, context)) {
      return;
    }

    _context = context;
    final connector = await _loadModalConnector();
    if (!context.mounted) return;
    await connector.initialize(
      context,
      ExternalWalletModalCallbacks(
        onConnectOrUpdate: _handleModalConnectOrUpdate,
        onDisconnect: _handleModalDisconnect,
        onError: _handleModalError,
      ),
    );
    _syncFromConnector();
  }

  void _handleModalConnectOrUpdate() {
    final result = _syncFromConnector();
    if (result == null) return;
    final pending = _pendingConnection;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
    }
  }

  void _handleModalDisconnect() {
    if (_connectorMode == _ExternalWalletConnectorMode.reownModal) {
      _connectedAddress = null;
      _connectedWalletName = null;
      _connectorMode = _ExternalWalletConnectorMode.none;
    }
    final pending = _pendingConnection;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('External wallet disconnected.'));
    }
  }

  void _handleModalError(String? message) {
    final pending = _pendingConnection;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        StateError(message ?? 'External wallet connection failed.'),
      );
    }
  }

  ExternalWalletConnectionResult? _syncFromConnector() {
    final session = _modalConnector?.currentSession();
    if (session == null) return null;

    final walletName = session.walletName.trim();
    _connectorMode = _ExternalWalletConnectorMode.reownModal;
    _connectedAddress = session.address;
    _connectedWalletName = walletName.isEmpty ? 'External wallet' : walletName;
    return ExternalWalletConnectionResult(
      address: session.address,
      walletName: _connectedWalletName!,
    );
  }

  Future<ExternalWalletConnectPlan> prepareConnectionPlan(
    BuildContext context,
  ) async {
    if (!kIsWeb) {
      return buildExternalWalletConnectPlan(
        isWeb: false,
        browserWallets: const <BrowserSolanaWalletDefinition>[],
        reownAvailable: ApiKeys.hasWalletConnectProjectId,
      );
    }

    final reownAvailable = ApiKeys.hasWalletConnectProjectId;
    List<BrowserSolanaWalletDefinition> browserWallets;
    try {
      browserWallets = await _browserWalletService.discoverCompatibleWallets();
    } catch (error) {
      _log(
        'browser wallet discovery failed: $error; '
        '${reownAvailable ? 'using Reown fallback' : 'no fallback available'}',
      );
      browserWallets = const <BrowserSolanaWalletDefinition>[];
    }
    final plan = buildExternalWalletConnectPlan(
      isWeb: true,
      browserWallets: browserWallets,
      reownAvailable: reownAvailable,
    );
    _log(
      'prepared web connection plan ${plan.route.name} '
      '(${browserWallets.length} injected wallet(s))',
    );
    return plan;
  }

  Future<ExternalWalletConnectionResult> connect(
    BuildContext context, {
    String? browserWalletId,
    bool preferBrowserWallet = true,
  }) async {
    if (kIsWeb && preferBrowserWallet) {
      final plan = await prepareConnectionPlan(context);
      final selectedWalletId =
          (browserWalletId ?? plan.preferredBrowserWallet?.id ?? '').trim();
      if (selectedWalletId.isNotEmpty) {
        try {
          return await _connectBrowserWallet(
            walletId: selectedWalletId,
            chainId: _solanaChainId(),
          );
        } catch (error) {
          if (!plan.reownAvailable) rethrow;
          _log(
            'browser wallet $selectedWalletId failed: $error; '
            'falling back to Reown modal',
          );
        }
      } else if (plan.route ==
          ExternalWalletConnectRoute.browserWalletChooser) {
        throw StateError('Select a browser wallet before continuing.');
      }
    }

    if (!context.mounted) {
      throw StateError('External wallet context is no longer mounted.');
    }
    if (!ApiKeys.hasWalletConnectProjectId) {
      throw StateError('The Reown wallet fallback is not configured.');
    }
    await initialize(context);
    final connector = _modalConnector;
    if (connector == null) {
      throw StateError('External wallet signer is not initialized.');
    }

    final existing = _syncFromConnector();
    if (existing != null) return existing;

    _connectorMode = _ExternalWalletConnectorMode.reownModal;
    final completer = Completer<ExternalWalletConnectionResult>();
    _pendingConnection = completer;
    await connector.openModalView();
    return completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        throw TimeoutException('External wallet approval timed out.');
      },
    );
  }

  Future<void> disconnect() async {
    final connector = _modalConnector;
    _connectedAddress = null;
    _connectedWalletName = null;
    final connectorMode = _connectorMode;
    _connectorMode = _ExternalWalletConnectorMode.none;
    if (connectorMode == _ExternalWalletConnectorMode.browserInjected) {
      await _browserWalletService.disconnect();
    }
    if (connector != null && connector.isConnected) {
      await connector.disconnect();
    }
  }

  Future<bool> dispatchEnvelope(Uri uri) async {
    if (!isWalletReturnUri(uri)) return false;
    // No connector means no connection was initiated this session; nothing
    // can consume the envelope, so don't pull the deferred library in.
    final connector = _modalConnector;
    if (connector == null) return false;
    final handled = await connector.dispatchEnvelope(uri.toString());
    _syncFromConnector();
    return handled;
  }

  bool isWalletReturnUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != callbackScheme) return false;
    final host = uri.host.toLowerCase();
    return host.isEmpty || host == callbackHost;
  }

  Future<String> signMessageBase64(String messageBase64) async {
    if (_connectorMode == _ExternalWalletConnectorMode.browserInjected) {
      return _browserWalletService.signMessageBase64(messageBase64);
    }
    final connector = _requireConnectedConnector();
    final result = await connector.requestSolana(
      method: 'solana_signMessage',
      params: {
        'message': messageBase64,
        'pubkey': _connectedAddress,
      },
    );
    return _extractSignature(result);
  }

  Future<String> signTransactionBase64(String transactionBase64) async {
    if (_connectorMode == _ExternalWalletConnectorMode.browserInjected) {
      return _browserWalletService.signTransactionBase64(
        transactionBase64: transactionBase64,
        chainId: _solanaChainId(),
      );
    }
    final connector = _requireConnectedConnector();
    final result = await connector.requestSolana(
      method: 'solana_signTransaction',
      params: {
        'transaction': transactionBase64,
        'pubkey': _connectedAddress,
        'feePayer': _connectedAddress,
      },
    );
    return _extractTransaction(result);
  }

  Future<String> signAndSendTransactionBase64(String transactionBase64) async {
    if (_connectorMode == _ExternalWalletConnectorMode.browserInjected) {
      return _browserWalletService.signAndSendTransactionBase64(
        transactionBase64: transactionBase64,
        chainId: _solanaChainId(),
      );
    }
    final connector = _requireConnectedConnector();
    final result = await connector.requestSolana(
      method: 'solana_signAndSendTransaction',
      params: {
        'transaction': transactionBase64,
        'pubkey': _connectedAddress,
        'feePayer': _connectedAddress,
      },
    );
    return _extractSignature(result);
  }

  Future<ExternalWalletConnectionResult> _connectBrowserWallet({
    required String walletId,
    required String chainId,
  }) async {
    final result = await _browserWalletService.connect(
      walletId: walletId,
      chainId: chainId,
    );
    _connectorMode = _ExternalWalletConnectorMode.browserInjected;
    _connectedAddress = result.address;
    _connectedWalletName = result.walletName;
    return ExternalWalletConnectionResult(
      address: result.address,
      walletName: result.walletName,
    );
  }

  ExternalWalletModalConnector _requireConnectedConnector() {
    final connector = _modalConnector;
    if (connector == null || !isConnected) {
      throw StateError('External wallet signer is not connected.');
    }
    return connector;
  }

  String _solanaChainId() {
    final fromConnector = (_modalConnector?.solanaChainId() ?? '').trim();
    if (fromConnector.isNotEmpty) return fromConnector;

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

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('ExternalWalletSignerService: $message');
  }
}

enum _ExternalWalletConnectorMode {
  none,
  reownModal,
  browserInjected,
}
