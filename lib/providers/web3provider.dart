import 'package:flutter/material.dart';
import '../services/solana_wallet_service.dart';
import 'package:solana/solana.dart' hide Wallet; // Hide solana Wallet to avoid name clash with app model
import '../services/backend_api_service.dart';
import '../models/wallet.dart';

class Web3Provider extends ChangeNotifier {
  final SolanaWalletService _solanaService = SolanaWalletService();
  final BackendApiService _apiService = BackendApiService();

  bool _isConnected = false;
  Wallet? _wallet; // Use unified Wallet model
  List<WalletTransaction> _transactions = [];
  Map<String, dynamic>? _backendProfile;
  int _collectionsCount = 0;
  int _achievementsUnlocked = 0;
  double _achievementTokenTotal = 0.0;

  // Configurable constants (replace with actual KUB8 mint/address)
  final String _kub8TokenAddress = 'KUB8_TOKEN_MINT_PLACEHOLDER';

  Web3Provider();

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

  // Network management
  void switchNetwork(String network) {
    _solanaService.switchNetwork(network);
    if (_isConnected && walletAddress.isNotEmpty) {
      _reloadWallet();
    }
    notifyListeners();
  }

  // Wallet connection (mnemonic based for now)
  Future<String> createWallet() async {
    final mnemonic = _solanaService.generateMnemonic();
    final keyPair = await _solanaService.generateKeyPairFromMnemonic(mnemonic);
    // Store keypair in service for signing
    final hdKeyPair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    _solanaService.setActiveKeyPair(hdKeyPair);
    await _initializeWallet(keyPair.publicKey, mnemonic: mnemonic);
    return keyPair.publicKey;
  }

  Future<void> importWallet(String mnemonic) async {
    final keyPair = await _solanaService.generateKeyPairFromMnemonic(mnemonic);
    final hdKeyPair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    _solanaService.setActiveKeyPair(hdKeyPair);
    await _initializeWallet(keyPair.publicKey, mnemonic: mnemonic);
  }

  Future<void> connectExistingWallet(String publicKey) async {
    // Existing wallet without mnemonic cannot sign (read-only mode)
    await _initializeWallet(publicKey);
  }

  Future<void> _initializeWallet(String publicKey, {String? mnemonic}) async {
    try {
      _isConnected = true;
      await _reloadWallet(address: publicKey);
      await _syncBackend(publicKey);
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      debugPrint('Web3Provider: wallet init failed: $e');
      rethrow;
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
    // Attempt SPL transfer via service (currently placeholder throws)
    try {
      final signature = await _solanaService.transferSplToken(
        mint: _kub8TokenAddress,
        toAddress: toAddress,
        amount: amount,
        decimals: 6,
      );
      // Refresh balances after transfer
      await _reloadWallet();
      notifyListeners();
      return signature;
    } on UnimplementedError catch (e) {
      debugPrint('KUB8 transfer pending implementation: $e');
      rethrow; // Surface unimplemented state to UI
    } catch (e) {
      debugPrint('KUB8 transfer failed: $e');
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
    } catch (e) {
      debugPrint('Swap failed: $e');
      rethrow;
    }
  }

  // Governance functions
  Future<String> voteOnProposal(String proposalId, bool support) async {
    // Placeholder: integrate governance program or backend endpoint
    throw UnimplementedError('Governance voting integration pending');
  }

  // NFT functions
  Future<String> mintArtworkNFT(String artworkData) async {
    // Placeholder call into service
    try {
      final signature = await _solanaService.mintNft(metadata: {'artwork': artworkData});
      return signature;
    } on UnimplementedError catch (e) {
      debugPrint('NFT mint pending integration: $e');
      rethrow;
    }
  }

  // Transaction loading
  Future<void> _reloadWallet({String? address}) async {
    final pubKey = address ?? walletAddress;
    if (pubKey.isEmpty) return;
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
    for (final b in splBalances) {
      tokens.add(Token(
        id: 'spl_${b.mint}',
        name: b.name,
        symbol: b.symbol,
        type: TokenType.erc20,
        balance: b.balance,
        value: b.balance * 1.0,
        changePercentage: 0.0,
        contractAddress: b.mint,
        decimals: b.decimals,
        logoUrl: null,
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
  }

  // Add mock transaction for demo purposes
  // Backend sync
  Future<void> _syncBackend(String address) async {
    try {
      try {
        _backendProfile = await _apiService.getProfileByWallet(address);
      } catch (e) {
        if (e.toString().contains('Profile not found')) {
          _backendProfile = await _apiService.saveProfile({
            'walletAddress': address,
            'username': 'user_${address.substring(0,6)}',
            'displayName': 'New User',
            'bio': '',
          });
        } else {
          rethrow;
        }
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
    } catch (e) {
      debugPrint('Web3Provider: backend sync error: $e');
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
