import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart' show Ed25519HDKeyPair;
import '../models/wallet.dart';
import '../models/swap_quote.dart';
import '../services/encrypted_wallet_backup_service.dart';
import '../services/external_wallet_signer_service.dart';
import '../services/solana_wallet_service.dart';
import '../services/backend_api_service.dart';
import '../services/stats_api_service.dart';
import '../services/pin_hashing.dart';
import '../services/security/pin_auth_service.dart';
import '../services/solana_walletconnect_service.dart';
import '../services/user_service.dart';
import '../services/wallet_backup_passkey_service.dart';
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

enum WalletSessionPhase {
  idle,
  restoring,
  ready,
  error,
}

enum WalletAuthorityState {
  signedOut,
  accountShellOnly,
  walletReadOnly,
  localSignerReady,
  externalWalletReady,
  encryptedBackupAvailableSignerMissing,
  recoveryNeeded,
}

enum WalletSignerSource {
  none,
  local,
  external,
}

class WalletAuthoritySnapshot {
  const WalletAuthoritySnapshot({
    required this.state,
    required this.signerSource,
    required this.accountSignedIn,
    required this.signInMethod,
    required this.accountEmail,
    required this.walletAddress,
    required this.hasLocalSigner,
    required this.hasExternalSigner,
    required this.externalWalletConnected,
    required this.externalWalletName,
    required this.hasEncryptedBackup,
    required this.encryptedBackupStatusKnown,
    required this.hasPasskeyProtection,
    required this.mnemonicBackupRequired,
    required this.recoveryNeeded,
  });

  final WalletAuthorityState state;
  final WalletSignerSource signerSource;
  final bool accountSignedIn;
  final AuthSignInMethod signInMethod;
  final String? accountEmail;
  final String? walletAddress;
  final bool hasLocalSigner;
  final bool hasExternalSigner;
  final bool externalWalletConnected;
  final String? externalWalletName;
  final bool hasEncryptedBackup;
  final bool encryptedBackupStatusKnown;
  final bool hasPasskeyProtection;
  final bool mnemonicBackupRequired;
  final bool recoveryNeeded;

  bool get hasWalletIdentity => (walletAddress ?? '').trim().isNotEmpty;
  bool get canUseAccount => accountSignedIn;
  bool get canReadWallet => hasWalletIdentity;
  bool get canTransact =>
      hasWalletIdentity && (hasLocalSigner || hasExternalSigner);
  bool get canRestoreFromEncryptedBackup =>
      hasWalletIdentity && !canTransact && hasEncryptedBackup;
  bool get isReadOnlyWallet => hasWalletIdentity && !canTransact;
}

enum ManagedWalletReconnectOutcome {
  signerRestored,
  readOnlyRefreshed,
  manualConnectRequired,
  noWalletIdentity,
  failed,
}

void _walletLog(String message) {
  if (!kDebugMode) return;
  debugPrint('WalletProvider: $message');
}

class WalletProvider extends ChangeNotifier {
  static const Duration _secureStorageOpTimeout = Duration(milliseconds: 800);

  final SolanaWalletService _solanaWalletService;
  final BackendApiService _apiService = BackendApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final EncryptedWalletBackupService _encryptedWalletBackupService =
      EncryptedWalletBackupService();
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
  WalletSessionPhase _sessionPhase = WalletSessionPhase.idle;
  String? _lastError;
  DerivedKeyPairResult? _cachedDerivedCandidate;
  Completer<void>? _initializeCompleter;
  Future<ManagedWalletReconnectOutcome>? _managedReconnectInFlight;
  EncryptedWalletBackupDefinition? _encryptedWalletBackupDefinition;
  bool _encryptedWalletBackupLoading = false;
  bool _walletBackupRecoveryInProgress = false;
  String? _encryptedWalletBackupError;
  bool _encryptedWalletBackupStatusKnown = false;
  bool _mnemonicBackupRequiredForAuthority = false;
  bool _accountSignedIn = false;
  AuthSignInMethod _accountSignInMethod = AuthSignInMethod.unknown;
  String? _accountEmail;
  String? _externalSignerAddress;
  String? _externalSignerName;

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
  WalletSessionPhase get sessionPhase => _sessionPhase;
  String? get lastError => _lastError;

