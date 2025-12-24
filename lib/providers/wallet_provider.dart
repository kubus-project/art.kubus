import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart' show Ed25519HDKeyPair;
import '../models/wallet.dart';
import '../models/swap_quote.dart';
import '../services/solana_wallet_service.dart';
import '../services/backend_api_service.dart';
import '../services/user_service.dart';
import '../config/api_keys.dart';
import '../utils/wallet_utils.dart';

class WalletProvider extends ChangeNotifier {
  final SolanaWalletService _solanaWalletService;
  final BackendApiService _apiService = BackendApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _pinHashKey = 'wallet_pin_hash';
  static const String _pinFailedKey = 'wallet_pin_failed_count';
  static const String _pinLockoutTsKey = 'wallet_pin_lockout_ts';
  static const int _maxPinAttempts = 5;
  static const Duration _pinLockoutDuration = Duration(minutes: 5);
  // Cached mnemonic import retry
  Timer? _importRetryTimer;
  int _importRetryAttempts = 0;
  static const int _maxImportRetryAttempts = 3;
  static const Duration _baseImportRetryDelay = Duration(seconds: 5);
  int _lockTimeoutSeconds = 0; // 0 = disabled
  bool _isLocked = false;
  bool _pendingShowMnemonic = false;

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
    await _loadLockTimeout();
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

  // Load lock timeout (seconds) from secure storage
  Future<void> _loadLockTimeout() async {
    try {
      final str = await _secureStorage.read(key: 'lock_timeout_seconds');
      if (str != null) {
        final v = int.tryParse(str) ?? 0;
        _lockTimeoutSeconds = v;
      }
    } catch (e) {
      debugPrint('Failed to load lock timeout: $e');
    }
  }

