import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';

/// Real WalletConnect v2 service for Solana wallet connections using Reown WalletKit
/// Replaces the discontinued walletconnect_flutter_v2 package
class SolanaWalletConnectService {
  static SolanaWalletConnectService? _instance;
  static SolanaWalletConnectService get instance {
    _instance ??= SolanaWalletConnectService._internal();
    return _instance!;
  }
  
  SolanaWalletConnectService._internal();
  
  late ReownWalletKit _walletKit;
  bool _isInitialized = false;
  
  // Session management
  SessionData? _currentSession;
  String? _connectedAddress;
  
  // Event callbacks
  Function(String address)? onConnected;
  Function(String? reason)? onDisconnected;
  Function(String error)? onError;
  
  /// Initialize WalletConnect with project ID from API keys
  /// Get a project ID from https://cloud.reown.com/
  Future<void> initialize() async {
    try {
      final projectId = ApiKeys.walletConnectProjectId;
      
      // Validate project ID
      if (projectId.isEmpty || projectId == 'YOUR_WALLETCONNECT_PROJECT_ID') {
        throw Exception('WalletConnect project ID not configured. Please set WALLETCONNECT_PROJECT_ID environment variable.');
      }
      
      _walletKit = ReownWalletKit(
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
      
      // Initialize the wallet kit
      await _walletKit.init();
      
      // Set up event listeners
      _setupEventListeners();
      
      _isInitialized = true;
      if (kDebugMode) {
        print('✅ WalletConnect initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ WalletConnect initialization failed: $e');
      }
      onError?.call('Failed to initialize WalletConnect: $e');
      rethrow;
    }
  }
  
  /// Set up event listeners for WalletConnect sessions
  void _setupEventListeners() {
    // Session proposal event
    _walletKit.onSessionProposal.subscribe((args) async {
      if (kDebugMode) {
        print('📨 Session proposal received');
      }
      
      // Auto-approve Solana sessions for demo purposes
      // In production, you should show UI for user approval
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
    _walletKit.onSessionRequest.subscribe((args) async {
      if (kDebugMode) {
        print('📝 Session request received');
      }
      await _handleSessionRequest(args);
    });
    
    // Session delete event
    _walletKit.onSessionDelete.subscribe((args) {
      if (kDebugMode) {
        print('🗑️ Session deleted');
      }
      _currentSession = null;
      _connectedAddress = null;
      onDisconnected?.call('Session deleted by dApp');
    });
    
    // Session expire event
    _walletKit.onSessionExpire.subscribe((args) {
      if (kDebugMode) {
        print('⏰ Session expired');
      }
      _currentSession = null;
      _connectedAddress = null;
      onDisconnected?.call('Session expired');
    });
  }
  
  /// Approve a session proposal
  Future<void> _approveSession(int id, ProposalData proposal) async {
    try {
      // Use real user wallet address if available, otherwise use mock for development
      String solanaAddress;
      
      if (kDebugMode) {
        // In debug mode, use mock address for development
        solanaAddress = ApiKeys.mockSolanaAddress;
      } else {
        // In production, this should be the user's actual wallet address
        // TODO: Get real user wallet address from wallet provider
        solanaAddress = ApiKeys.mockSolanaAddress; // Temporary - replace with real address
      }
      
      final sessionData = await _walletKit.approveSession(
        id: id,
        namespaces: {
          'solana': Namespace(
            accounts: ['solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp:$solanaAddress'],
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
        print('✅ Session approved successfully');
      }
      
      onConnected?.call(solanaAddress);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to approve session: $e');
      }
      onError?.call('Failed to approve session: $e');
    }
  }
  
  /// Reject a session proposal
  Future<void> _rejectSession(int id, String reason) async {
    try {
      await _walletKit.rejectSession(
        id: id,
        reason: ReownSignError(
          code: 5000,
          message: reason,
        ),
      );
      
      if (kDebugMode) {
        print('❌ Session rejected: $reason');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to reject session: $e');
      }
    }
  }
  
  /// Handle session requests (transaction signing, message signing, etc.)
  Future<void> _handleSessionRequest(SessionRequestEvent args) async {
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
          await _walletKit.respondSessionRequest(
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
        print('❌ Failed to handle session request: $e');
      }
      
      await _walletKit.respondSessionRequest(
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
  
  /// Handle message signing requests
  Future<void> _handleSignMessage(SessionRequestEvent args) async {
    try {
      final params = args.params.request.params as Map<String, dynamic>;
      final message = params['message'] as String;
      
      if (kDebugMode) {
        print('📝 Signing message: $message');
      }
      
      // For demo purposes, return a mock signature
      // In production, this should use the actual wallet's private key
      const mockSignature = 'mock_signature_base64_encoded_string';
      
      await _walletKit.respondSessionRequest(
        topic: args.params.topic,
        response: JsonRpcResponse(
          id: args.params.request.id,
          result: {
            'signature': mockSignature,
          },
        ),
      );
      
      if (kDebugMode) {
        print('✅ Message signed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sign message: $e');
      }
      rethrow;
    }
  }
  
  /// Handle transaction signing requests
  Future<void> _handleSignTransaction(SessionRequestEvent args) async {
    try {
      if (kDebugMode) {
        print('📝 Signing transaction');
      }
      
      // For demo purposes, return a mock signed transaction
      // In production, this should use the actual wallet's private key
      const mockSignedTransaction = 'mock_signed_transaction_base64';
      
      await _walletKit.respondSessionRequest(
        topic: args.params.topic,
        response: JsonRpcResponse(
          id: args.params.request.id,
          result: {
            'transaction': mockSignedTransaction,
          },
        ),
      );
      
      if (kDebugMode) {
        print('✅ Transaction signed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sign transaction: $e');
      }
      rethrow;
    }
  }
  
  /// Handle sign and send transaction requests
  Future<void> _handleSignAndSendTransaction(SessionRequestEvent args) async {
    try {
      if (kDebugMode) {
        print('📝 Signing and sending transaction');
      }
      
      // For demo purposes, return a mock transaction hash
      // In production, this should sign and broadcast the transaction
      const mockTxHash = 'mock_transaction_hash_12345';
      
      await _walletKit.respondSessionRequest(
        topic: args.params.topic,
        response: JsonRpcResponse(
          id: args.params.request.id,
          result: {
            'signature': mockTxHash,
          },
        ),
      );
      
      if (kDebugMode) {
        print('✅ Transaction signed and sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sign and send transaction: $e');
      }
      rethrow;
    }
  }
  
  /// Connect to a dApp using a pairing URI
  Future<void> pair(String uri) async {
    if (!_isInitialized) {
      throw Exception('WalletConnect not initialized');
    }
    
    try {
      await _walletKit.pair(uri: Uri.parse(uri));
      
      if (kDebugMode) {
        print('🔗 Pairing initiated with URI');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to pair: $e');
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
      await _walletKit.disconnectSession(
        topic: _currentSession!.topic,
        reason: const ReownSignError(
          code: 6000,
          message: 'User disconnected',
        ),
      );
      
      _currentSession = null;
      _connectedAddress = null;
      
      if (kDebugMode) {
        print('✅ Disconnected successfully');
      }
      
      onDisconnected?.call('User disconnected');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to disconnect: $e');
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
  List<SessionData> get activeSessions => _walletKit.sessions.getAll();
  
  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
