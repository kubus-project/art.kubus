import 'package:flutter/material.dart';
import 'package:solana/solana.dart' show Ed25519HDKeyPair;

import '../config/api_keys.dart';
import '../models/wallet.dart';
import '../providers/wallet_provider.dart';
import '../services/solana_wallet_service.dart';

class Web3Provider extends ChangeNotifier {
  final SolanaWalletService _solanaService;
  WalletProvider? _walletProvider;
  VoidCallback? _walletListener;

  bool _initialized = false;
  bool _initializing = false;
  String? _initializeError;

  Web3Provider({SolanaWalletService? solanaWalletService})
      : _solanaService = solanaWalletService ?? SolanaWalletService();

  void bindWalletProvider(WalletProvider walletProvider) {
    if (identical(_walletProvider, walletProvider)) return;

    final listener = _walletListener;
    if (_walletProvider != null && listener != null) {
      _walletProvider!.removeListener(listener);
    }

    _walletProvider = walletProvider;
    _walletListener = () {
      _initializeError = walletProvider.lastError;
      notifyListeners();
    };
    walletProvider.addListener(_walletListener!);
    _initializeError = walletProvider.lastError;
    notifyListeners();
  }

  WalletProvider get _boundWalletProvider {
    final provider = _walletProvider;
    if (provider == null) {
      throw StateError('Web3Provider is not bound to WalletProvider.');
    }
    return provider;
  }

  bool get hasWalletIdentity => _walletProvider?.hasWalletIdentity ?? false;
  bool get hasSigner => _walletProvider?.hasSigner ?? false;
  bool get canTransact => _walletProvider?.authority.canTransact ?? false;
  bool get isReadOnlySession =>
      _walletProvider?.authority.isReadOnlyWallet ?? false;
  bool get isConnected => canTransact;
  Wallet? get wallet => _walletProvider?.wallet;
  String get walletAddress => _walletProvider?.currentWalletAddress ?? '';
  double get solBalance => wallet?.getTokenBySymbol('SOL')?.balance ?? 0.0;
  double get kub8Balance => wallet?.getTokenBySymbol('KUB8')?.balance ?? 0.0;
  String get currentNetwork =>
      _walletProvider?.currentSolanaNetwork ?? _solanaService.currentNetwork;
  List<WalletTransaction> get transactions =>
      List.unmodifiable(_walletProvider?.transactions ?? const []);
  Map<String, dynamic>? get backendProfile => _walletProvider?.backendProfile;
  int get collectionsCount => _walletProvider?.collectionsCount ?? 0;
  int get achievementsUnlocked => _walletProvider?.achievementsUnlocked ?? 0;
  double get achievementTokenTotal =>
      _walletProvider?.achievementTokenTotal ?? 0.0;
  String get kub8TokenAddress => ApiKeys.kub8MintAddress;
  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  String? get initializeError => _initializeError;

  Future<void> initialize({bool attemptRestore = true}) async {
    final walletProvider = _walletProvider;
    if (walletProvider == null) {
      _initialized = true;
      _initializeError = null;
      notifyListeners();
      return;
    }

    if (_initialized || _initializing) return;

    _initializing = true;
    _initializeError = null;
    notifyListeners();
    try {
      if (attemptRestore) {
        await walletProvider.initialize();
      }
      _initializeError = walletProvider.lastError;
    } catch (e) {
      _initializeError = e.toString();
      rethrow;
    } finally {
      _initialized = true;
      _initializing = false;
      notifyListeners();
    }
  }

  void switchNetwork(String network) {
    final walletProvider = _walletProvider;
    if (walletProvider == null) {
      _solanaService.switchNetwork(network);
      notifyListeners();
      return;
    }
    walletProvider.switchSolanaNetwork(network);
  }

  Future<String> createWallet() async {
    final result = await _boundWalletProvider.createWallet();
    return result['address']!;
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

    DerivedKeyPairResult? preDerived;
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
      preDerived = DerivedKeyPairResult(
        keyPair: solanaKeyPair,
        hdKeyPair: hdKeyPair,
        pathType: resolvedPath,
        accountIndex: resolvedAccount,
        changeIndex: resolvedChange,
      );
    }

    await _boundWalletProvider.importWalletFromMnemonic(
      mnemonic,
      preDerived: preDerived,
    );
  }

  Future<void> connectExistingWallet(String publicKey) async {
    await _boundWalletProvider.connectWalletWithAddress(publicKey);
  }

  Future<void> disconnectWallet() async {
    await _boundWalletProvider.disconnectWallet();
  }

  Future<void> updateBalances() async {
    await _boundWalletProvider.refreshData();
  }

  Future<String> sendKub8(String toAddress, double amount) async {
    final result = await _boundWalletProvider.sendTransaction(
      token: 'KUB8',
      amount: amount,
      toAddress: toAddress,
    );
    return result.primarySignature;
  }

  Future<String> swapSolToKub8(double solAmount) async {
    if (!_boundWalletProvider.authority.canTransact) {
      throw Exception('Wallet signer required for swaps');
    }
    final signer = _boundWalletProvider.solanaWalletService;
    final signature = _boundWalletProvider.hasLocalSigner
        ? await signer.swapSolToSpl(
            mint: kub8TokenAddress,
            solAmount: solAmount,
          ).then((record) => record.signature)
        : await _boundWalletProvider.signAndSendTransactionBase64(
            (
              await signer.buildJupiterSwapTransactionBase64(
              userPublicKey: _boundWalletProvider.currentWalletAddress!,
              inputMint: ApiKeys.wrappedSolMintAddress,
              outputMint: kub8TokenAddress,
              inputAmountRaw: (solAmount * 1000000000).round(),
              slippageBps: 50,
              wrapAndUnwrapSol: true,
            ))
                .transactionBase64,
          );
    await _boundWalletProvider.refreshData();
    return signature;
  }

  Future<String> mintArtworkNFT(Map<String, dynamic> metadata) async {
    if (!_boundWalletProvider.authority.canTransact) {
      throw Exception('Wallet signer required for NFT minting');
    }
    if (!_boundWalletProvider.hasLocalSigner) {
      throw Exception('Local signer required for NFT minting');
    }
    return _boundWalletProvider.solanaWalletService.mintNft(metadata: metadata);
  }

  String formatBalance(double balance, {int decimals = 2}) {
    return balance.toStringAsFixed(decimals);
  }

  String formatAddress(String address, {int startChars = 6, int endChars = 4}) {
    if (address.length <= startChars + endChars) return address;
    return '${address.substring(0, startChars)}...${address.substring(address.length - endChars)}';
  }

  @override
  void dispose() {
    final listener = _walletListener;
    if (_walletProvider != null && listener != null) {
      _walletProvider!.removeListener(listener);
    }
    super.dispose();
  }
}
