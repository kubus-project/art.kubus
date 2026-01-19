import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart' show Ed25519HDKeyPair;
import '../models/wallet.dart';
import '../models/swap_quote.dart';
import '../services/solana_wallet_service.dart';
import '../services/backend_api_service.dart';
import '../services/stats_api_service.dart';
import '../services/pin_hashing.dart';
import '../services/security/pin_auth_service.dart';
import '../services/user_service.dart';
import '../config/config.dart';
import '../config/api_keys.dart';
import '../utils/wallet_utils.dart';

enum BiometricAuthOutcome {
  success,
  failed,
  cancelled,
  notAvailable,
  lockedOut,
  permanentlyLockedOut,
  error,
}

void _walletLog(String message) {
  if (!kDebugMode) return;
  debugPrint('WalletProvider: $message');
}

class WalletProvider extends ChangeNotifier {
  final SolanaWalletService _solanaWalletService;
  final BackendApiService _apiService = BackendApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  late final PinAuthService _pinAuth = PinAuthService(
    store: SecureStoragePinStore(_secureStorage),
  );
  // Cached mnemonic import retry
  Timer? _importRetryTimer;
  int _importRetryAttempts = 0;
  static const int _maxImportRetryAttempts = 3;
  static const Duration _baseImportRetryDelay = Duration(seconds: 5);

  Wallet? _wallet;
  List<Token> _tokens = [];
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isBalanceVisible = true;
  String? _currentWalletAddress;
  DerivedKeyPairResult? _cachedDerivedCandidate;
  Completer<void>? _initializeCompleter;

  // Backend supplemental data
  Map<String, dynamic>? _backendProfile;
  int _collectionsCount = 0;
  int _achievementsUnlocked = 0;
  double _achievementTokenTotal = 0.0; // totalTokens from achievement stats

  // Backend supplemental getters
  Map<String, dynamic>? get backendProfile => _backendProfile;
  int get collectionsCount => _collectionsCount;
  int get achievementsUnlocked => _achievementsUnlocked;
  double get achievementTokenTotal => _achievementTokenTotal;

  WalletProvider({SolanaWalletService? solanaWalletService, bool deferInit = false})
      : _solanaWalletService = solanaWalletService ?? SolanaWalletService() {
    if (!deferInit) {
      unawaited(initialize());
    }
  }

  /// Idempotent async initialization. Safe to call multiple times.
  Future<void> initialize() {
    final existing = _initializeCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initializeCompleter = completer;

    () async {
      try {
        await _init();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('WalletProvider.initialize failed: $e');
        }
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    }();

    return completer.future;
  }

  @visibleForTesting
  void setCurrentWalletAddressForTesting(String? address) {
    final next = (address ?? '').trim();
    _currentWalletAddress = next.isEmpty ? null : next;
    notifyListeners();
  }

  Future<void> _init() async {
    await _applySavedNetworkPreference();
    await _loadCachedWallet();
    // If a cached wallet was not loaded, proceed to load data normally
    if (_currentWalletAddress == null) {
      await _loadData();
    }
  }