  int get lockTimeoutSeconds => _lockTimeoutSeconds;
  bool get isLocked => _isLocked;
  bool get pendingShowMnemonic => _pendingShowMnemonic;

  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Biometrics check failed: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock the app',
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth failed: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    try {
      final digest = sha256.convert(utf8.encode(pin)).toString();
      await _secureStorage.write(key: _pinHashKey, value: digest);
      debugPrint('App PIN set');
    } catch (e) {
      debugPrint('Failed to set PIN: $e');
      rethrow;
    }
  }

  Future<void> clearPin() async {
    try {
      await _secureStorage.delete(key: _pinHashKey);
      debugPrint('App PIN cleared');
    } catch (e) {
      debugPrint('Failed to clear PIN: $e');
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      // Check lockout
      final lockoutStr = await _secureStorage.read(key: _pinLockoutTsKey);
      if (lockoutStr != null) {
        final lockoutTs = int.tryParse(lockoutStr);
        if (lockoutTs != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now < lockoutTs) {
            // Still in lockout
            debugPrint('PIN locked until $lockoutTs');
            return false;
          } else {
            // Lockout expired, clear
            await _secureStorage.delete(key: _pinLockoutTsKey);
            await _secureStorage.delete(key: _pinFailedKey);
          }
        }
      }

      final stored = await _secureStorage.read(key: _pinHashKey);
      if (stored == null) return false;
      final digest = sha256.convert(utf8.encode(pin)).toString();
      final matched = digest == stored;
      if (matched) {
        // Reset failed attempts
        await _secureStorage.delete(key: _pinFailedKey);
        return true;
      }

      // Not matched: increment failed count
      final failedStr = await _secureStorage.read(key: _pinFailedKey);
      var failed = int.tryParse(failedStr ?? '0') ?? 0;
      failed += 1;
      await _secureStorage.write(key: _pinFailedKey, value: failed.toString());
      if (failed >= _maxPinAttempts) {
        final lockoutUntil = DateTime.now().add(_pinLockoutDuration).millisecondsSinceEpoch;
        await _secureStorage.write(key: _pinLockoutTsKey, value: lockoutUntil.toString());
        await _secureStorage.delete(key: _pinFailedKey);
        debugPrint('PIN locked until $lockoutUntil due to too many attempts');
      }

      return false;
    } catch (e) {
      debugPrint('PIN verification failed: $e');
      return false;
    }
  }

  /// Authenticate to unlock the app (does not reveal mnemonic).
  /// Tries biometric first, then PIN if provided. Returns true when unlocked.
  Future<bool> authenticateForAppUnlock({String? pin}) async {
    try {
      bool ok = false;
      try {
        ok = await authenticateWithBiometrics();
      } catch (_) {
        ok = false;
      }

      if (!ok && pin != null && pin.isNotEmpty) {
        ok = await verifyPin(pin);
      }

      if (ok) {
        _isLocked = false;
        _pendingShowMnemonic = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('authenticateForAppUnlock failed: $e');
      return false;
    }
  }

  /// Returns remaining lockout seconds for PIN entry (0 if none)
  Future<int> getPinLockoutRemainingSeconds() async {
    try {
      final lockoutStr = await _secureStorage.read(key: _pinLockoutTsKey);
      if (lockoutStr == null) return 0;
      final ts = int.tryParse(lockoutStr);
      if (ts == null) return 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = ts - now;
      return remaining > 0 ? (remaining / 1000).ceil() : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> setLockTimeoutSeconds(int seconds) async {
    _lockTimeoutSeconds = seconds;
    try {
      await _secureStorage.write(key: 'lock_timeout_seconds', value: seconds.toString());
    } catch (e) {
      debugPrint('Failed to save lock timeout: $e');
    }
    notifyListeners();
  }

  // Mark app inactive (store timestamp)
  Future<void> markInactive() async {
    try {
      await _secureStorage.write(key: 'last_inactive_ts', value: DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      debugPrint('Failed to write last_inactive_ts: $e');
    }
  }

  // Mark app active (check if lock threshold exceeded)
  Future<void> markActive() async {
    try {
      final tsStr = await _secureStorage.read(key: 'last_inactive_ts');
      if (tsStr != null && _lockTimeoutSeconds > 0) {
        final ts = int.tryParse(tsStr);
        if (ts != null) {
          final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
          if (elapsed.inSeconds >= _lockTimeoutSeconds) {
            _isLocked = true;
            _pendingShowMnemonic = true;
            notifyListeners();
            return;
          }
        }
      }
      // Not locked
      _isLocked = false;
      _pendingShowMnemonic = false;
      // clear stored timestamp
      await _secureStorage.delete(key: 'last_inactive_ts');
      notifyListeners();
    } catch (e) {
      debugPrint('Error during markActive: $e');
    }
  }

  /// Reveal the stored mnemonic (only when available). If wallet is locked,
  /// calling this will clear the locked state and return the mnemonic.
  Future<String?> revealMnemonic({String? pin}) async {
    try {
      // If locked, require authentication first
      if (_isLocked) {
        bool ok = false;
        // Try biometric first
        try {
          ok = await authenticateWithBiometrics();
        } catch (_) {
          ok = false;
        }

        // If biometric not available or failed, try PIN if provided
        if (!ok && pin != null && pin.isNotEmpty) {
          ok = await verifyPin(pin);
        }

        if (!ok) {
          debugPrint('Unlock required but authentication failed');
          return null;
        }
      }

      final m = await _secureStorage.read(key: 'cached_mnemonic');
      // unlock after revealing
      _isLocked = false;
      _pendingShowMnemonic = false;
      notifyListeners();
      return m;
    } catch (e) {
      debugPrint('Failed to reveal mnemonic: $e');
      return null;
    }
  }

  // Cache mnemonic for 7 days so user doesn't need to re-enter it
  Future<void> _cacheMnemonic(String mnemonic) async {
    try {
      await _secureStorage.write(key: 'cached_mnemonic', value: mnemonic);
      await _secureStorage.write(
          key: 'cached_mnemonic_ts', value: DateTime.now().millisecondsSinceEpoch.toString());
      debugPrint('Wallet mnemonic cached securely for 7 days');
    } catch (e) {
      debugPrint('Failed to cache mnemonic securely: $e');
    }
  }

  Future<void> clearCachedMnemonic() async {
    try {
      await _secureStorage.delete(key: 'cached_mnemonic');
      await _secureStorage.delete(key: 'cached_mnemonic_ts');
      debugPrint('Cached mnemonic cleared securely');
    } catch (e) {
      debugPrint('Failed to clear cached mnemonic: $e');
    }
  }

  Future<void> _loadCachedWallet() async {
    try {
      debugPrint('🔐 WalletProvider._loadCachedWallet: Starting cached wallet check...');
      final mnemonic = await _secureStorage.read(key: 'cached_mnemonic');
      final tsStr = await _secureStorage.read(key: 'cached_mnemonic_ts');
      
      debugPrint('🔐 Cached mnemonic found: ${mnemonic != null}, timestamp: ${tsStr != null}');
      
      if (mnemonic != null) {
        if (tsStr != null) {
          final ts = int.tryParse(tsStr);
          if (ts != null) {
            final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
            debugPrint('🔐 Mnemonic age: ${age.inDays} days');
            
            if (age.inDays < 7) {
              debugPrint('Found cached mnemonic (age ${age.inDays} days). Validating before import...');
              // Validate mnemonic format first. If invalid, clear it immediately.
              try {
                final isValid = _solanaWalletService.validateMnemonic(mnemonic);
                debugPrint('🔐 Mnemonic validation result: $isValid');
                if (!isValid) {
                  debugPrint('Cached mnemonic is invalid format, clearing cache');
                  await clearCachedMnemonic();
                  return;
                }
              } catch (e) {
                debugPrint('Error validating cached mnemonic: $e');
                // don't clear yet — may be transient
              }

              // Immediately derive the public address locally so the app appears connected,
              // then attempt to import balances/data in background. This avoids forcing the
              // user through onboarding when network/import fails temporarily.
              DerivedKeyPairResult? derived;
              try {
                debugPrint('🔐 Attempting to derive keypair from cached mnemonic...');
                derived = await _solanaWalletService.derivePreferredKeyPair(
                  mnemonic,
                );
                _cachedDerivedCandidate = derived;
                try {
                  _solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
                  debugPrint('🔐 Active keypair restored from cached mnemonic');
                } catch (e) {
                  debugPrint('⚠️ Failed to set active keypair from cached mnemonic: $e');
                }
                _currentWalletAddress = derived.address;
                debugPrint('🔐 ✅ Keypair derived! Address: $_currentWalletAddress');
                
                // Save to SharedPreferences for profile provider
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('wallet_address', _currentWalletAddress!);
                debugPrint('🔐 ✅ Wallet address saved to SharedPreferences');
                
                notifyListeners();
                // Attempt to load data in background (don't block startup)
                _loadData().then((_) {
                  debugPrint('🔐 Wallet data loaded, notifying listeners');
                  notifyListeners();
                });
              } catch (e) {
                debugPrint('❌ Failed to derive keypair from cached mnemonic: $e');
              }

              // Attempt import of full wallet state; if it fails, schedule retries.
              debugPrint('🔐 Calling _attemptImportFromCache...');
              final success = await _attemptImportFromCache(mnemonic, derived: derived);
              debugPrint('🔐 Import result: $success');
              if (success) return;
              _scheduleImportRetry(mnemonic);
            } else {
              // expired
              debugPrint('🔐 Mnemonic expired (${age.inDays} days), clearing');
              await clearCachedMnemonic();
            }
          }
        } else {
          // No timestamp present but mnemonic exists — try to import and set timestamp on success.
          debugPrint('Found cached mnemonic with no timestamp. Attempting import and will set timestamp on success.');
          try {
            final isValid = _solanaWalletService.validateMnemonic(mnemonic);
            if (!isValid) {
              debugPrint('Cached mnemonic invalid format, clearing');
              await clearCachedMnemonic();
              return;
            }
          } catch (e) {
            debugPrint('Error validating cached mnemonic without ts: $e');
          }

          DerivedKeyPairResult? derived;
          try {
            derived = await _solanaWalletService.derivePreferredKeyPair(
              mnemonic,
            );
            _cachedDerivedCandidate = derived;
            try {
              _solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
              debugPrint('🔐 Active keypair restored from cached mnemonic (no ts)');
            } catch (e) {
              debugPrint('⚠️ Failed to set active keypair from cached mnemonic (no ts): $e');
            }
            _currentWalletAddress = derived.address;
            notifyListeners();
            _loadData();
          } catch (e) {
            debugPrint('Failed to derive keypair from cached mnemonic (no ts): $e');
          }

          final success = await _attemptImportFromCache(mnemonic, derived: derived);
          if (success) {
            // Set a fresh timestamp so subsequent runs treat it as recent
            try {
              await _secureStorage.write(key: 'cached_mnemonic_ts', value: DateTime.now().millisecondsSinceEpoch.toString());
            } catch (e) {
              debugPrint('Failed to write cached_mnemonic_ts after successful import: $e');
            }
            return;
          }
          _scheduleImportRetry(mnemonic);
        }
      } else {
        debugPrint('🔐 No cached mnemonic found - fresh start');
      }
    } catch (e) {
      debugPrint('❌ Error loading cached wallet: $e');
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
          debugPrint('🔐 Fallback restored wallet from SharedPreferences: $_currentWalletAddress');
          await _loadData();
        }
      } catch (e) {
        debugPrint('⚠️ WalletProvider fallback restore failed: $e');
      }
    }
  }

  // Attempt import immediately (returns true on success)
  Future<bool> _attemptImportFromCache(String mnemonic, {DerivedKeyPairResult? derived}) async {
    try {
      debugPrint('🔐 Attempting to import cached mnemonic (attempt ${_importRetryAttempts + 1})...');
      final candidate = derived ?? _cachedDerivedCandidate;
      await importWalletFromMnemonic(mnemonic, preDerived: candidate);
      _cachedDerivedCandidate = null;
      debugPrint('🔐 ✅ Imported cached mnemonic successfully');
      // reset retry state
      _importRetryAttempts = 0;
      _importRetryTimer?.cancel();
      _importRetryTimer = null;
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Import attempt failed: $e');
      debugPrint('Stack trace: $stackTrace');
      _importRetryAttempts += 1;
      return false;
    }
  }

  void _scheduleImportRetry(String mnemonic) {
    try {
      if (_importRetryAttempts >= _maxImportRetryAttempts) {
        debugPrint('Max import retry attempts reached; will not retry further automatically');
        return;
      }

      _importRetryTimer?.cancel();
      final multiplier = _importRetryAttempts + 1;
      final delay = Duration(seconds: _baseImportRetryDelay.inSeconds * multiplier);
      debugPrint('Scheduling mnemonic import retry in ${delay.inSeconds}s');
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
            debugPrint('Import retries exhausted');
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to schedule import retry: $e');
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

    debugPrint('WalletProvider._loadData: Starting');

    try {
      debugPrint('WalletProvider._loadData: Loading from blockchain');
      await _loadFromBlockchain();
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromBlockchain() async {
    try {
      if (_currentWalletAddress == null) {
        debugPrint('No wallet address available - clearing wallet data');
        // Clear all data when mock is disabled and no real wallet
        _wallet = null;
        _tokens = [];
        _transactions = [];
        return;
      }

      // Load Solana wallet data
      await _loadSolanaWallet(_currentWalletAddress!);
    } catch (e) {
      debugPrint('Error loading blockchain data: $e');
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
      debugPrint('Error loading Solana wallet: $e');
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
                debugPrint('WalletProvider._syncBackendData: registerWallet response: $reg');
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
                debugPrint('WalletProvider._syncBackendData: registerWallet failed: $regErr');
              }
            } else {
              rethrow;
            }
          }
        }
      } catch (e) {
        debugPrint('WalletProvider._syncBackendData: profile lookup failed: $e');
      }

      // Collections
      try {
        final collections = await _apiService.getCollections(walletAddress: address);
        _collectionsCount = collections.length;
      } catch (e) {
        debugPrint('collections fetch failed: $e');
      }

      // Achievement stats
      try {
        final stats = await _apiService.getAchievementStats(address);
        _achievementsUnlocked = (stats['unlocked'] as int?) ?? 0;
        _achievementTokenTotal = (stats['totalTokens'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('achievement stats fetch failed: $e');
      }

      // Try to issue backend token for this wallet to ensure API auth is ready
      try {
        final issued = await _apiService.issueTokenForWallet(address);
        debugPrint('WalletProvider._syncBackendData: token issued for $address -> $issued');
        if (issued) await _apiService.loadAuthToken();
      } catch (e) {
        debugPrint('WalletProvider._syncBackendData: token issuance failed: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('backend sync error: $e');
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
      debugPrint('sendTransaction failed: $e\n$st');
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
      debugPrint('swapTokens failed: $e\n$st');
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
      debugPrint('🔐 Active keypair set for newly created wallet');
    } catch (e) {
      debugPrint('⚠️ Failed to set active keypair for new wallet: $e');
    }
    
    _currentWalletAddress = keyPair.publicKey;
    // Persist address for other providers/screens
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', _currentWalletAddress!);
      await prefs.setBool('has_wallet', true);
    } catch (e) {
      debugPrint('Failed to persist wallet address: $e');
    }

    // Load the newly created wallet from blockchain and sync backend
    try {
      await _loadData();
    } catch (e) {
      debugPrint('createWallet: loadData failed: $e');
    }
    try {
      await _syncBackendData(_currentWalletAddress!);
    } catch (e) {
      debugPrint('createWallet: sync backend failed: $e');
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
    debugPrint('🔐 importWalletFromMnemonic START');
    
    if (!_solanaWalletService.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }
    
    final derived = preDerived ?? await _solanaWalletService.derivePreferredKeyPair(
      mnemonic,
    );
    try {
      _solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
      debugPrint('🔐 Active keypair set for imported wallet');
    } catch (e) {
      debugPrint('⚠️ Failed to set active keypair for imported wallet: $e');
    }
    _currentWalletAddress = derived.address;
    debugPrint('🔐 Wallet address set: $_currentWalletAddress');
    
    // Save to SharedPreferences for profile provider
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', _currentWalletAddress!);
      await prefs.setBool('has_wallet', true);
      debugPrint('🔐 ✅ Wallet address saved to SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Failed to save wallet address to SharedPreferences: $e');
    }
    
    // Notify immediately that we have an address
    notifyListeners();
    
    // Load the imported wallet from blockchain
    try {
      debugPrint('🔐 Loading wallet data...');
      await _loadData();
      debugPrint('🔐 Wallet data loaded, wallet object: ${_wallet != null}');
    } catch (e) {
      debugPrint('❌ Error loading wallet data: $e');
      // Even if loading fails, we have the address
    }
    
    if (_currentWalletAddress != null) {
      try {
        await _syncBackendData(_currentWalletAddress!);
        debugPrint('🔐 Backend data synced');
      } catch (e) {
        debugPrint('❌ Error syncing backend data: $e');
      }
    }

    // Cache mnemonic for reuse
    try {
      await _cacheMnemonic(mnemonic);
      debugPrint('🔐 Mnemonic cached');
    } catch (e) {
      debugPrint('❌ Error caching mnemonic: $e');
    }
    
    // Final notification to update all listeners
    debugPrint('🔐 Notifying listeners - wallet import complete');
    notifyListeners();
    
    return _currentWalletAddress!;
  }

  Future<void> connectWalletWithAddress(String address) async {
    final sanitized = address.trim();
    if (sanitized.isEmpty) {
      debugPrint('connectWalletWithAddress called with empty address');
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
      debugPrint('connectWalletWithAddress: failed to persist wallet address -> $e');
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