  WalletProvider(
      {SolanaWalletService? solanaWalletService, bool deferInit = false})
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
    _sessionPhase = WalletSessionPhase.ready;
    notifyListeners();
  }

  @visibleForTesting
  void setEncryptedWalletBackupDefinitionForTesting(
    EncryptedWalletBackupDefinition? definition,
  ) {
    _setEncryptedWalletBackupDefinition(definition);
    notifyListeners();
  }

  @visibleForTesting
  void setEncryptedWalletBackupStatusKnownForTesting(bool known) {
    _encryptedWalletBackupStatusKnown = known;
    notifyListeners();
  }

  Future<void> _init() async {
    _sessionPhase = WalletSessionPhase.restoring;
    _lastError = null;
    await _applySavedNetworkPreference();
    await _loadCachedWallet();
    // If a cached wallet was not loaded, proceed to load data normally
    if (_currentWalletAddress == null) {
      await _loadData();
    }
    _sessionPhase = WalletSessionPhase.ready;
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
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate
          ? BiometricAuthOutcome.success
          : BiometricAuthOutcome.cancelled;
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
      if (code.contains('permanentlylockedout') ||
          code.contains('permanently_locked_out')) {
        return BiometricAuthOutcome.permanentlyLockedOut;
      }
      if (code.contains('temporarylockout') ||
          code.contains('temporary_lockout') ||
          code.contains('biometriclockout')) {
        return BiometricAuthOutcome.lockedOut;
      }
      if (code.contains('usercanceled') ||
          code.contains('user_canceled') ||
          code.contains('usercancel') ||
          code.contains('user_cancel') ||
          code.contains('systemcanceled') ||
          code.contains('system_canceled') ||
          code.contains('canceled') ||
          code.contains('cancelled')) {
        return BiometricAuthOutcome.cancelled;
      }
      if (code.contains('passcode') || code.contains('fallback')) {
        return BiometricAuthOutcome.failed;
      }
      return BiometricAuthOutcome.error;
    } catch (e) {
      _walletLog('biometric auth error: $e');
      return BiometricAuthOutcome.error;
    }
  }

  Future<bool> authenticateWithBiometrics({String? localizedReason}) async {
    final outcome = await authenticateWithBiometricsDetailed(
        localizedReason: localizedReason);
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
      return await _secureStorage
          .read(key: 'cached_mnemonic')
          .timeout(_secureStorageOpTimeout);
    } catch (e) {
      _walletLog('failed to read cached mnemonic: $e');
      return null;
    }
  }

  // Cache mnemonic for 7 days so user doesn't need to re-enter it
  Future<void> _cacheMnemonic(String mnemonic) async {
    try {
      await _secureStorage
          .write(key: 'cached_mnemonic', value: mnemonic)
          .timeout(_secureStorageOpTimeout);
      await _secureStorage
          .write(
            key: 'cached_mnemonic_ts',
            value: DateTime.now().millisecondsSinceEpoch.toString(),
          )
          .timeout(_secureStorageOpTimeout);
    } catch (e) {
      _walletLog('failed to cache mnemonic: $e');
    }
  }

  Future<void> clearCachedMnemonic() async {
    try {
      await _secureStorage
          .delete(key: 'cached_mnemonic')
          .timeout(_secureStorageOpTimeout);
      await _secureStorage
          .delete(key: 'cached_mnemonic_ts')
          .timeout(_secureStorageOpTimeout);
    } catch (e) {
      _walletLog('failed to clear cached mnemonic: $e');
    }
  }

  Future<void> _loadCachedWallet() async {
    try {
      _walletLog('_loadCachedWallet: starting cached wallet check');
      final mnemonic = await _secureStorage
          .read(key: 'cached_mnemonic')
          .timeout(_secureStorageOpTimeout);
      final tsStr = await _secureStorage
          .read(key: 'cached_mnemonic_ts')
          .timeout(_secureStorageOpTimeout);

      if (mnemonic != null) {
        if (tsStr != null) {
          final ts = int.tryParse(tsStr);
          if (ts != null) {
            final age = DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(ts));

            if (age.inDays < 7) {
              _walletLog(
                  'cached mnemonic within TTL; validating before import');
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
                  _walletLog(
                      'failed to set active keypair from cached mnemonic: $e');
                }
                _currentWalletAddress = derived.address;
                SolanaWalletConnectService.instance
                    .updateActiveWalletAddress(_currentWalletAddress);

                // Save to SharedPreferences for profile provider
                await _persistWalletIdentity(_currentWalletAddress!);
                _apiService.setPreferredWalletAddress(_currentWalletAddress);

                notifyListeners();
                // Attempt to load data in background (don't block startup)
                _loadData().then((_) {
                  notifyListeners();
                });
              } catch (e) {
                _walletLog('failed to derive keypair from cached mnemonic: $e');
              }

              // Attempt import of full wallet state; if it fails, schedule retries.
              final success =
                  await _attemptImportFromCache(mnemonic, derived: derived);
              if (success) return;
              _scheduleImportRetry(mnemonic);
            } else {
              // expired
              await clearCachedMnemonic();
            }
          }
        } else {
          // No timestamp present but mnemonic exists — try to import and set timestamp on success.
          _walletLog(
              'cached mnemonic present without timestamp; attempting import');
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
              _walletLog(
                  'failed to set active keypair from cached mnemonic (no timestamp): $e');
            }
            _currentWalletAddress = derived.address;
            SolanaWalletConnectService.instance
                .updateActiveWalletAddress(_currentWalletAddress);
            await _persistWalletIdentity(_currentWalletAddress!);
            _apiService.setPreferredWalletAddress(_currentWalletAddress);
            notifyListeners();
            _loadData();
          } catch (e) {
            _walletLog(
                'failed to derive keypair from cached mnemonic (no timestamp): $e');
          }

          final success =
              await _attemptImportFromCache(mnemonic, derived: derived);
          if (success) {
            // Set a fresh timestamp so subsequent runs treat it as recent
            try {
              await _secureStorage.write(
                  key: 'cached_mnemonic_ts',
                  value: DateTime.now().millisecondsSinceEpoch.toString());
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
          _apiService.setPreferredWalletAddress(storedAddress);
          await _loadData();
        }
      } catch (e) {
        _walletLog('fallback restore failed: $e');
      }
    }
  }

  // Attempt import immediately (returns true on success)
  Future<bool> _attemptImportFromCache(String mnemonic,
      {DerivedKeyPairResult? derived}) async {
    try {
      final candidate = derived ?? _cachedDerivedCandidate;
      await importWalletFromMnemonic(
        mnemonic,
        preDerived: candidate,
        markBackedUp: false,
      );
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
      final delay =
          Duration(seconds: _baseImportRetryDelay.inSeconds * multiplier);
      _walletLog('scheduling mnemonic import retry in ${delay.inSeconds}s');
      _importRetryTimer = Timer(delay, () async {
        // Only retry if still have cached mnemonic and not imported yet
        final cached = await _secureStorage.read(key: 'cached_mnemonic');
        if (cached == null) return;
        final ok = await _attemptImportFromCache(cached,
            derived: _cachedDerivedCandidate);
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
  bool get hasWalletIdentity =>
      _currentWalletAddress != null && _currentWalletAddress!.isNotEmpty;
  bool get accountSignedIn => authority.accountSignedIn;
  AuthSignInMethod get accountSignInMethod => authority.signInMethod;
  String? get accountEmail => authority.accountEmail;
  bool get hasLocalSigner => _localSignerMatchesCurrentWallet;
  bool get hasExternalSigner => _externalSignerMatchesCurrentWallet;
  bool get hasSigner => hasLocalSigner || hasExternalSigner;
  bool get isReadOnlySession => authority.isReadOnlyWallet;
  bool get canTransact => authority.canTransact;
  bool get isConnected => hasWalletIdentity;
  bool get hasActiveKeyPair => hasLocalSigner;
  String? get externalSignerAddress => _externalSignerAddress;
  String? get externalSignerName => _externalSignerName;
  bool get externalWalletConnected => hasExternalSigner;
  SolanaWalletService get solanaWalletService => _solanaWalletService;
  EncryptedWalletBackupDefinition? get encryptedWalletBackupDefinition =>
      _encryptedWalletBackupDefinition;
  bool get isEncryptedWalletBackupLoading => _encryptedWalletBackupLoading;
  bool get isWalletBackupRecoveryInProgress => _walletBackupRecoveryInProgress;
  String? get encryptedWalletBackupError => _encryptedWalletBackupError;
  bool get hasEncryptedWalletBackup {
    final backup = _encryptedWalletBackupDefinition;
    if (backup == null) return false;
    final targetWallet = (backup.walletAddress).trim();
    if (targetWallet.isEmpty) return false;
    final currentWallet = (_currentWalletAddress ?? '').trim();
    if (currentWallet.isEmpty) return false;
    return WalletUtils.equals(currentWallet, targetWallet);
  }

  DateTime? get encryptedWalletBackupLastVerifiedAt =>
      _encryptedWalletBackupDefinition?.lastVerifiedAt;
  List<WalletBackupPasskeyDefinition> get encryptedWalletBackupPasskeys =>
      _encryptedWalletBackupDefinition?.passkeys ??
      const <WalletBackupPasskeyDefinition>[];
  bool get hasEncryptedWalletBackupPasskey =>
      encryptedWalletBackupPasskeys.isNotEmpty;

  bool get _localSignerMatchesCurrentWallet {
    final signer = (_solanaWalletService.activePublicKey ?? '').trim();
    final wallet = (_currentWalletAddress ?? '').trim();
    if (signer.isEmpty || wallet.isEmpty) return false;
    return WalletUtils.equals(signer, wallet);
  }

  bool get _externalSignerMatchesCurrentWallet {
    final signer = (_externalSignerAddress ?? '').trim();
    final wallet = (_currentWalletAddress ?? '').trim();
    if (signer.isEmpty || wallet.isEmpty) return false;
    return WalletUtils.equals(signer, wallet);
  }

  WalletAuthoritySnapshot get authority {
    final tokenPresent = (_apiService.getAuthToken() ?? '').trim().isNotEmpty;
    final accountSignedIn = _accountSignedIn || tokenPresent;
    final hasWallet = hasWalletIdentity;
    final localReady = _localSignerMatchesCurrentWallet;
    final externalReady = _externalSignerMatchesCurrentWallet;
    final canSign = hasWallet && (localReady || externalReady);
    final hasBackup = hasEncryptedWalletBackup;
    final hasPasskey = hasEncryptedWalletBackupPasskey;
    final recoveryNeeded = hasWallet &&
        !canSign &&
        _encryptedWalletBackupStatusKnown &&
        !hasBackup;

    final WalletAuthorityState state;
    if (canSign && localReady) {
      state = WalletAuthorityState.localSignerReady;
    } else if (canSign && externalReady) {
      state = WalletAuthorityState.externalWalletReady;
    } else if (hasWallet && hasBackup) {
      state = WalletAuthorityState.encryptedBackupAvailableSignerMissing;
    } else if (recoveryNeeded) {
      state = WalletAuthorityState.recoveryNeeded;
    } else if (hasWallet) {
      state = WalletAuthorityState.walletReadOnly;
    } else if (accountSignedIn) {
      state = WalletAuthorityState.accountShellOnly;
    } else {
      state = WalletAuthorityState.signedOut;
    }

    return WalletAuthoritySnapshot(
      state: state,
      signerSource: localReady
          ? WalletSignerSource.local
          : externalReady
              ? WalletSignerSource.external
              : WalletSignerSource.none,
      accountSignedIn: accountSignedIn,
      signInMethod: _accountSignInMethod,
      accountEmail: _accountEmail,
      walletAddress: _currentWalletAddress,
      hasLocalSigner: localReady,
      hasExternalSigner: externalReady,
      externalWalletConnected: externalReady,
      externalWalletName: _externalSignerName,
      hasEncryptedBackup: hasBackup,
      encryptedBackupStatusKnown: _encryptedWalletBackupStatusKnown,
      hasPasskeyProtection: hasPasskey,
      mnemonicBackupRequired: _mnemonicBackupRequiredForAuthority,
      recoveryNeeded: recoveryNeeded,
    );
  }

  void _setLastError(Object error) {
    _lastError = error.toString();
    _sessionPhase = WalletSessionPhase.error;
  }

  void _clearLastError() {
    _lastError = null;
    if (_sessionPhase != WalletSessionPhase.restoring) {
      _sessionPhase = WalletSessionPhase.ready;
    }
  }

  void _setEncryptedWalletBackupDefinition(
    EncryptedWalletBackupDefinition? definition,
  ) {
    _encryptedWalletBackupDefinition = definition;
    _encryptedWalletBackupStatusKnown = true;
    _encryptedWalletBackupError = null;
  }

  void _clearEncryptedWalletBackupState() {
    _encryptedWalletBackupDefinition = null;
    _encryptedWalletBackupLoading = false;
    _walletBackupRecoveryInProgress = false;
    _encryptedWalletBackupError = null;
    _encryptedWalletBackupStatusKnown = false;
  }

  Future<void> _persistWalletIdentity(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_address', address);
    await prefs.setString('walletAddress', address);
    await prefs.setString('wallet', address);
    await prefs.setBool('has_wallet', true);
  }

  String _walletScopedPreferenceKey({
    required String prefix,
    required String walletAddress,
  }) {
    final canonical = WalletUtils.canonical(walletAddress);
    return '$prefix:$canonical';
  }

  Future<String?> _resolveWalletAddressFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromPrefs = (prefs.getString(PreferenceKeys.walletAddress) ??
              prefs.getString('wallet_address') ??
              prefs.getString('walletAddress') ??
              prefs.getString('wallet'))
          ?.trim();
      if (fromPrefs != null && fromPrefs.isNotEmpty) return fromPrefs;
    } catch (e) {
      _walletLog('failed to resolve wallet from prefs: $e');
    }
    return null;
  }

  Future<String?> _resolveWalletForRecovery({String? preferredWallet}) async {
    final preferred = (preferredWallet ?? '').trim();
    if (preferred.isNotEmpty) return preferred;

    final current = (_currentWalletAddress ?? '').trim();
    if (current.isNotEmpty) return current;

    final authWallet = (_apiService.getCurrentAuthWalletAddress() ?? '').trim();
    if (authWallet.isNotEmpty) return authWallet;

    return _resolveWalletAddressFromPrefs();
  }

  Future<bool> isManagedReconnectEligible() async {
    final method = await _apiService.resolveLastSignInMethod();
    return method == AuthSignInMethod.email ||
        method == AuthSignInMethod.google;
  }

  Future<ManagedWalletReconnectOutcome> recoverManagedWalletSession({
    String? walletAddress,
    bool refreshBackendSession = true,
  }) async {
    final inFlight = _managedReconnectInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final reconnectFuture = _recoverManagedWalletSessionInternal(
      walletAddress: walletAddress,
      refreshBackendSession: refreshBackendSession,
    );
    _managedReconnectInFlight = reconnectFuture;
    try {
      return await reconnectFuture;
    } finally {
      if (identical(_managedReconnectInFlight, reconnectFuture)) {
        _managedReconnectInFlight = null;
      }
    }
  }

  Future<ManagedWalletReconnectOutcome> _recoverManagedWalletSessionInternal({
    String? walletAddress,
    bool refreshBackendSession = true,
  }) async {
    final targetWallet = await _resolveWalletForRecovery(
      preferredWallet: walletAddress,
    );
    if (targetWallet == null || targetWallet.isEmpty) {
      return ManagedWalletReconnectOutcome.noWalletIdentity;
    }

    final eligible = await isManagedReconnectEligible();
    if (!eligible) {
      return ManagedWalletReconnectOutcome.manualConnectRequired;
    }

    _lastError = null;
    _sessionPhase = WalletSessionPhase.restoring;
    notifyListeners();

    try {
      if (refreshBackendSession) {
        await _apiService
            .restoreExistingSession(allowRefresh: false)
            .timeout(const Duration(seconds: 4));
      }

      await setReadOnlyWalletIdentity(
        targetWallet,
        loadData: true,
        syncBackend: false,
      );
      if (WalletUtils.equals(_currentWalletAddress, targetWallet) &&
          canTransact) {
        if (refreshBackendSession) {
          await ensureBackendSessionForActiveSigner(walletAddress: targetWallet);
        }
        _clearLastError();
        return ManagedWalletReconnectOutcome.signerRestored;
      }

      final mnemonic = await readCachedMnemonic();
      final normalizedMnemonic = (mnemonic ?? '').trim();
      if (normalizedMnemonic.isEmpty) {
        _clearLastError();
        return ManagedWalletReconnectOutcome.manualConnectRequired;
      }

      if (!_solanaWalletService.validateMnemonic(normalizedMnemonic)) {
        await clearCachedMnemonic();
        _clearLastError();
        return ManagedWalletReconnectOutcome.manualConnectRequired;
      }

      final derived =
          await _solanaWalletService.derivePreferredKeyPair(normalizedMnemonic);
      if (!WalletUtils.equals(derived.address, targetWallet)) {
        _walletLog(
          'managed reconnect: mnemonic wallet mismatch, preserving wallet identity',
        );
        _clearLastError();
        return ManagedWalletReconnectOutcome.manualConnectRequired;
      }

      await importWalletFromMnemonic(
        normalizedMnemonic,
        preDerived: derived,
        markBackedUp: false,
      );
      if (WalletUtils.equals(_currentWalletAddress, targetWallet) &&
          canTransact) {
        if (refreshBackendSession) {
          await ensureBackendSessionForActiveSigner(walletAddress: targetWallet);
        }
        _clearLastError();
        return ManagedWalletReconnectOutcome.signerRestored;
      }

      _clearLastError();
      return ManagedWalletReconnectOutcome.readOnlyRefreshed;
    } catch (e, stackTrace) {
      _walletLog('recoverManagedWalletSession failed: $e\n$stackTrace');
      _setLastError(e);
      return ManagedWalletReconnectOutcome.failed;
    } finally {
      if (_sessionPhase == WalletSessionPhase.restoring) {
        _sessionPhase = WalletSessionPhase.ready;
      }
      notifyListeners();
    }
  }

  Future<void> setMnemonicBackupRequired({
    bool required = true,
    String? walletAddress,
  }) async {
    final targetWallet = (walletAddress ?? _currentWalletAddress ?? '').trim();
    if (targetWallet.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final requiredKey = _walletScopedPreferenceKey(
      prefix: PreferenceKeys.walletMnemonicBackupRequiredV1Prefix,
      walletAddress: targetWallet,
    );
    final backedUpKey = _walletScopedPreferenceKey(
      prefix: PreferenceKeys.walletMnemonicBackedUpV1Prefix,
      walletAddress: targetWallet,
    );

    await prefs.setBool(requiredKey, required);
    if (required) {
      await prefs.setBool(backedUpKey, false);
    }
    if (WalletUtils.equals(targetWallet, _currentWalletAddress)) {
      _mnemonicBackupRequiredForAuthority = required;
      notifyListeners();
    }
  }

  Future<void> markMnemonicBackedUp({String? walletAddress}) async {
    final targetWallet = (walletAddress ?? _currentWalletAddress ?? '').trim();
    if (targetWallet.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final requiredKey = _walletScopedPreferenceKey(
      prefix: PreferenceKeys.walletMnemonicBackupRequiredV1Prefix,
      walletAddress: targetWallet,
    );
    final backedUpKey = _walletScopedPreferenceKey(
      prefix: PreferenceKeys.walletMnemonicBackedUpV1Prefix,
      walletAddress: targetWallet,
    );
    await prefs.setBool(requiredKey, false);
    await prefs.setBool(backedUpKey, true);
    if (WalletUtils.equals(targetWallet, _currentWalletAddress)) {
      _mnemonicBackupRequiredForAuthority = false;
      notifyListeners();
    }
  }

  Future<bool> isMnemonicBackupRequired({String? walletAddress}) async {
    final targetWallet = (walletAddress ?? _currentWalletAddress ?? '').trim();
    if (targetWallet.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final requiredKey = _walletScopedPreferenceKey(
      prefix: PreferenceKeys.walletMnemonicBackupRequiredV1Prefix,
      walletAddress: targetWallet,
    );
    final required = prefs.getBool(requiredKey) ?? false;
    if (WalletUtils.equals(targetWallet, _currentWalletAddress)) {
      _mnemonicBackupRequiredForAuthority = required;
    }
    return required;
  }

  Future<String?> _resolveBackupWalletAddress({String? walletAddress}) async {
    final explicitWallet = (walletAddress ?? '').trim();
    if (explicitWallet.isNotEmpty) return explicitWallet;
    final currentWallet = (_currentWalletAddress ?? '').trim();
    if (currentWallet.isNotEmpty) return currentWallet;
    final authenticatedWallet =
        (await _resolveAuthenticatedWalletAddress() ?? '').trim();
    if (authenticatedWallet.isNotEmpty) return authenticatedWallet;
    return _resolveWalletAddressFromPrefs();
  }

  Future<EncryptedWalletBackupDefinition?> refreshEncryptedWalletBackupStatus({
    String? walletAddress,
    bool notify = true,
  }) async {
    if (!AppConfig.isFeatureEnabled('encryptedWalletBackup')) {
      _clearEncryptedWalletBackupState();
      if (notify) notifyListeners();
      return null;
    }

    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    if (targetWallet.isEmpty) {
      _clearEncryptedWalletBackupState();
      if (notify) notifyListeners();
      return null;
    }

    if (notify) {
      _encryptedWalletBackupLoading = true;
      _encryptedWalletBackupError = null;
      notifyListeners();
    }

    try {
      final definition = await _apiService.getEncryptedWalletBackup(
        walletAddress: targetWallet,
      );
      _setEncryptedWalletBackupDefinition(definition);
      return definition;
    } on BackendApiRequestException catch (e) {
      if (e.statusCode == 404) {
        _setEncryptedWalletBackupDefinition(null);
        return null;
      }
      _encryptedWalletBackupError = e.toString();
      rethrow;
    } catch (e) {
      _encryptedWalletBackupError = e.toString();
      rethrow;
    } finally {
      _encryptedWalletBackupLoading = false;
      if (notify) notifyListeners();
    }
  }

  Future<EncryptedWalletBackupDefinition?> getEncryptedWalletBackup({
    String? walletAddress,
    bool refresh = false,
  }) async {
    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    if (targetWallet.isEmpty) return null;

    final cached = _encryptedWalletBackupDefinition;
    if (!refresh &&
        cached != null &&
        WalletUtils.equals(cached.walletAddress, targetWallet)) {
      return cached;
    }

    return refreshEncryptedWalletBackupStatus(walletAddress: targetWallet);
  }

  Future<EncryptedWalletBackupDefinition> createEncryptedWalletBackup({
    required String recoveryPassword,
    String? walletAddress,
    String? mnemonic,
  }) async {
    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    if (targetWallet.isEmpty) {
      throw const EncryptedWalletBackupException(
        'No wallet is available for backup.',
      );
    }

    final effectiveMnemonic =
        (mnemonic ?? await readCachedMnemonic() ?? '').trim();
    if (effectiveMnemonic.isEmpty) {
      throw const EncryptedWalletBackupException(
        'This device does not have the recovery phrase cached.',
      );
    }

    _encryptedWalletBackupLoading = true;
    _encryptedWalletBackupError = null;
    notifyListeners();
    try {
      final definition =
          await _encryptedWalletBackupService.buildEncryptedBackupDefinition(
        walletAddress: targetWallet,
        mnemonic: effectiveMnemonic,
        recoveryPassword: recoveryPassword,
      );
      final savedDefinition = await _apiService.putEncryptedWalletBackup(
        definition,
      );
      _setEncryptedWalletBackupDefinition(savedDefinition);
      return savedDefinition;
    } catch (e) {
      _encryptedWalletBackupError = e.toString();
      rethrow;
    } finally {
      _encryptedWalletBackupLoading = false;
      notifyListeners();
    }
  }

  @protected
  Future<String> decryptEncryptedWalletBackupMnemonic({
    required EncryptedWalletBackupDefinition backupDefinition,
    required String recoveryPassword,
    required String expectedWalletAddress,
  }) {
    return _encryptedWalletBackupService.decryptMnemonic(
      backupDefinition: backupDefinition,
      recoveryPassword: recoveryPassword,
      expectedWalletAddress: expectedWalletAddress,
    );
  }

  @protected
  Future<void> emitWalletBackupEventBestEffort({
    required String walletAddress,
    required String eventType,
  }) async {
    try {
      await _apiService.emitWalletBackupEvent(
        walletAddress: walletAddress,
        eventType: eventType,
      );
    } catch (e) {
      _walletLog(
        'emitWalletBackupEventBestEffort failed for $eventType: $e',
      );
    }
  }

  Future<String> verifyEncryptedWalletBackup({
    required String recoveryPassword,
    String? walletAddress,
    bool emitSecurityEvent = true,
  }) async {
    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    final definition = await getEncryptedWalletBackup(
      walletAddress: targetWallet,
      refresh: true,
    );
    if (definition == null) {
      throw const EncryptedWalletBackupException(
        'No encrypted backup is configured for this wallet.',
      );
    }

    _encryptedWalletBackupLoading = true;
    _encryptedWalletBackupError = null;
    notifyListeners();
    try {
      final mnemonic = await decryptEncryptedWalletBackupMnemonic(
        backupDefinition: definition,
        recoveryPassword: recoveryPassword,
        expectedWalletAddress: targetWallet,
      );
      _setEncryptedWalletBackupDefinition(
        definition.copyWith(lastVerifiedAt: DateTime.now()),
      );
      if (emitSecurityEvent) {
        await emitWalletBackupEventBestEffort(
          walletAddress: targetWallet,
          eventType: 'backup_verified',
        );
      }
      return mnemonic;
    } catch (e) {
      _encryptedWalletBackupError = e.toString();
      rethrow;
    } finally {
      _encryptedWalletBackupLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEncryptedWalletBackup({String? walletAddress}) async {
    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    if (targetWallet.isEmpty) {
      throw const EncryptedWalletBackupException(
        'No wallet is available for backup deletion.',
      );
    }

    _encryptedWalletBackupLoading = true;
    _encryptedWalletBackupError = null;
    notifyListeners();
    try {
      await _apiService.deleteEncryptedWalletBackup(
          walletAddress: targetWallet);
      if (_encryptedWalletBackupDefinition != null &&
          WalletUtils.equals(
            _encryptedWalletBackupDefinition!.walletAddress,
            targetWallet,
          )) {
        _setEncryptedWalletBackupDefinition(null);
      }
      if (WalletUtils.equals(_currentWalletAddress, targetWallet) &&
          hasSigner) {
        await setMnemonicBackupRequired(
          required: true,
          walletAddress: targetWallet,
        );
      }
    } catch (e) {
      _encryptedWalletBackupError = e.toString();
      rethrow;
    } finally {
      _encryptedWalletBackupLoading = false;
      notifyListeners();
    }
  }

  Future<bool> authenticateEncryptedWalletBackupPasskey({
    String? walletAddress,
  }) async {
    if (!AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') || !kIsWeb) {
      return true;
    }

    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    if (targetWallet.isEmpty) return false;

    final definition = await getEncryptedWalletBackup(
      walletAddress: targetWallet,
      refresh: true,
    );
    if (definition == null) return false;
    if (definition.passkeys.isEmpty) return true;

    final supported = await isWalletBackupPasskeySupported();
    if (!supported) {
      throw const EncryptedWalletBackupException(
        'Passkeys are not available in this browser.',
      );
    }

    final options = await _apiService.getWalletBackupPasskeyAuthOptions(
      walletAddress: targetWallet,
    );
    final assertion = await getWalletBackupPasskeyAssertion(options);
    await _apiService.verifyWalletBackupPasskeyAuth(
      walletAddress: targetWallet,
      responsePayload: assertion,
    );
    await refreshEncryptedWalletBackupStatus(walletAddress: targetWallet);
    return true;
  }

  Future<WalletBackupPasskeyDefinition> enrollEncryptedWalletBackupPasskey({
    required String nickname,
    String? walletAddress,
  }) async {
    if (!AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') || !kIsWeb) {
      throw const EncryptedWalletBackupException(
        'Passkeys are only available on web.',
      );
    }

    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    if (targetWallet.isEmpty) {
      throw const EncryptedWalletBackupException(
        'No wallet is available for passkey enrollment.',
      );
    }

    final supported = await isWalletBackupPasskeySupported();
    if (!supported) {
      throw const EncryptedWalletBackupException(
        'Passkeys are not available in this browser.',
      );
    }

    final options = await _apiService.getWalletBackupPasskeyRegistrationOptions(
      walletAddress: targetWallet,
      nickname: nickname,
    );
    final credential = await createWalletBackupPasskeyCredential(options);
    final verifyResponse =
        await _apiService.verifyWalletBackupPasskeyRegistration(
      walletAddress: targetWallet,
      nickname: nickname,
      responsePayload: credential,
    );
    await refreshEncryptedWalletBackupStatus(walletAddress: targetWallet);

    final passkeyPayload = verifyResponse['passkey'] is Map<String, dynamic>
        ? verifyResponse['passkey'] as Map<String, dynamic>
        : verifyResponse;
    return WalletBackupPasskeyDefinition.fromJson(passkeyPayload);
  }

  Future<bool> restoreSignerFromEncryptedWalletBackup({
    required String recoveryPassword,
    String? walletAddress,
  }) async {
    final targetWallet = (await _resolveBackupWalletAddress(
              walletAddress: walletAddress,
            ) ??
            '')
        .trim();
    if (targetWallet.isEmpty) return false;

    _walletBackupRecoveryInProgress = true;
    _encryptedWalletBackupError = null;
    notifyListeners();
    try {
      final mnemonic = await verifyEncryptedWalletBackup(
        recoveryPassword: recoveryPassword,
        walletAddress: targetWallet,
        emitSecurityEvent: false,
      );
      final derived = await _solanaWalletService.derivePreferredKeyPair(
        mnemonic,
      );
      if (!WalletUtils.equals(derived.address, targetWallet)) {
        throw const EncryptedWalletBackupException(
          'Encrypted backup does not match the selected wallet.',
        );
      }
      await importWalletFromMnemonic(
        mnemonic,
        preDerived: derived,
        markBackedUp: false,
      );
      await refreshEncryptedWalletBackupStatus(walletAddress: targetWallet);
      await emitWalletBackupEventBestEffort(
        walletAddress: targetWallet,
        eventType: 'backup_restored',
      );
      return WalletUtils.equals(_currentWalletAddress, targetWallet) &&
          hasSigner;
    } catch (e) {
      _encryptedWalletBackupError = e.toString();
      rethrow;
    } finally {
      _walletBackupRecoveryInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _clearPersistedWalletIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const <String>[
      'wallet_address',
      'walletAddress',
      'wallet',
      'has_wallet',
    ]) {
      await prefs.remove(key);
    }
  }

  Future<String?> _resolveAuthenticatedWalletAddress() async {
    final authenticatedWallet =
        (_apiService.getCurrentAuthWalletAddress() ?? '').trim();
    return authenticatedWallet.isEmpty ? null : authenticatedWallet;
  }

  Future<bool> restoreAccountShellFromBackend({
    bool allowRefresh = true,
    bool loadWalletData = true,
  }) async {
    final restored = await _apiService.restoreExistingSession(
      allowRefresh: allowRefresh,
    );
    final token = (_apiService.getAuthToken() ?? '').trim();
    _accountSignedIn = restored || token.isNotEmpty;
    _accountSignInMethod = await _apiService.resolveLastSignInMethod();
    _accountEmail = _apiService.getCurrentAuthEmail();

    final accountWallet =
        (_apiService.getCurrentAuthWalletAddress() ?? '').trim();
    if (accountWallet.isNotEmpty) {
      await setReadOnlyWalletIdentity(
        accountWallet,
        loadData: loadWalletData,
        syncBackend: false,
      );
    } else {
      notifyListeners();
    }
    return _accountSignedIn;
  }

  Future<void> clearAccountShell() async {
    _clearAccountShellState();
    notifyListeners();
  }

  void _clearAccountShellState() {
    _accountSignedIn = false;
    _accountSignInMethod = AuthSignInMethod.unknown;
    _accountEmail = null;
  }

  Future<void> setReadOnlyWalletIdentity(
    String address, {
    bool persist = true,
    bool loadData = true,
    bool syncBackend = false,
  }) async {
    final sanitized = address.trim();
    if (sanitized.isEmpty) return;

    final activeSignerAddress =
        (_solanaWalletService.activePublicKey ?? '').trim();
    if (activeSignerAddress.isNotEmpty &&
        !WalletUtils.equals(activeSignerAddress, sanitized)) {
      _solanaWalletService.clearActiveKeyPair();
      _cachedDerivedCandidate = null;
    }
    if ((_externalSignerAddress ?? '').trim().isNotEmpty &&
        !WalletUtils.equals(_externalSignerAddress, sanitized)) {
      await clearExternalSigner(notify: false);
    }
    if (!WalletUtils.equals(_currentWalletAddress, sanitized)) {
      _clearEncryptedWalletBackupState();
      _mnemonicBackupRequiredForAuthority = false;
    }

    _lastError = null;
    _sessionPhase = WalletSessionPhase.restoring;
    _currentWalletAddress = sanitized;

    if (persist) {
      try {
        await _persistWalletIdentity(sanitized);
      } catch (e) {
        _walletLog('setReadOnlyWalletIdentity: persist failed: $e');
      }
    }
    _apiService.setPreferredWalletAddress(sanitized);

    try {
      await isMnemonicBackupRequired(walletAddress: sanitized);
    } catch (_) {}
    unawaited(
      refreshEncryptedWalletBackupStatus(
        walletAddress: sanitized,
        notify: true,
      ).catchError((Object error, StackTrace stackTrace) {
        _walletLog(
          'setReadOnlyWalletIdentity: encrypted backup status refresh failed: $error',
        );
        return null;
      }),
    );

    if (loadData) {
      await _loadData();
    }
    if (syncBackend) {
      await _syncBackendData(sanitized);
    }
    _clearLastError();
    notifyListeners();
  }

  Future<ExternalWalletConnectionResult> connectExternalWallet(
    BuildContext context, {
    bool allowReplacingWalletIdentity = false,
  }) async {
    final result = await ExternalWalletSignerService.instance.connect(context);
    await bindExternalSigner(
      address: result.address,
      walletName: result.walletName,
      allowReplacingWalletIdentity: allowReplacingWalletIdentity,
    );
    return result;
  }

  Future<void> bindExternalSigner({
    required String address,
    String? walletName,
    bool allowReplacingWalletIdentity = false,
  }) async {
    final sanitized = address.trim();
    if (sanitized.isEmpty) {
      throw ArgumentError('External wallet address cannot be empty');
    }
    final current = (_currentWalletAddress ?? '').trim();
    if (current.isNotEmpty &&
        !WalletUtils.equals(current, sanitized) &&
        !allowReplacingWalletIdentity) {
      throw StateError('External wallet must match the account wallet.');
    }
    if (current.isEmpty ||
        (allowReplacingWalletIdentity &&
            !WalletUtils.equals(current, sanitized))) {
      await setReadOnlyWalletIdentity(
        sanitized,
        loadData: true,
        syncBackend: true,
      );
    }

    _externalSignerAddress = sanitized;
    final label = (walletName ?? '').trim();
    _externalSignerName = label.isEmpty ? 'External wallet' : label;
    _apiService.setPreferredWalletAddress(sanitized);
    notifyListeners();
  }

  Future<void> clearExternalSigner({bool notify = true}) async {
    _externalSignerAddress = null;
    _externalSignerName = null;
    if (notify) notifyListeners();
  }

  Future<bool> dispatchExternalWalletReturn(Uri uri) async {
    final handled = await ExternalWalletSignerService.instance.dispatchEnvelope(
      uri,
    );
    if (handled) {
      final address = ExternalWalletSignerService.instance.connectedAddress;
      if ((address ?? '').trim().isNotEmpty) {
        await bindExternalSigner(
          address: address!,
          walletName: ExternalWalletSignerService.instance.connectedWalletName,
        );
      }
    }
    return handled;
  }

  Future<void> _loadData() async {
    _isLoading = true;
    _sessionPhase = WalletSessionPhase.restoring;
    notifyListeners();

    _walletLog('_loadData: starting');

    try {
      _walletLog('_loadData: loading from blockchain');
      await _loadFromBlockchain();
      _clearLastError();
    } catch (e) {
      _walletLog('error loading wallet data: $e');
      _setLastError(e);
    } finally {
      _isLoading = false;
      if (_sessionPhase == WalletSessionPhase.restoring) {
        _sessionPhase = WalletSessionPhase.ready;
      }
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
      _setLastError(e);
    }
  }

  Future<void> _loadSolanaWallet(String address) async {
    try {
      final solBalance = await _solanaWalletService.getBalance(address);
      final tokenBalances =
          await _solanaWalletService.getTokenBalances(address);
      final transactionHistory =
          await _solanaWalletService.getTransactionHistory(address);

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
          logoUrl:
              'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
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
      _transactions = transactionHistory
          .map((tx) => WalletTransaction(
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
              ))
          .toList();

      _wallet = Wallet(
        id: 'wallet_${address.substring(0, 8)}',
        address: address,
        name: 'Solana Wallet',
        network: 'Solana',
        tokens: _tokens,
        transactions: _transactions,
        totalValue: _tokens.fold(0.0, (sum, token) => sum + token.value),
        lastUpdated: DateTime.now(),
      );

      await _syncBackendData(address);
      _clearLastError();
    } catch (e) {
      _walletLog('error loading Solana wallet: $e');
      _setLastError(e);
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
                  username: 'user_${address.substring(0, 6)}',
                );
                _walletLog('_syncBackendData: registerWallet response: $reg');
                try {
                  _backendProfile =
                      await _apiService.getProfileByWallet(address);
                } catch (_) {
                  final user2 = await UserService.getUserById(address,
                      forceRefresh: true);
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
          metrics: const [
            'collections',
            'achievementsUnlocked',
            'achievementTokensTotal'
          ],
          scope: 'public',
        );
        _collectionsCount = snapshot.counters['collections'] ?? 0;
        _achievementsUnlocked = snapshot.counters['achievementsUnlocked'] ?? 0;
        _achievementTokenTotal =
            (snapshot.counters['achievementTokensTotal'] ?? 0).toDouble();
      } catch (e) {
        _walletLog('stats snapshot fetch failed: $e');
      }

      // Keep backend auth aligned only when this provider owns signer
      // authority. Profile bootstrap above is separate from session issuance.
      try {
        if (await ensureBackendSessionForActiveSigner(walletAddress: address)) {
          _walletLog('_syncBackendData: signer-backed session ensured');
        } else if (AppConfig.enableDebugIssueToken) {
          final issued = await _apiService.issueDebugTokenForWallet(address);
          _walletLog('_syncBackendData: debug token issued=$issued');
          if (issued) await _apiService.loadAuthToken();
        }
      } catch (e) {
        _walletLog('_syncBackendData: session ensure failed: $e');
      }

      notifyListeners();
    } catch (e) {
      _walletLog('backend sync error: $e');
      _setLastError(e);
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

    if (normalized == 'native' ||
        normalized == ApiKeys.wrappedSolMintAddress.toLowerCase()) {
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
    if (!canTransact ||
        _currentWalletAddress == null ||
        _currentWalletAddress!.isEmpty) {
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
        throw Exception(
            'Insufficient balance. Needed $totalRequired $token including fees.');
      }

      String? signature;
      final isSol = token.toUpperCase() == 'SOL';
      final tokenMeta = getTokenBySymbol(token);
      final decimals = tokenMeta?.decimals ?? ApiKeys.kub8Decimals;
      final mint = tokenMeta?.contractAddress ?? ApiKeys.kub8MintAddress;

      if (hasExternalSigner && !hasLocalSigner) {
        final externalSigner = ExternalWalletSignerService.instance;
        if (isSol) {
          final tx =
              await _solanaWalletService.buildTransferSolTransactionBase64(
            fromAddress: _currentWalletAddress!,
            toAddress: toAddress,
            amount: amount,
          );
          signature = await externalSigner.signAndSendTransactionBase64(tx);
        } else {
          final tx =
              await _solanaWalletService.buildTransferSplTokenTransactionBase64(
            fromAddress: _currentWalletAddress!,
            mint: mint,
            toAddress: toAddress,
            amount: amount,
            decimals: decimals,
          );
          signature = await externalSigner.signAndSendTransactionBase64(tx);
        }
      } else if (isSol) {
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
        if (hasExternalSigner && !hasLocalSigner) {
          final tx = isSol
              ? await _solanaWalletService.buildTransferSolTransactionBase64(
                  fromAddress: _currentWalletAddress!,
                  toAddress: ApiKeys.kubusTeamWallet,
                  amount: feeTeam,
                )
              : await _solanaWalletService
                  .buildTransferSplTokenTransactionBase64(
                  fromAddress: _currentWalletAddress!,
                  mint: mint,
                  toAddress: ApiKeys.kubusTeamWallet,
                  amount: feeTeam,
                  decimals: decimals,
                );
          await ExternalWalletSignerService.instance
              .signAndSendTransactionBase64(tx);
        } else if (isSol) {
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
        if (hasExternalSigner && !hasLocalSigner) {
          final tx = isSol
              ? await _solanaWalletService.buildTransferSolTransactionBase64(
                  fromAddress: _currentWalletAddress!,
                  toAddress: ApiKeys.kubusTreasuryWallet,
                  amount: feeTreasury,
                )
              : await _solanaWalletService
                  .buildTransferSplTokenTransactionBase64(
                  fromAddress: _currentWalletAddress!,
                  mint: mint,
                  toAddress: ApiKeys.kubusTreasuryWallet,
                  amount: feeTreasury,
                  decimals: decimals,
                );
          await ExternalWalletSignerService.instance
              .signAndSendTransactionBase64(tx);
        } else if (isSol) {
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

  Future<String> signMessage(String message) async {
    if (!canTransact) {
      throw StateError('A ready signer is required to sign messages.');
    }
    final encoded = base64Encode(utf8.encode(message));
    if (hasLocalSigner) {
      return _solanaWalletService.signMessageBase64(encoded);
    }
    return ExternalWalletSignerService.instance.signMessageBase64(encoded);
  }

  Future<bool> ensureBackendSessionForActiveSigner({
    String? walletAddress,
  }) async {
    final targetWallet = (walletAddress ?? _currentWalletAddress ?? '').trim();
    if (targetWallet.isEmpty ||
        !canTransact ||
        !WalletUtils.equals(_currentWalletAddress, targetWallet)) {
      return false;
    }

    try {
      _apiService.setPreferredWalletAddress(targetWallet);
      await _apiService.ensureSessionForActiveSigner(
        walletAddress: targetWallet,
        signMessage: signMessage,
      );
      final authWallet =
          (_apiService.getCurrentAuthWalletAddress() ?? '').trim();
      return (_apiService.getAuthToken() ?? '').trim().isNotEmpty &&
          WalletUtils.equals(authWallet, targetWallet);
    } catch (e) {
      _walletLog('ensureBackendSessionForActiveSigner failed: $e');
      return false;
    }
  }

  Future<String> signTransactionBase64(String transactionBase64) async {
    if (!canTransact) {
      throw StateError('A ready signer is required to sign transactions.');
    }
    if (hasLocalSigner) {
      return _solanaWalletService.signTransactionBase64(transactionBase64);
    }
    return ExternalWalletSignerService.instance.signTransactionBase64(
      transactionBase64,
    );
  }

  Future<String> signAndSendTransactionBase64(String transactionBase64) async {
    if (!canTransact) {
      throw StateError('A ready signer is required to submit transactions.');
    }
    if (hasLocalSigner) {
      return _solanaWalletService.signAndSendTransactionBase64(
        transactionBase64,
      );
    }
    return ExternalWalletSignerService.instance.signAndSendTransactionBase64(
      transactionBase64,
    );
  }

  Future<void> swapTokens({
    required String fromToken,
    required String toToken,
    required double fromAmount,
    required double toAmount,
    double? slippage,
  }) async {
    if (!canTransact ||
        _currentWalletAddress == null ||
        _currentWalletAddress!.isEmpty) {
      throw Exception('Connect wallet before swapping');
    }
    if (fromAmount <= 0 || toAmount <= 0) {
      throw Exception('Swap amounts must be greater than zero');
    }

    try {
      // Simple SOL -> SPL swap via Jupiter (SolanaWalletService).
      String? signature;
      final useExternalSigner = hasExternalSigner && !hasLocalSigner;
      if (useExternalSigner) {
        final inputMint = fromToken.toUpperCase() == 'SOL'
            ? ApiKeys.wrappedSolMintAddress
            : getTokenBySymbol(fromToken)?.contractAddress ?? fromToken;
        final outputMint =
            getTokenBySymbol(toToken)?.contractAddress ?? toToken;
        final inputDecimals = fromToken.toUpperCase() == 'SOL'
            ? 9
            : getTokenBySymbol(fromToken)?.decimals ?? ApiKeys.kub8Decimals;
        final tx = await _solanaWalletService.buildJupiterSwapTransactionBase64(
          userPublicKey: _currentWalletAddress!,
          inputMint: inputMint,
          outputMint: outputMint,
          inputAmountRaw: (fromAmount * pow(10, inputDecimals)).round(),
          slippageBps:
              (((slippage ?? 0.01) * 10000).round()).clamp(1, 5000).toInt(),
          wrapAndUnwrapSol: fromToken.toUpperCase() == 'SOL' ||
              toToken.toUpperCase() == 'SOL',
        );
        signature = await ExternalWalletSignerService.instance
            .signAndSendTransactionBase64(tx);
      } else if (fromToken.toUpperCase() == 'SOL') {
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
        if (useExternalSigner) {
          final mint = getTokenBySymbol(toToken)?.contractAddress ?? toToken;
          final decimals =
              getTokenBySymbol(toToken)?.decimals ?? ApiKeys.kub8Decimals;
          final tx =
              await _solanaWalletService.buildTransferSplTokenTransactionBase64(
            fromAddress: _currentWalletAddress!,
            mint: mint,
            toAddress: ApiKeys.kubusTeamWallet,
            amount: feeTeam,
            decimals: decimals,
          );
          await ExternalWalletSignerService.instance
              .signAndSendTransactionBase64(tx);
        } else {
          await _solanaWalletService.transferSplToken(
            mint: getTokenBySymbol(toToken)?.contractAddress ?? toToken,
            toAddress: ApiKeys.kubusTeamWallet,
            amount: feeTeam,
            decimals:
                getTokenBySymbol(toToken)?.decimals ?? ApiKeys.kub8Decimals,
          );
        }
      }
      if (feeTreasury > 0) {
        if (useExternalSigner) {
          final mint = getTokenBySymbol(toToken)?.contractAddress ?? toToken;
          final decimals =
              getTokenBySymbol(toToken)?.decimals ?? ApiKeys.kub8Decimals;
          final tx =
              await _solanaWalletService.buildTransferSplTokenTransactionBase64(
            fromAddress: _currentWalletAddress!,
            mint: mint,
            toAddress: ApiKeys.kubusTreasuryWallet,
            amount: feeTreasury,
            decimals: decimals,
          );
          await ExternalWalletSignerService.instance
              .signAndSendTransactionBase64(tx);
        } else {
          await _solanaWalletService.transferSplToken(
            mint: getTokenBySymbol(toToken)?.contractAddress ?? toToken,
            toAddress: ApiKeys.kubusTreasuryWallet,
            amount: feeTreasury,
            decimals:
                getTokenBySymbol(toToken)?.decimals ?? ApiKeys.kub8Decimals,
          );
        }
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
    final receivedTransactions =
        getTransactionsByType(TransactionType.receive).length;
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
    _lastError = null;
    _sessionPhase = WalletSessionPhase.restoring;
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
    await clearExternalSigner(notify: false);
    _setEncryptedWalletBackupDefinition(null);
    SolanaWalletConnectService.instance
        .updateActiveWalletAddress(_currentWalletAddress);
    // Persist address for other providers/screens
    try {
      await _persistWalletIdentity(_currentWalletAddress!);
      _apiService.setPreferredWalletAddress(_currentWalletAddress);
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
    try {
      await setMnemonicBackupRequired(
        required: true,
        walletAddress: _currentWalletAddress,
      );
    } catch (e) {
      _walletLog('createWallet: failed to persist backup-required flag: $e');
    }

    _clearLastError();
    notifyListeners();

    return {
      'mnemonic': mnemonic,
      'address': _currentWalletAddress!,
    };
  }

  Future<String> deriveWalletAddressFromMnemonic(String mnemonic) async {
    final normalizedMnemonic = mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ');
    final derived =
        await _solanaWalletService.derivePreferredKeyPair(normalizedMnemonic);
    return derived.address;
  }

  Future<String> importWalletFromMnemonic(
    String mnemonic, {
    DerivedKeyPairResult? preDerived,
    bool markBackedUp = true,
  }) async {
    _walletLog('importWalletFromMnemonic start');
    _lastError = null;
    _sessionPhase = WalletSessionPhase.restoring;

    if (!_solanaWalletService.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    final derived = preDerived ??
        await _solanaWalletService.derivePreferredKeyPair(
          mnemonic,
        );
    try {
      _solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
      _walletLog('active keypair set for imported wallet');
    } catch (e) {
      _walletLog('failed to set active keypair for imported wallet: $e');
    }
    _currentWalletAddress = derived.address;
    await clearExternalSigner(notify: false);
    _setEncryptedWalletBackupDefinition(null);
    SolanaWalletConnectService.instance
        .updateActiveWalletAddress(_currentWalletAddress);
    // Wallet address set.

    // Save to SharedPreferences for profile provider
    try {
      await _persistWalletIdentity(_currentWalletAddress!);
      _apiService.setPreferredWalletAddress(_currentWalletAddress);
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
    if (markBackedUp) {
      try {
        await markMnemonicBackedUp(walletAddress: _currentWalletAddress);
      } catch (e) {
        _walletLog(
            'importWalletFromMnemonic: failed to mark backup complete: $e');
      }
    }

    // Final notification to update all listeners
    _walletLog('wallet import complete');
    _clearLastError();
    notifyListeners();

    return _currentWalletAddress!;
  }

  Future<void> connectWalletWithAddress(String address) async {
    await setReadOnlyWalletIdentity(
      address,
      loadData: true,
      syncBackend: true,
    );
  }

  Future<void> disconnectWallet(
      {bool preserveAuthenticatedWallet = true}) async {
    final fallbackWallet = preserveAuthenticatedWallet
        ? await _resolveAuthenticatedWalletAddress()
        : null;

    _solanaWalletService.clearActiveKeyPair();
    SolanaWalletConnectService.instance.updateActiveWalletAddress(null);
    await clearExternalSigner(notify: false);
    _currentWalletAddress = null;
    _wallet = null;
    _tokens.clear();
    _transactions.clear();
    _backendProfile = null;
    _collectionsCount = 0;
    _achievementsUnlocked = 0;
    _achievementTokenTotal = 0.0;
    _cachedDerivedCandidate = null;
    _clearEncryptedWalletBackupState();
    // Clear cached mnemonic on explicit disconnect for security
    try {
      await clearCachedMnemonic();
    } catch (_) {}
    // Cancel any pending import retry timers
    try {
      _importRetryTimer?.cancel();
      _importRetryTimer = null;
      _importRetryAttempts = 0;
    } catch (_) {}

    try {
      await _clearPersistedWalletIdentity();
    } catch (e) {
      _walletLog('disconnectWallet: failed to clear wallet identity: $e');
    }
    try {
      await SolanaWalletConnectService.instance
          .disconnect()
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      _walletLog('disconnectWallet: walletconnect cleanup failed: $e');
    }
    try {
      await ExternalWalletSignerService.instance
          .disconnect()
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      _walletLog('disconnectWallet: external signer cleanup failed: $e');
    }

    final nextWallet = (fallbackWallet ?? '').trim();
    if (nextWallet.isNotEmpty) {
      _currentWalletAddress = nextWallet;
      SolanaWalletConnectService.instance.updateActiveWalletAddress(nextWallet);
      try {
        await _persistWalletIdentity(nextWallet);
      } catch (e) {
        _walletLog('disconnectWallet: failed to persist read-only wallet: $e');
      }
      _apiService.setPreferredWalletAddress(nextWallet);
      await _loadData();
      _clearLastError();
    } else {
      _apiService.setPreferredWalletAddress(null);
      _clearAccountShellState();
      _sessionPhase = WalletSessionPhase.ready;
      _lastError = null;
    }
    notifyListeners();
  }

  // Solana-specific methods
  Future<void> requestAirdrop(double amount) async {
    if (_currentWalletAddress == null) {
      throw Exception('No wallet connected');
    }

    await _solanaWalletService.requestAirdrop(_currentWalletAddress!,
        amount: amount);

    // Refresh wallet data after airdrop
    await refreshData();
  }

  void switchSolanaNetwork(String network) {
    _solanaWalletService.switchNetwork(network);

    // Refresh data with new network
    if (_currentWalletAddress != null) {
      unawaited(_loadData());
    }
    _clearLastError();
    notifyListeners();
  }

  String get currentSolanaNetwork => _solanaWalletService.currentNetwork;

  String _resolveMintAddress(Token token) {
    if (token.symbol.toUpperCase() == 'SOL' ||
        token.contractAddress.toLowerCase() == 'native') {
      return ApiKeys.wrappedSolMintAddress;
    }
    return token.contractAddress;
  }
}