  Future<void> _applySavedNetworkPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedNetwork = prefs.getString('networkSelection');
      final targetNetwork = (savedNetwork == null || savedNetwork.isEmpty)
          ? ApiKeys.defaultSolanaNetwork
          : savedNetwork;
      _solanaWalletService.switchNetwork(targetNetwork);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WalletProvider: failed to apply saved network: $e');
      }
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      return canCheck || available.isNotEmpty;
    } catch (e) {
      _walletLog('biometrics check failed: $e');
      return false;
    }
  }

  Future<BiometricAuthOutcome> authenticateWithBiometricsDetailed({
    String? localizedReason,
  }) async {
    try {
      final canUse = await canUseBiometrics();
      if (!canUse) return BiometricAuthOutcome.notAvailable;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason ?? 'Authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );
      return didAuthenticate ? BiometricAuthOutcome.success : BiometricAuthOutcome.failed;
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('notavailable') || code.contains('not_available')) {
        return BiometricAuthOutcome.notAvailable;
      }
      if (code.contains('notenrolled') || code.contains('not_enrolled')) {
        return BiometricAuthOutcome.notAvailable;
      }
      if (code.contains('lockedout') || code.contains('locked_out')) {
        return BiometricAuthOutcome.lockedOut;
      }
      if (code.contains('permanentlylockedout') || code.contains('permanently_locked_out')) {
        return BiometricAuthOutcome.permanentlyLockedOut;
      }
      if (code.contains('usercanceled') ||
          code.contains('user_canceled') ||
          code.contains('usercancel') ||
          code.contains('user_cancel') ||
          code.contains('canceled') ||
          code.contains('cancelled')) {
        return BiometricAuthOutcome.cancelled;
      }
      return BiometricAuthOutcome.error;
    } catch (e) {
      _walletLog('biometric auth error: $e');
      return BiometricAuthOutcome.error;
    }
  }

  Future<bool> authenticateWithBiometrics({String? localizedReason}) async {
    final outcome = await authenticateWithBiometricsDetailed(localizedReason: localizedReason);
    return outcome == BiometricAuthOutcome.success;
  }

  Future<void> setPin(String pin) async {
    try {
      await _pinAuth.setPin(pin);
    } catch (e) {
      _walletLog('failed to set PIN: $e');
      rethrow;
    }
  }

  Future<void> clearPin() async {
    try {
      await _pinAuth.clearPin();
    } catch (e) {
      _walletLog('failed to clear PIN: $e');
    }
  }

  Future<bool> hasPin() async {
    try {
      return await _pinAuth.hasPin();
    } catch (_) {
      return false;
    }
  }

  Future<PinVerifyResult> verifyPinDetailed(String pin) async {
    try {
      return await _pinAuth.verifyPin(pin);
    } catch (e) {
      _walletLog('PIN verification failed: $e');
      return const PinVerifyResult(PinVerifyOutcome.error);
    }
  }

  Future<bool> verifyPin(String pin) async {
    final result = await verifyPinDetailed(pin);
    return result.isSuccess;
  }

  /// Authenticate to unlock the app (does not reveal mnemonic).
  /// Tries biometric first, then PIN if provided. Returns true when unlocked.
  Future<bool> authenticateForAppUnlock({String? pin}) async {
    try {
      final biometric = await authenticateWithBiometricsDetailed();
      var ok = biometric == BiometricAuthOutcome.success;

      if (!ok && pin != null && pin.isNotEmpty) {
        ok = (await verifyPinDetailed(pin)).isSuccess;
      }

      if (ok) {
        return true;
      }
      return false;
    } catch (e) {
      _walletLog('authenticateForAppUnlock failed: $e');
      return false;
    }
  }

  /// Returns remaining lockout seconds for PIN entry (0 if none)
  Future<int> getPinLockoutRemainingSeconds() async {
    try {
      return await _pinAuth.getLockoutRemainingSeconds();
    } catch (e) {
      return 0;
    }
  }

  /// Reads the cached mnemonic without performing any local authentication.
  /// Callers must enforce their own security gate before calling this.
  Future<String?> readCachedMnemonic() async {
    try {
      return await _secureStorage.read(key: 'cached_mnemonic');
    } catch (e) {
      _walletLog('failed to read cached mnemonic: $e');
      return null;
    }
  }

  // Cache mnemonic for 7 days so user doesn't need to re-enter it
  Future<void> _cacheMnemonic(String mnemonic) async {
    try {
      await _secureStorage.write(key: 'cached_mnemonic', value: mnemonic);
      await _secureStorage.write(
          key: 'cached_mnemonic_ts', value: DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      _walletLog('failed to cache mnemonic: $e');
    }
  }

  Future<void> clearCachedMnemonic() async {
    try {
      await _secureStorage.delete(key: 'cached_mnemonic');
      await _secureStorage.delete(key: 'cached_mnemonic_ts');
    } catch (e) {
      _walletLog('failed to clear cached mnemonic: $e');
    }
  }

  Future<void> _loadCachedWallet() async {
    try {
      _walletLog('_loadCachedWallet: starting cached wallet check');
      final mnemonic = await _secureStorage.read(key: 'cached_mnemonic');
      final tsStr = await _secureStorage.read(key: 'cached_mnemonic_ts');

      if (mnemonic != null) {
        if (tsStr != null) {
          final ts = int.tryParse(tsStr);
          if (ts != null) {
            final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));

            if (age.inDays < 7) {
              _walletLog('cached mnemonic within TTL; validating before import');
              // Validate mnemonic format first. If invalid, clear it immediately.
              try {
                final isValid = _solanaWalletService.validateMnemonic(mnemonic);
                if (!isValid) {
                  _walletLog('cached mnemonic invalid format; clearing');
                  await clearCachedMnemonic();
                  return;
                }
              } catch (e) {
                _walletLog('cached mnemonic validation failed: $e');
                // don't clear yet — may be transient
              }

              // Immediately derive the public address locally so the app appears connected,
              // then attempt to import balances/data in background. This avoids forcing the
              // user through onboarding when network/import fails temporarily.
              DerivedKeyPairResult? derived;
              try {
                derived = await _solanaWalletService.derivePreferredKeyPair(
                  mnemonic,
                );
                _cachedDerivedCandidate = derived;
                try {
                  _solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
                } catch (e) {
                  _walletLog('failed to set active keypair from cached mnemonic: $e');
                }
                _currentWalletAddress = derived.address;

                // Save to SharedPreferences for profile provider
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('wallet_address', _currentWalletAddress!);

                notifyListeners();
                // Attempt to load data in background (don't block startup)
                _loadData().then((_) {
                  notifyListeners();
                });
              } catch (e) {
                _walletLog('failed to derive keypair from cached mnemonic: $e');
              }

              // Attempt import of full wallet state; if it fails, schedule retries.
              final success = await _attemptImportFromCache(mnemonic, derived: derived);
              if (success) return;
              _scheduleImportRetry(mnemonic);
            } else {
              // expired
              await clearCachedMnemonic();
            }
          }
        } else {
          // No timestamp present but mnemonic exists — try to import and set timestamp on success.
          _walletLog('cached mnemonic present without timestamp; attempting import');
          try {
            final isValid = _solanaWalletService.validateMnemonic(mnemonic);
            if (!isValid) {
              _walletLog('cached mnemonic invalid format; clearing');
              await clearCachedMnemonic();
              return;
            }
          } catch (e) {
            _walletLog('cached mnemonic validation failed (no timestamp): $e');
          }

          DerivedKeyPairResult? derived;
          try {
            derived = await _solanaWalletService.derivePreferredKeyPair(
              mnemonic,
            );
            _cachedDerivedCandidate = derived;
            try {
              _solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
            } catch (e) {
              _walletLog('failed to set active keypair from cached mnemonic (no timestamp): $e');
            }
            _currentWalletAddress = derived.address;
            notifyListeners();
            _loadData();
          } catch (e) {
            _walletLog('failed to derive keypair from cached mnemonic (no timestamp): $e');
          }

          final success = await _attemptImportFromCache(mnemonic, derived: derived);
          if (success) {
            // Set a fresh timestamp so subsequent runs treat it as recent
            try {
              await _secureStorage.write(key: 'cached_mnemonic_ts', value: DateTime.now().millisecondsSinceEpoch.toString());
            } catch (e) {
              _walletLog('failed to write cached_mnemonic_ts after import: $e');
            }
            return;
          }
          _scheduleImportRetry(mnemonic);
        }
      } else {
        // No cached mnemonic found.
      }
    } catch (e) {
      _walletLog('error loading cached wallet: $e');
    }

    // Fallback: if no cached mnemonic restored a wallet, try SharedPreferences so web
    // refreshes keep a read-only connection at minimum.
    if (_currentWalletAddress == null || _currentWalletAddress!.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedAddress = (prefs.getString('wallet_address') ??
                prefs.getString('walletAddress') ??
                prefs.getString('wallet'))
            ?.trim();
        if (storedAddress != null && storedAddress.isNotEmpty) {
          _currentWalletAddress = storedAddress;
          await _loadData();
        }
      } catch (e) {
        _walletLog('fallback restore failed: $e');
      }
    }
  }

  // Attempt import immediately (returns true on success)
  Future<bool> _attemptImportFromCache(String mnemonic, {DerivedKeyPairResult? derived}) async {
    try {
      final candidate = derived ?? _cachedDerivedCandidate;
      await importWalletFromMnemonic(mnemonic, preDerived: candidate);
      _cachedDerivedCandidate = null;
      // reset retry state
      _importRetryAttempts = 0;
      _importRetryTimer?.cancel();
      _importRetryTimer = null;
      return true;
    } catch (e, stackTrace) {
      _walletLog('import attempt failed: $e\n$stackTrace');
      _importRetryAttempts += 1;
      return false;
    }
  }

  void _scheduleImportRetry(String mnemonic) {
    try {
      if (_importRetryAttempts >= _maxImportRetryAttempts) {
        _walletLog('max import retry attempts reached; giving up');
        return;
      }

      _importRetryTimer?.cancel();
      final multiplier = _importRetryAttempts + 1;
      final delay = Duration(seconds: _baseImportRetryDelay.inSeconds * multiplier);
      _walletLog('scheduling mnemonic import retry in ${delay.inSeconds}s');
      _importRetryTimer = Timer(delay, () async {
        // Only retry if still have cached mnemonic and not imported yet
        final cached = await _secureStorage.read(key: 'cached_mnemonic');
        if (cached == null) return;
        final ok = await _attemptImportFromCache(cached, derived: _cachedDerivedCandidate);
        if (!ok) {
          // If still failing and attempts not exhausted, schedule another
          if (_importRetryAttempts < _maxImportRetryAttempts) {
            _scheduleImportRetry(cached);
          } else {
            _walletLog('import retries exhausted');
          }
        }
      });
    } catch (e) {
      _walletLog('failed to schedule import retry: $e');
    }
  }

  // Getters
  Wallet? get wallet => _wallet;
  List<Token> get tokens => List.unmodifiable(_tokens);
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  bool get isBalanceVisible => _isBalanceVisible;
  double get totalBalance => _wallet?.totalValue ?? 0.0;
  String? get currentWalletAddress => _currentWalletAddress;
  bool get isConnected => _currentWalletAddress != null && _currentWalletAddress!.isNotEmpty;
  bool get hasActiveKeyPair => _solanaWalletService.hasActiveKeyPair;
  SolanaWalletService get solanaWalletService => _solanaWalletService;

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    _walletLog('_loadData: starting');

    try {
      _walletLog('_loadData: loading from blockchain');
      await _loadFromBlockchain();
    } catch (e) {
      _walletLog('error loading wallet data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromBlockchain() async {
    try {
      if (_currentWalletAddress == null) {
        _walletLog('no wallet address available; clearing wallet data');
        // Clear all data when mock is disabled and no real wallet
        _wallet = null;
        _tokens = [];
        _transactions = [];
        return;
      }

      // Load Solana wallet data
      await _loadSolanaWallet(_currentWalletAddress!);
    } catch (e) {
      _walletLog('error loading blockchain data: $e');
      // Clear data on error when mock data is disabled
      _wallet = null;
      _tokens = [];
      _transactions = [];
    }
  }

  Future<void> _loadSolanaWallet(String address) async {
    try {
      final solBalance = await _solanaWalletService.getBalance(address);
      final tokenBalances = await _solanaWalletService.getTokenBalances(address);
      final transactionHistory = await _solanaWalletService.getTransactionHistory(address);

      // Native SOL token first
      _tokens = [
        Token(
          id: 'sol_native',
          name: 'Solana',
          symbol: 'SOL',
          type: TokenType.native,
          balance: solBalance,
          value: solBalance * 50.0, // Placeholder price
          changePercentage: 0.0,
          contractAddress: 'native',
          decimals: 9,
          logoUrl: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
          network: 'Solana',
        ),
      ];

      // Add SPL tokens
      final kub8Mint = WalletUtils.canonical(ApiKeys.kub8MintAddress);
      for (final t in tokenBalances) {
        final isKub8 = WalletUtils.equals(t.mint, kub8Mint);
        _tokens.add(Token(
          id: 'spl_${t.mint}',
          name: t.name,
          symbol: t.symbol,
          type: isKub8 ? TokenType.governance : TokenType.erc20,
          balance: t.balance,
          value: t.balance * 1.0, // Placeholder until price API
          changePercentage: 0.0,
          contractAddress: t.mint,
          decimals: t.decimals,
          logoUrl: t.logoUrl,
          network: 'Solana',
        ));
      }

      // Map transaction history (simplified)
      _transactions = transactionHistory.map((tx) => WalletTransaction(
        id: tx.signature,
        type: TransactionType.receive, // Placeholder mapping
        token: 'SOL',
        amount: 0.0,
        fromAddress: null,
        toAddress: address,
        timestamp: tx.blockTime,
        status: tx.status.toLowerCase() == 'finalized'
            ? TransactionStatus.confirmed
            : TransactionStatus.pending,
        txHash: tx.signature,
        gasUsed: tx.fee.toDouble(),
        gasFee: tx.fee / 1000000000.0,
        metadata: {'slot': tx.slot.toString()},
      )).toList();

      _wallet = Wallet(
        id: 'wallet_${address.substring(0,8)}',
        address: address,
        name: 'Solana Wallet',
        network: 'Solana',
        tokens: _tokens,
        transactions: _transactions,
        totalValue: _tokens.fold(0.0, (sum, token) => sum + token.value),
        lastUpdated: DateTime.now(),
      );

      await _syncBackendData(address);
    } catch (e) {
      _walletLog('error loading Solana wallet: $e');
      rethrow;
    }
  }

  Future<void> _syncBackendData(String address) async {
    try {
      // Profile fetch or create
      try {
        // Request fresh profile when syncing backend data for connected wallet
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
          try {
            _backendProfile = await _apiService.getProfileByWallet(address);
          } catch (e) {
            if (e.toString().contains('Profile not found')) {
              try {
                final reg = await _apiService.registerWallet(
                  walletAddress: address,
                  username: 'user_${address.substring(0,6)}',
                );
                _walletLog('_syncBackendData: registerWallet response: $reg');
                try {
                  _backendProfile = await _apiService.getProfileByWallet(address);
                } catch (_) {
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
                _walletLog('_syncBackendData: registerWallet failed: $regErr');
              }
            } else {
              rethrow;
            }
          }
        }
      } catch (e) {
        _walletLog('_syncBackendData: profile lookup failed: $e');
      }

      // Canonical user snapshot (collections + achievement stats)
      try {
        final snapshot = await StatsApiService(api: _apiService).fetchSnapshot(
          entityType: 'user',
          entityId: address,
          metrics: const ['collections', 'achievementsUnlocked', 'achievementTokensTotal'],
          scope: 'public',
        );
        _collectionsCount = snapshot.counters['collections'] ?? 0;
        _achievementsUnlocked = snapshot.counters['achievementsUnlocked'] ?? 0;
        _achievementTokenTotal = (snapshot.counters['achievementTokensTotal'] ?? 0).toDouble();
      } catch (e) {
        _walletLog('stats snapshot fetch failed: $e');
      }

      // Try to issue backend token for this wallet to ensure API auth is ready
      try {
        // Keep API layer aligned with the active wallet. This prevents stale
        // tokens from a previous wallet session from causing 403s on
        // ownership-gated endpoints (marker edit/delete).
        _apiService.setPreferredWalletAddress(address);
        if (AppConfig.enableDebugIssueToken) {
          final issued = await _apiService.issueTokenForWallet(address);
          _walletLog('_syncBackendData: token issued');
          if (issued) await _apiService.loadAuthToken();
        }
      } catch (e) {
        _walletLog('_syncBackendData: token issuance failed: $e');
      }

      notifyListeners();
    } catch (e) {
      _walletLog('backend sync error: $e');
    }
  }

  // Balance visibility toggle
  void toggleBalanceVisibility() {
    _isBalanceVisible = !_isBalanceVisible;
    notifyListeners();
  }

  // Token methods
  Token? getTokenBySymbol(String symbol) {
    try {
      return _tokens.firstWhere((token) => token.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  Token? getTokenByMint(String? mint) {
    if (mint == null) return null;
    final normalized = mint.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final token in _tokens) {
      if (token.contractAddress.toLowerCase() == normalized) {
        return token;
      }
    }

    if (normalized == 'native' || normalized == ApiKeys.wrappedSolMintAddress.toLowerCase()) {
      return getTokenBySymbol('SOL');
    }
    return null;
  }

  List<Token> getTokensByType(TokenType type) {
    return _tokens.where((token) => token.type == type).toList();
  }

  double getTokenBalance(String symbol) {
    final token = getTokenBySymbol(symbol);
    return token?.balance ?? 0.0;
  }

  // Transaction methods
  List<WalletTransaction> getRecentTransactions({int limit = 10}) {
    return List<WalletTransaction>.from(_transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
      ..take(limit);
  }

  List<WalletTransaction> getTransactionsByType(TransactionType type) {
    return _transactions.where((tx) => tx.type == type).toList();
  }

  List<WalletTransaction> getTransactionsByToken(String token) {
    return _transactions.where((tx) => tx.token == token).toList();
  }

  Future<void> sendTransaction({
    required String token,
    required double amount,
    required String toAddress,
    double? gasPrice,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isConnected || _currentWalletAddress == null || _currentWalletAddress!.isEmpty) {
      throw Exception('Connect wallet before sending transactions');
    }
    if (toAddress.trim().isEmpty) {
      throw Exception('Recipient address is required');
    }
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero');
    }

    try {
      final feeTeam = amount * ApiKeys.kubusTeamFeePct;
      final feeTreasury = amount * ApiKeys.kubusTreasuryFeePct;
      final totalRequired = amount + feeTeam + feeTreasury;
      final balance = getTokenBalance(token);
      if (balance < totalRequired) {
        throw Exception('Insufficient balance. Needed $totalRequired $token including fees.');
      }

      String? signature;
      final isSol = token.toUpperCase() == 'SOL';
      final tokenMeta = getTokenBySymbol(token);
      final decimals = tokenMeta?.decimals ?? ApiKeys.kub8Decimals;
      final mint = tokenMeta?.contractAddress ?? ApiKeys.kub8MintAddress;

      if (isSol) {
        signature = await _solanaWalletService.transferSol(
          toAddress: toAddress,
          amount: amount,
        );
      } else {
        signature = await _solanaWalletService.transferSplToken(
          mint: mint,
          toAddress: toAddress,
          amount: amount,
          decimals: decimals,
        );
      }

      // Fee transfers (match the token being sent)
      if (feeTeam > 0) {
        if (isSol) {
          await _solanaWalletService.transferSol(
            toAddress: ApiKeys.kubusTeamWallet,
            amount: feeTeam,
          );
        } else {
          await _solanaWalletService.transferSplToken(
            mint: mint,
            toAddress: ApiKeys.kubusTeamWallet,
            amount: feeTeam,
            decimals: decimals,
          );
        }
      }
      if (feeTreasury > 0) {
        if (isSol) {
          await _solanaWalletService.transferSol(
            toAddress: ApiKeys.kubusTreasuryWallet,
            amount: feeTreasury,
          );
        } else {
          await _solanaWalletService.transferSplToken(
            mint: mint,
            toAddress: ApiKeys.kubusTreasuryWallet,
            amount: feeTreasury,
            decimals: decimals,
          );
        }
      }

      // Optimistically append transaction and refresh
      _transactions.insert(
        0,
        WalletTransaction(
          id: signature,
          type: TransactionType.send,
          token: token,
          amount: amount,
          fromAddress: _currentWalletAddress,
          toAddress: toAddress,
          timestamp: DateTime.now(),
          status: TransactionStatus.confirmed,
          txHash: signature,
          gasUsed: gasPrice ?? 0.0,
          gasFee: gasPrice ?? 0.0,
          metadata: {
            ...?metadata,
            'feeTeam': feeTeam,
            'feeTreasury': feeTreasury,
          },
        ),
      );
      await _loadFromBlockchain();
      notifyListeners();
        } catch (e, st) {
      _walletLog('sendTransaction failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> swapTokens({
    required String fromToken,
    required String toToken,
    required double fromAmount,
    required double toAmount,
    double? slippage,
  }) async {
    if (!isConnected || _currentWalletAddress == null || _currentWalletAddress!.isEmpty) {
      throw Exception('Connect wallet before swapping');
    }
    if (fromAmount <= 0 || toAmount <= 0) {
      throw Exception('Swap amounts must be greater than zero');
    }

    try {
      // Simple SOL -> SPL swap via Jupiter (SolanaWalletService).
      String? signature;
      if (fromToken.toUpperCase() == 'SOL') {
        signature = await _solanaWalletService.swapSolToSpl(
          mint: getTokenBySymbol(toToken)?.contractAddress ?? toToken,
          solAmount: fromAmount,
        );
      } else {
        // SPL -> SOL or SPL -> SPL handled via two calls (SPL->SOL not yet wired)
        signature = await _solanaWalletService.swapSplToken(
          fromMint: getTokenBySymbol(fromToken)?.contractAddress ?? fromToken,
          toMint: getTokenBySymbol(toToken)?.contractAddress ?? toToken,
          amount: fromAmount,
          slippage: slippage ?? 0.01,
        );
      }

      // Apply fees on output token
      final feeTeam = toAmount * ApiKeys.kubusTeamFeePct;
      final feeTreasury = toAmount * ApiKeys.kubusTreasuryFeePct;
      if (feeTeam > 0) {
        await _solanaWalletService.transferSplToken(
          mint: getTokenBySymbol(toToken)?.contractAddress ?? toToken,
          toAddress: ApiKeys.kubusTeamWallet,
          amount: feeTeam,
          decimals: getTokenBySymbol(toToken)?.decimals ?? ApiKeys.kub8Decimals,
        );
      }
      if (feeTreasury > 0) {
        await _solanaWalletService.transferSplToken(
          mint: getTokenBySymbol(toToken)?.contractAddress ?? toToken,
          toAddress: ApiKeys.kubusTreasuryWallet,
          amount: feeTreasury,
          decimals: getTokenBySymbol(toToken)?.decimals ?? ApiKeys.kub8Decimals,
        );
      }

      _transactions.insert(
        0,
        WalletTransaction(
          id: signature,
          type: TransactionType.swap,
          token: '$fromToken->$toToken',
          amount: fromAmount,
          fromAddress: _currentWalletAddress,
          toAddress: _currentWalletAddress,
          timestamp: DateTime.now(),
          status: TransactionStatus.confirmed,
          txHash: signature,
          gasUsed: 0.0,
          gasFee: 0.0,
          metadata: {
            'slippage': slippage,
            'expectedOut': toAmount,
            'feeTeam': feeTeam,
            'feeTreasury': feeTreasury,
          },
        ),
      );
      await _loadFromBlockchain();
      notifyListeners();
        } catch (e, st) {
      _walletLog('swapTokens failed: $e\n$st');
      rethrow;
    }
  }

  Future<SwapQuote> previewSwapQuote({
    required String fromToken,
    required String toToken,
    required double amount,
    double slippagePercent = 0.5,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero');
    }

    final from = getTokenBySymbol(fromToken);
    final to = getTokenBySymbol(toToken);
    if (from == null || to == null) {
      throw Exception('Token not available in your wallet');
    }

    final balance = getTokenBalance(fromToken);
    if (balance <= 0) {
      throw Exception('No balance available for $fromToken');
    }
    if (amount > balance) {
      throw Exception('Amount exceeds available $fromToken balance');
    }

    final inputDecimals = from.decimals;
    final outputDecimals = to.decimals;
    final rawAmount = (amount * pow(10, inputDecimals)).round();
    if (rawAmount <= 0) {
      throw Exception('Amount too small for $fromToken');
    }

    final slippageBps = (slippagePercent * 100).round().clamp(1, 500);

    return _solanaWalletService.fetchSwapQuote(
      inputMint: _resolveMintAddress(from),
      outputMint: _resolveMintAddress(to),
      inputAmountRaw: rawAmount,
      inputDecimals: inputDecimals,
      outputDecimals: outputDecimals,
      slippageBps: slippageBps,
    );
  }

  // Analytics methods
  Map<String, dynamic> getWalletAnalytics() {
    final totalTransactions = _transactions.length;
    final sentTransactions = getTransactionsByType(TransactionType.send).length;
    final receivedTransactions = getTransactionsByType(TransactionType.receive).length;
    final swapTransactions = getTransactionsByType(TransactionType.swap).length;
    
    final totalSent = getTransactionsByType(TransactionType.send)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    final totalReceived = getTransactionsByType(TransactionType.receive)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    
    return {
      'totalBalance': totalBalance,
      'totalTokens': _tokens.length,
      'totalTransactions': totalTransactions,
      'sentTransactions': sentTransactions,
      'receivedTransactions': receivedTransactions,
      'swapTransactions': swapTransactions,
      'totalSent': totalSent,
      'totalReceived': totalReceived,
      'tokensByType': {
        for (var type in TokenType.values)
          type.name: getTokensByType(type).length,
      },
    };
  }

  Future<void> refreshData() async {
    await _loadData();
  }

  // Wallet Management
  Future<Map<String, String>> createWallet() async {
    final mnemonic = _solanaWalletService.generateMnemonic();
    final keyPair = await _solanaWalletService.generateKeyPairFromMnemonic(
      mnemonic,
      accountIndex: 0,
      changeIndex: 0,
      pathType: DerivationPathType.standard,
    );
    try {
      final hdKeyPair = await Ed25519HDKeyPair.fromMnemonic(
        mnemonic,
        account: 0,
        change: 0,
      );
      _solanaWalletService.setActiveKeyPair(hdKeyPair);
      _walletLog('active keypair set for newly created wallet');
    } catch (e) {
      _walletLog('failed to set active keypair for new wallet: $e');
    }
    
    _currentWalletAddress = keyPair.publicKey;
    // Persist address for other providers/screens
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', _currentWalletAddress!);
      await prefs.setBool('has_wallet', true);
    } catch (e) {
      _walletLog('failed to persist wallet address: $e');
    }

    // Load the newly created wallet from blockchain and sync backend
    try {
      await _loadData();
    } catch (e) {
      _walletLog('createWallet: loadData failed: $e');
    }
    try {
      await _syncBackendData(_currentWalletAddress!);
    } catch (e) {
      _walletLog('createWallet: sync backend failed: $e');
    }

    // Cache mnemonic for reuse
    try {
      await _cacheMnemonic(mnemonic);
    } catch (_) {}
    
    notifyListeners();

    return {
      'mnemonic': mnemonic,
      'address': _currentWalletAddress!,
    };
  }

  Future<String> importWalletFromMnemonic(String mnemonic, {DerivedKeyPairResult? preDerived}) async {
    _walletLog('importWalletFromMnemonic start');
    
    if (!_solanaWalletService.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }
    
    final derived = preDerived ?? await _solanaWalletService.derivePreferredKeyPair(
      mnemonic,
    );
    try {
      _solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
      _walletLog('active keypair set for imported wallet');
    } catch (e) {
      _walletLog('failed to set active keypair for imported wallet: $e');
    }
    _currentWalletAddress = derived.address;
    // Wallet address set.
    
    // Save to SharedPreferences for profile provider
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', _currentWalletAddress!);
      await prefs.setBool('has_wallet', true);
      _walletLog('wallet address saved to SharedPreferences');
    } catch (e) {
      _walletLog('failed to save wallet address to SharedPreferences: $e');
    }
    
    // Notify immediately that we have an address
    notifyListeners();
    
    // Load the imported wallet from blockchain
    try {
      _walletLog('loading wallet data');
      await _loadData();
      _walletLog('wallet data loaded');
    } catch (e) {
      _walletLog('error loading wallet data: $e');
      // Even if loading fails, we have the address
    }
    
    if (_currentWalletAddress != null) {
      try {
        await _syncBackendData(_currentWalletAddress!);
        _walletLog('backend data synced');
      } catch (e) {
        _walletLog('error syncing backend data: $e');
      }
    }

    // Cache mnemonic for reuse
    try {
      await _cacheMnemonic(mnemonic);
      // Mnemonic cached.
    } catch (e) {
      _walletLog('error caching mnemonic: $e');
    }
    
    // Final notification to update all listeners
    _walletLog('wallet import complete');
    notifyListeners();
    
    return _currentWalletAddress!;
  }

  Future<void> connectWalletWithAddress(String address) async {
    final sanitized = address.trim();
    if (sanitized.isEmpty) {
      _walletLog('connectWalletWithAddress called with empty address');
      return;
    }

    _currentWalletAddress = sanitized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', sanitized);
      await prefs.setString('walletAddress', sanitized);
      await prefs.setString('wallet', sanitized);
      await prefs.setBool('has_wallet', true);
    } catch (e) {
      _walletLog('connectWalletWithAddress: failed to persist wallet address: $e');
    }
    
    // Load the connected wallet from blockchain
    await _loadData();
    await _syncBackendData(sanitized);
    notifyListeners();
  }

  void disconnectWallet() {
    _currentWalletAddress = null;
    _wallet = null;
    _tokens.clear();
    _transactions.clear();
    _backendProfile = null;
    _collectionsCount = 0;
    _achievementsUnlocked = 0;
    _achievementTokenTotal = 0.0;
    _cachedDerivedCandidate = null;
    // Clear cached mnemonic on explicit disconnect for security
    try {
      clearCachedMnemonic();
    } catch (_) {}
    // Cancel any pending import retry timers
    try {
      _importRetryTimer?.cancel();
      _importRetryTimer = null;
      _importRetryAttempts = 0;
    } catch (_) {}
    notifyListeners();
  }

  // Solana-specific methods
  Future<void> requestAirdrop(double amount) async {
    if (_currentWalletAddress == null) {
      throw Exception('No wallet connected');
    }
    
    await _solanaWalletService.requestAirdrop(_currentWalletAddress!, amount: amount);
    
    // Refresh wallet data after airdrop
    await refreshData();
  }

  void switchSolanaNetwork(String network) {
    _solanaWalletService.switchNetwork(network);
    
    // Refresh data with new network
    if (_currentWalletAddress != null) {
      _loadData();
    }
  }

  String get currentSolanaNetwork => _solanaWalletService.currentNetwork;

  String _resolveMintAddress(Token token) {
    if (token.symbol.toUpperCase() == 'SOL' || token.contractAddress.toLowerCase() == 'native') {
      return ApiKeys.wrappedSolMintAddress;
    }
    return token.contractAddress;
  }
}
