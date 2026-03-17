import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';
import 'solana_wallet_service.dart';

/// Real WalletConnect v2 service for Solana wallet connections using Reown WalletKit
/// Replaces the discontinued walletconnect_flutter_v2 package
class SolanaWalletConnectService {
  static SolanaWalletConnectService? _instance;
  static SolanaWalletConnectService get instance {
    _instance ??= SolanaWalletConnectService._internal();
    return _instance!;
  }

  final SolanaWalletService _solanaWalletService;

  SolanaWalletConnectService._internal({
    SolanaWalletService? solanaWalletService,
  }) : _solanaWalletService = solanaWalletService ?? SolanaWalletService();

  ReownWalletKit? _walletKit;
  bool _isInitialized = false;

  // Session management
  SessionData? _currentSession;
  String? _connectedAddress;
  String? _activeWalletAddress;

  // Event callbacks
  Function(String address)? onConnected;
  Function(String? reason)? onDisconnected;
  Function(String error)? onError;

  bool get isInitialized => _isInitialized;

  /// Initialize WalletConnect with project ID from API keys
  /// Get a project ID from https://cloud.reown.com/
  Future<void> initialize() async {
    try {
      final projectId = ApiKeys.walletConnectProjectId;

      // Validate project ID
      if (projectId.isEmpty || projectId == 'YOUR_WALLETCONNECT_PROJECT_ID') {
        throw Exception(
            'WalletConnect project ID not configured. Please set WALLETCONNECT_PROJECT_ID environment variable.');
      }

      final walletKit = ReownWalletKit(
        core: ReownCore(
          projectId: projectId,
          logLevel: kDebugMode ? LogLevel.debug : LogLevel.error,
        ),
        metadata: const PairingMetadata(
          name: 'art.kubus',
          description: 'Augmented Reality NFT Gallery',
          url: 'https://art.kubus.com',
          icons: ['https://art.kubus.com/logo.png'],
        ),
      );
      _walletKit = walletKit;

      // Initialize the wallet kit
      await walletKit.init();

      // Set up event listeners
      _setupEventListeners();

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: initialization failed: $e');
      }
      onError?.call('Failed to initialize WalletConnect: $e');
      rethrow;
    }
  }

  /// Set up event listeners for WalletConnect sessions
  void _setupEventListeners() {
    final walletKit = _walletKit;
    if (walletKit == null) return;
    // Session proposal event
    walletKit.onSessionProposal.subscribe((args) async {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: session proposal received');
      }

      final proposal = args.params;

      // Check if it's a Solana session
      final solanaNamespace = proposal.requiredNamespaces['solana'];
      if (solanaNamespace != null) {
        await _approveSession(args.id, proposal);
      } else {
        await _rejectSession(args.id, 'Unsupported blockchain');
      }
    });

    // Session request event (for signing transactions/messages)
    walletKit.onSessionRequest.subscribe((args) async {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: session request received');
      }
      await _handleSessionRequest(args);
    });

    // Session delete event
    walletKit.onSessionDelete.subscribe((args) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: session deleted');
      }
      _currentSession = null;
      _connectedAddress = null;
      onDisconnected?.call('Session deleted by dApp');
    });

    // Session expire event
    walletKit.onSessionExpire.subscribe((args) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: session expired');
      }
      _currentSession = null;
      _connectedAddress = null;
      onDisconnected?.call('Session expired');
    });
  }

  /// Update the wallet address that will be exposed to connected dApps
  void updateActiveWalletAddress(String? address) {
    if (address == null || address.isEmpty) {
      _activeWalletAddress = null;
      return;
    }
    _activeWalletAddress = address;
  }

  /// Approve a session proposal
  Future<void> _approveSession(int id, ProposalData proposal) async {
    try {
      final solanaAddress = _activeWalletAddress;
      if (solanaAddress == null || solanaAddress.isEmpty) {
        throw Exception(
            'No wallet address configured for WalletConnect session');
      }
      if (!_solanaWalletService.hasActiveKeyPair) {
        throw Exception('WalletConnect requires an active local signer');
      }
      final activeSignerAddress =
          (_solanaWalletService.activePublicKey ?? '').trim();
      if (activeSignerAddress.isNotEmpty &&
          activeSignerAddress != solanaAddress) {
        throw Exception('Active signer does not match the selected wallet');
      }
      final walletKit = _walletKit;
      if (walletKit == null || !_isInitialized) {
        throw Exception('WalletConnect not initialized');
      }

      final sessionData = await walletKit.approveSession(
        id: id,
        namespaces: {
          'solana': Namespace(
            accounts: [
              'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp:$solanaAddress'
            ],
            methods: [
              'solana_signTransaction',
              'solana_signMessage',
              'solana_signAndSendTransaction',
            ],
            events: ['accountsChanged', 'chainChanged'],
          ),
        },
      );

      _currentSession = sessionData.session;
      _connectedAddress = solanaAddress;

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: session approved');
      }

      onConnected?.call(solanaAddress);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: approve session failed: $e');
      }
      await _rejectSession(id, e.toString());
      onError?.call('Failed to approve session: $e');
    }
  }

  /// Reject a session proposal
  Future<void> _rejectSession(int id, String reason) async {
    try {
      final walletKit = _walletKit;
      if (walletKit == null || !_isInitialized) return;
      await walletKit.rejectSession(
        id: id,
        reason: ReownSignError(
          code: 5000,
          message: reason,
        ),
      );

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: session rejected: $reason');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: reject session failed: $e');
      }
    }
  }

  /// Handle session requests (transaction signing, message signing, etc.)
  Future<void> _handleSessionRequest(SessionRequestEvent args) async {
    final walletKit = _walletKit;
    if (walletKit == null || !_isInitialized) {
      throw Exception('WalletConnect not initialized');
    }
    try {
      final request = args.params;
      final method = request.request.method;

      switch (method) {
        case 'solana_signMessage':
          await _handleSignMessage(args);
          break;
        case 'solana_signTransaction':
          await _handleSignTransaction(args);
          break;
        case 'solana_signAndSendTransaction':
          await _handleSignAndSendTransaction(args);
          break;
        default:
          await walletKit.respondSessionRequest(
            topic: request.topic,
            response: JsonRpcResponse(
              id: request.request.id,
              error: const JsonRpcError(
                code: 4001,
                message: 'Unsupported method',
              ),
            ),
          );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'SolanaWalletConnectService: handle session request failed: $e');
      }

      await walletKit.respondSessionRequest(
        topic: args.params.topic,
        response: JsonRpcResponse(
          id: args.params.request.id,
          error: JsonRpcError(
            code: 5000,
            message: 'Internal error: $e',
          ),
        ),
      );
    }
  }

  Future<void> _respondSuccess({
    required String topic,
    required int id,
    required Object result,
  }) async {
    final walletKit = _walletKit;
    if (walletKit == null || !_isInitialized) {
      throw Exception('WalletConnect not initialized');
    }
    await walletKit.respondSessionRequest(
      topic: topic,
      response: JsonRpcResponse(
        id: id,
        result: result,
      ),
    );
  }

  Future<void> _respondError({
    required String topic,
    required int id,
    required int code,
    required String message,
  }) async {
    final walletKit = _walletKit;
    if (walletKit == null || !_isInitialized) {
      throw Exception('WalletConnect not initialized');
    }
    await walletKit.respondSessionRequest(
      topic: topic,
      response: JsonRpcResponse(
        id: id,
        error: JsonRpcError(
          code: code,
          message: message,
        ),
      ),
    );
  }

  String _requireSigningAddress() {
    final configuredAddress = (_activeWalletAddress ?? '').trim();
    final signerAddress = (_solanaWalletService.activePublicKey ?? '').trim();

    if (!_solanaWalletService.hasActiveKeyPair || signerAddress.isEmpty) {
      throw Exception(
          'WalletConnect signing is unavailable without a local signer');
    }
    if (configuredAddress.isNotEmpty && configuredAddress != signerAddress) {
      throw Exception(
          'WalletConnect signer does not match the selected wallet');
    }
    return configuredAddress.isNotEmpty ? configuredAddress : signerAddress;
  }

  String _extractRequestPayload(
    SessionRequestEvent args, {
    required List<String> paramKeys,
  }) {
    final rawParams = args.params.request.params;
    if (rawParams is Map) {
      final params = Map<String, dynamic>.from(rawParams);
      for (final key in paramKeys) {
        final value = params[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }
    if (rawParams is List) {
      for (final entry in rawParams) {
        if (entry is String && entry.isNotEmpty) {
          return entry;
        }
        if (entry is Map) {
          final params = Map<String, dynamic>.from(entry);
          for (final key in paramKeys) {
            final value = params[key];
            if (value is String && value.isNotEmpty) {
              return value;
            }
          }
        }
      }
    }
    throw Exception('WalletConnect request missing ${paramKeys.join('/')}');
  }

  /// Handle message signing requests
  Future<void> _handleSignMessage(SessionRequestEvent args) async {
    try {
      final walletAddress = _requireSigningAddress();
      final message = _extractRequestPayload(
        args,
        paramKeys: const ['message', 'data'],
      );

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: signing message: $message');
      }

      final signature = await _solanaWalletService.signMessageBase64(message);
      await _respondSuccess(
        topic: args.params.topic,
        id: args.params.request.id,
        result: <String, dynamic>{
          'signature': signature,
          'publicKey': walletAddress,
        },
      );

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: message signed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: sign message failed: $e');
      }
      await _respondError(
        topic: args.params.topic,
        id: args.params.request.id,
        code: 4001,
        message: e.toString(),
      );
    }
  }

  /// Handle transaction signing requests
  Future<void> _handleSignTransaction(SessionRequestEvent args) async {
    try {
      _requireSigningAddress();
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: signing transaction');
      }

      final transaction = _extractRequestPayload(
        args,
        paramKeys: const ['transaction'],
      );
      final signedTransaction =
          await _solanaWalletService.signTransactionBase64(transaction);
      await _respondSuccess(
        topic: args.params.topic,
        id: args.params.request.id,
        result: <String, dynamic>{
          'transaction': signedTransaction,
        },
      );

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: transaction signed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: sign transaction failed: $e');
      }
      await _respondError(
        topic: args.params.topic,
        id: args.params.request.id,
        code: 4001,
        message: e.toString(),
      );
    }
  }

  /// Handle sign and send transaction requests
  Future<void> _handleSignAndSendTransaction(SessionRequestEvent args) async {
    try {
      _requireSigningAddress();
      if (kDebugMode) {
        debugPrint(
            'SolanaWalletConnectService: signing and sending transaction');
      }

      final transaction = _extractRequestPayload(
        args,
        paramKeys: const ['transaction'],
      );
      final signature =
          await _solanaWalletService.signAndSendTransactionBase64(transaction);
      await _respondSuccess(
        topic: args.params.topic,
        id: args.params.request.id,
        result: <String, dynamic>{
          'signature': signature,
        },
      );

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: transaction signed and sent');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'SolanaWalletConnectService: sign and send transaction failed: $e');
      }
      await _respondError(
        topic: args.params.topic,
        id: args.params.request.id,
        code: 4001,
        message: e.toString(),
      );
    }
  }

  /// Connect to a dApp using a pairing URI
  Future<void> pair(String uri) async {
    if (!_isInitialized) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      final walletKit = _walletKit;
      if (walletKit == null) {
        throw Exception('WalletConnect not initialized');
      }
      await walletKit.pair(uri: Uri.parse(uri));

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: pairing initiated');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: pair failed: $e');
      }
      onError?.call('Failed to pair: $e');
      rethrow;
    }
  }

  /// Disconnect from the current session
  Future<void> disconnect() async {
    if (_currentSession == null) {
      return;
    }

    try {
      final walletKit = _walletKit;
      if (walletKit == null || !_isInitialized) {
        _currentSession = null;
        _connectedAddress = null;
        onDisconnected?.call('WalletConnect not initialized');
        return;
      }
      await walletKit.disconnectSession(
        topic: _currentSession!.topic,
        reason: const ReownSignError(
          code: 6000,
          message: 'User disconnected',
        ),
      );

      _currentSession = null;
      _connectedAddress = null;

      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: disconnected');
      }

      onDisconnected?.call('User disconnected');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SolanaWalletConnectService: disconnect failed: $e');
      }
      onError?.call('Failed to disconnect: $e');
    }
  }

  /// Get current session info
  SessionData? get currentSession => _currentSession;

  /// Get connected wallet address
  String? get connectedAddress => _connectedAddress;

  /// Check if connected to a dApp
  bool get isConnected => _currentSession != null && _connectedAddress != null;

  /// Get all active sessions
  List<SessionData> get activeSessions {
    final walletKit = _walletKit;
    if (walletKit == null || !_isInitialized) return const <SessionData>[];
    return walletKit.sessions.getAll();
  }

  /// Dispose of the service
  void dispose() {
    _walletKit = null;
    _instance = null;
  }
}
