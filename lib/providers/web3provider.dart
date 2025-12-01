import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart' hide Wallet; // Hide solana Wallet to avoid name clash with app model
import '../config/api_keys.dart';
import '../services/solana_wallet_service.dart';
import '../services/backend_api_service.dart';
import '../services/user_service.dart';
import '../models/wallet.dart';
import '../utils/wallet_utils.dart';

class Web3Provider extends ChangeNotifier {
  final SolanaWalletService _solanaService;
  final BackendApiService _apiService = BackendApiService();

  bool _isConnected = false;
  Wallet? _wallet; // Use unified Wallet model
  List<WalletTransaction> _transactions = [];
  Map<String, dynamic>? _backendProfile;
  int _collectionsCount = 0;
  int _achievementsUnlocked = 0;
  double _achievementTokenTotal = 0.0;

  // Configurable constants (KUB8 mint/address from ApiKeys)
  final String _kub8TokenAddress = ApiKeys.kub8MintAddress;

  // Initialization guards
  bool _initialized = false;
  bool _initializing = false;
  int _initializeCallCount = 0;

  // Error tracking
  String? _initializeError;

  Web3Provider({SolanaWalletService? solanaWalletService})
      : _solanaService = solanaWalletService ?? SolanaWalletService();

  // Getters
  bool get isConnected => _isConnected;
  Wallet? get wallet => _wallet;
  String get walletAddress => _wallet?.address ?? '';
  double get solBalance => _wallet?.getTokenBySymbol('SOL')?.balance ?? 0.0;
  double get kub8Balance => _wallet?.getTokenBySymbol('KUB8')?.balance ?? 0.0;
  String get currentNetwork => _solanaService.currentNetwork;
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);
  Map<String, dynamic>? get backendProfile => _backendProfile;
  int get collectionsCount => _collectionsCount;
  int get achievementsUnlocked => _achievementsUnlocked;
  double get achievementTokenTotal => _achievementTokenTotal;
  String get kub8TokenAddress => _kub8TokenAddress;
  // Add simple initialize / state flags so AppInitializer can await provider init
  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  String? get initializeError => _initializeError;

  // Network management
  void switchNetwork(String network) {
    _solanaService.switchNetwork(network);
    if (_isConnected && walletAddress.isNotEmpty) {
      _reloadWallet();
    }
    notifyListeners();
  }

  Future<void> _loadSavedNetworkPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedNetwork = prefs.getString('networkSelection');
      final targetNetwork = (savedNetwork == null || savedNetwork.isEmpty)
          ? ApiKeys.defaultSolanaNetwork
          : savedNetwork;
      _solanaService.switchNetwork(targetNetwork);
      debugPrint('Web3Provider: applied saved network -> $targetNetwork');
    } catch (e, st) {
      debugPrint('Web3Provider: failed to load saved network preference: $e\n$st');
    }
  }

  Future<void> initialize({bool attemptRestore = true}) async {
    _initializeCallCount++;
    if (_initialized || _initializing) {
      debugPrint('Web3Provider.initialize skipped: already initialized or initializing (#$_initializeCallCount)');
      return;
    }
    _initializing = true;
    _initializeError = null;
    debugPrint('Web3Provider.initialize: start (#$_initializeCallCount), attemptRestore=$attemptRestore');
    try {
      await _loadSavedNetworkPreference();
      if (attemptRestore) {
        try {
          final dynamic dynamicSol = _solanaService;
          if (dynamicSol != null) {
            try {
              final String? savedPubKey = await dynamicSol.getActivePublicKey();
              if (savedPubKey != null && savedPubKey.isNotEmpty) {
                debugPrint('Web3Provider.initialize: restoring wallet $savedPubKey');
                await _initializeWallet(savedPubKey, suppressErrors: true);
              }
            } catch (e, st) {
              debugPrint('Web3Provider.initialize: restore attempt not possible or failed: $e\n$st');
              // Do not rethrow - it's a best-effort restore
            }
          }
        } catch (e, st) {
          debugPrint('Web3Provider.initialize: restore attempt top-level failure: $e\n$st');
        }
      }
    } catch (e, st) {
      _initializeError = e.toString();
      debugPrint('Web3Provider.initialize error: $e\n$st');
    } finally {
      _initialized = true;
      _initializing = false;
      debugPrint('Web3Provider.initialize: done (#$_initializeCallCount)');
      notifyListeners();
    }
  }

  // Wallet connection (mnemonic based for now)
  Future<String> createWallet() async {
    final mnemonic = _solanaService.generateMnemonic();
    final keyPair = await _solanaService.generateKeyPairFromMnemonic(
      mnemonic,
      accountIndex: 0,
      changeIndex: 0,
      pathType: DerivationPathType.standard,
    );
    final hdKeyPair = await Ed25519HDKeyPair.fromMnemonic(
      mnemonic,
      account: 0,
      change: 0,
    );
    _solanaService.setActiveKeyPair(hdKeyPair);
    await _initializeWallet(keyPair.publicKey); // explicit user action - allow rethrow
    return keyPair.publicKey;
  }

  Future<void> importWallet(
    String mnemonic, {
    int? accountIndex,
    int? changeIndex,
    DerivationPathType? pathType,
  }) async {
    if (mnemonic.trim().isEmpty) {
      throw ArgumentError('Mnemonic cannot be empty');
    }

    DerivedKeyPairResult derived;

    if (accountIndex != null || changeIndex != null || pathType != null) {
      final resolvedAccount = accountIndex ?? 0;
      final resolvedChange = changeIndex ?? 0;
      final resolvedPath = pathType ?? DerivationPathType.standard;
      final solanaKeyPair = await _solanaService.generateKeyPairFromMnemonic(
        mnemonic,
        accountIndex: resolvedAccount,
        changeIndex: resolvedChange,
        pathType: resolvedPath,
      );
      final hdKeyPair = await (resolvedPath == DerivationPathType.legacy
          ? Ed25519HDKeyPair.fromMnemonic(
              mnemonic,
              account: resolvedAccount,
            )
          : Ed25519HDKeyPair.fromMnemonic(
              mnemonic,
              account: resolvedAccount,
              change: resolvedChange,
            ));
      derived = DerivedKeyPairResult(
        keyPair: solanaKeyPair,
        hdKeyPair: hdKeyPair,
        pathType: resolvedPath,
        accountIndex: resolvedAccount,
        changeIndex: resolvedChange,
      );
    } else {
      derived = await _solanaService.derivePreferredKeyPair(mnemonic);
    }

    _solanaService.setActiveKeyPair(derived.hdKeyPair);
    await _initializeWallet(derived.address); // explicit user action - allow rethrow
  }

  Future<void> connectExistingWallet(String publicKey) async {
    if (publicKey.trim().isEmpty) {
      debugPrint('Web3Provider.connectExistingWallet: empty publicKey, skipping init');
      return;
    }
    // Existing wallet without mnemonic cannot sign (read-only mode)
    await _initializeWallet(publicKey);
  }

  Future<void> _initializeWallet(String publicKey, {bool suppressErrors = false}) async {
    try {
      if (publicKey.trim().isEmpty) {
        throw ArgumentError('Public key cannot be empty');
      }
      _isConnected = true;
      await _reloadWallet(address: publicKey);
      await _syncBackend(publicKey);

      try {
        final issued = await BackendApiService().issueTokenForWallet(publicKey);
        debugPrint('Web3Provider._initializeWallet: backend token issuance for $publicKey -> $issued');
        if (issued) {
          await BackendApiService().loadAuthToken();
          debugPrint('Web3Provider._initializeWallet: Auth token loaded after issuance');
        }
      } catch (e, st) {
        debugPrint('Web3Provider._initializeWallet: token issuance failed: $e\n$st');
      }

      notifyListeners();
    } catch (e, st) {
      _isConnected = false;
      _initializeError = e.toString();
      debugPrint('Web3Provider: wallet init failed: $e\n$st');
      if (!suppressErrors) rethrow;
    }
  }

  void disconnectWallet() {
    _isConnected = false;
    _wallet = null;
    _transactions.clear();
    _backendProfile = null;
    _collectionsCount = 0;
    _achievementsUnlocked = 0;
    _achievementTokenTotal = 0.0;
    notifyListeners();
  }

  Future<void> updateBalances() async {
    if (!_isConnected || walletAddress.isEmpty) return;
    await _reloadWallet();
    notifyListeners();
  }

  // KUB8 token operations
  Future<String> sendKub8(String toAddress, double amount) async {
    if (!_isConnected || walletAddress.isEmpty) {
      throw Exception('Wallet not connected');
    }
    if (toAddress.trim().isEmpty) {
      throw ArgumentError('Recipient address cannot be empty');
    }
    try {
      final signature = await _solanaService.transferSplToken(
        mint: _kub8TokenAddress,
        toAddress: toAddress,
        amount: amount,
        decimals: 6,
      );
      await _reloadWallet();
      notifyListeners();
      return signature;
    } on UnimplementedError catch (e) {
      debugPrint('KUB8 transfer pending implementation: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('KUB8 transfer failed: $e\n$st');
      rethrow;
    }
  }

  Future<String> swapSolToKub8(double solAmount) async {
    if (!_isConnected || walletAddress.isEmpty) {
      throw Exception('Wallet not connected');
    }
    try {
      final signature = await _solanaService.swapSolToSpl(mint: _kub8TokenAddress, solAmount: solAmount);
      await _reloadWallet();
      notifyListeners();
      return signature;
    } on UnimplementedError catch (e) {
      debugPrint('Swap not yet implemented: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('Swap failed: $e\n$st');
      rethrow;
    }
  }

  // Governance functions
  Future<String> voteOnProposal(String proposalId, bool support) async {
    // Placeholder: integrate governance program or backend endpoint
    throw UnimplementedError('Governance voting integration pending');
  }

  // NFT functions
  Future<String> mintArtworkNFT(Map<String, dynamic> metadata) async {
    try {
      final signature = await _solanaService.mintNft(metadata: metadata);
      return signature;
    } catch (e, st) {
      debugPrint('NFT mint failed: $e\n$st');
      rethrow;
    }
  }

  // Transaction loading
  Future<void> _reloadWallet({String? address}) async {
    final pubKey = (address ?? walletAddress).trim();
    if (pubKey.isEmpty) return;

    try {
      final solBalance = await _solanaService.getBalance(pubKey);
      final splBalances = await _solanaService.getTokenBalances(pubKey);
      final txHistory = await _solanaService.getTransactionHistory(pubKey);

      // Build token list (SOL first)
      final tokens = <Token>[
        Token(
          id: 'sol_native',
          name: 'Solana',
          symbol: 'SOL',
          type: TokenType.native,
          balance: solBalance,
          value: solBalance * 50.0,
          changePercentage: 0.0,
          contractAddress: 'native',
          decimals: 9,
          logoUrl: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
          network: 'Solana',
        ),
      ];

      final kub8Mint = WalletUtils.canonical(ApiKeys.kub8MintAddress);
      for (final b in splBalances) {
        final isKub8 = WalletUtils.equals(b.mint, kub8Mint);
        tokens.add(Token(
          id: 'spl_${b.mint}',
          name: b.name,
          symbol: b.symbol,
          type: isKub8 ? TokenType.governance : TokenType.erc20,
          balance: b.balance,
          value: b.balance * 1.0,
          changePercentage: 0.0,
          contractAddress: b.mint,
          decimals: b.decimals,
          logoUrl: b.logoUrl,
          network: 'Solana',
        ));
      }

      _transactions = txHistory.map((tx) => WalletTransaction(
        id: tx.signature,
        type: TransactionType.receive,
        token: 'SOL',
        amount: 0.0,
        fromAddress: null,
        toAddress: pubKey,
        timestamp: tx.blockTime,
        status: tx.status == 'success' ? TransactionStatus.confirmed : TransactionStatus.failed,
        txHash: tx.signature,
        gasUsed: tx.fee,
        gasFee: tx.fee,
        metadata: {'slot': tx.slot},
      )).toList();

      _wallet = Wallet(
        id: 'wallet_${pubKey.substring(0,8)}',
        address: pubKey,
        name: 'Solana Wallet',
        network: 'Solana',
        tokens: tokens,
        transactions: _transactions,
        totalValue: tokens.fold(0.0, (sum, t) => sum + t.value),
        lastUpdated: DateTime.now(),
      );
    } catch (e, st) {
      // Log and mark wallet as disconnected if reload fails during restore
      debugPrint('Web3Provider._reloadWallet failed for $pubKey: $e\n$st');
      _isConnected = false;
      _wallet = null;
      _transactions.clear();
      // Do NOT rethrow when called during background initialization or restore
    }
  }

  // Backend sync
  Future<void> _syncBackend(String address) async {
    try {
        try {
          // Prefer cache-first UserService lookup to avoid unnecessary network calls
          final user = await UserService.getUserById(address, forceRefresh: true);
          if (user != null) {
            _backendProfile = {
              'walletAddress': user.id,
              'username': user.username.replaceFirst('@', ''),
              'displayName': user.name,
              'bio': user.bio,
              'avatar': user.profileImageUrl,
              'isVerified': user.isVerified,
              'createdAt': null,
            };
          } else {
            // Fallback to backend call if cache miss
            try {
              _backendProfile = await _apiService.getProfileByWallet(address);
            } catch (e) {
                if (e.toString().contains('Profile not found')) {
                  try {
                    // Ask backend auth to register the wallet (creates user+profile and issues token)
                    final reg = await _apiService.registerWallet(
                      walletAddress: address,
                      username: 'user_${address.substring(0,6)}',
                    );
                    debugPrint('Web3Provider._syncBackend: registerWallet response: $reg');
                    // Try to fetch created profile
                    try {
                      _backendProfile = await _apiService.getProfileByWallet(address);
                    } catch (_) {
                      // Fallback to UserService cache
                      final user2 = await UserService.getUserById(address, forceRefresh: true);
                      if (user2 != null) {
                        _backendProfile = {
                          'walletAddress': user2.id,
                          'username': user2.username.replaceFirst('@', ''),
                          'displayName': user2.name,
                          'bio': user2.bio,
                          'avatar': user2.profileImageUrl,
                          'isVerified': user2.isVerified,
                          'createdAt': null,
                        };
                      }
                    }
                  } catch (regErr) {
                    debugPrint('Web3Provider._syncBackend: registerWallet failed: $regErr');
                  }
                } else {
                  rethrow;
                }
            }
          }
        } catch (e) {
          debugPrint('Web3Provider._syncBackend: profile lookup failed: $e');
        }

      // Collections count
      try {
        final collections = await _apiService.getCollections(walletAddress: address);
        _collectionsCount = collections.length;
      } catch (e) {
        debugPrint('Web3Provider: collections fetch failed: $e');
      }

      // Achievement stats
      try {
        final stats = await _apiService.getAchievementStats(address);
        _achievementsUnlocked = (stats['unlocked'] as int?) ?? 0;
        _achievementTokenTotal = (stats['totalTokens'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('Web3Provider: achievement stats fetch failed: $e');
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint('Web3Provider: backend sync error: $e\n$st');
    }
  }

  // Placeholder: formatting utilities retained for potential UI usage

  // Utility functions
  String formatBalance(double balance, {int decimals = 2}) {
    return balance.toStringAsFixed(decimals);
  }

  String formatAddress(String address, {int startChars = 6, int endChars = 4}) {
    if (address.length <= startChars + endChars) return address;
    return '${address.substring(0, startChars)}...${address.substring(address.length - endChars)}';
  }
}
