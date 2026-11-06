import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/wallet_utils.dart';
import 'backend_api_service.dart';
import 'wallet_session_sync_dependencies.dart';

/// Raised when the account-wallet link transaction cannot start because the
/// caller is missing required authenticated-account state.
class AccountWalletLinkStateException implements Exception {
  const AccountWalletLinkStateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised when `/api/profiles/me` does not prove that the original account
/// now owns the wallet (user id changed, wallet mismatch, fetch failed).
class AccountWalletLinkVerificationException implements Exception {
  const AccountWalletLinkVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised when the originating account or session generation ended while the
/// link was in progress.
///
/// This is not a link failure. Nothing is written or restored for the
/// originating account after it is raised, and UI must not show failure copy
/// for it: the account the user is now in owns the state.
class AccountWalletLinkSupersededException implements Exception {
  const AccountWalletLinkSupersededException();

  @override
  String toString() => 'The account session changed during the wallet link.';
}

/// Verified outcome of a wallet -> existing-account link transaction.
class AccountWalletLinkResult {
  const AccountWalletLinkResult({
    required this.userId,
    required this.walletAddress,
    required this.profilePayload,
    required this.bindPayload,
  });

  /// The server account id (`users.id`) proven to own [walletAddress].
  final String userId;

  /// The wallet now linked to [userId].
  final String walletAddress;

  /// Raw `/api/profiles/me` payload used for verification.
  final Map<String, dynamic> profilePayload;

  /// Raw `/api/auth/bind-wallet` response payload.
  final Map<String, dynamic> bindPayload;
}

/// Strict account-link transaction used by onboarding WalletConnect.
///
/// Inside Google/email onboarding, connecting a wallet is an account-link
/// operation against the already-authenticated account — never a wallet
/// login/register. This service:
///
/// 1. Forces the original account token back onto [BackendApiService]
///    before any backend call (wallet creation may have polluted it).
/// 2. Proves wallet ownership: requests `/api/auth/challenge` for the wallet
///    and signs it with the active signer. The backend rejects any
///    `/api/auth/bind-wallet` from a non-wallet-signed (Google/email) session
///    that does not carry this challenge signature.
/// 3. POSTs `/api/auth/bind-wallet` with the signature under that token, once.
/// 4. Persists the bind response token.
/// 5. GETs `/api/profiles/me` and verifies the returned `userId` equals the
///    original account id and the returned wallet equals the linked wallet.
/// 6. Only after verification commits local state: profile and chat hydration
///    (network, outside the auth-session lease), then the account-scoped prefs
///    and provider identity under [BackendApiService.withAuthSessionLease].
///
/// Every stage after an await re-checks that the originating account and
/// session generation are still current before it writes or notifies. A stale
/// stage raises [AccountWalletLinkSupersededException] instead of a failure.
///
/// Before the bind request, failures leave the remote account untouched. Once
/// the bind request is sent, a transport or verification failure can leave the
/// remote result indeterminate; callers must ask the user to check account
/// wallet status before retrying. The bind is never retried automatically.
/// This service must never navigate.
class AccountWalletLinkService {
  AccountWalletLinkService({
    BackendApiService? backendApi,
    Future<Map<String, dynamic>> Function(
      String walletAddress, {
      String? signature,
    })? bindWallet,
    Future<Map<String, dynamic>> Function()? fetchMyProfile,
    Future<String> Function(String walletAddress)? signWalletChallenge,
  })  : _backendApi = backendApi ?? BackendApiService(),
        _bindWalletOverride = bindWallet,
        _fetchMyProfileOverride = fetchMyProfile,
        _signWalletChallengeOverride = signWalletChallenge;

  final BackendApiService _backendApi;
  final Future<Map<String, dynamic>> Function(
    String walletAddress, {
    String? signature,
  })? _bindWalletOverride;
  final Future<Map<String, dynamic>> Function()? _fetchMyProfileOverride;
  final Future<String> Function(String walletAddress)?
      _signWalletChallengeOverride;

  static const Duration _bindTimeout = Duration(seconds: 10);
  static const Duration _verifyTimeout = Duration(seconds: 8);

  /// External wallets need user approval to sign the ownership challenge, so
  /// the proof step gets a much longer budget than the bind call itself.
  static const Duration _challengeSignTimeout = Duration(minutes: 2);

  /// Account-scoped preference keys written by the verified commit. They are
  /// written and rolled back only inside the auth-session lease.
  static const List<String> _accountPrefKeys = <String>[
    'wallet_address',
    'walletAddress',
    'wallet',
    'has_wallet',
    'user_id',
  ];

  Future<AccountWalletLinkResult> linkWalletToCurrentAccount({
    required String walletAddress,
    required String expectedUserId,
    required String originalAuthToken,
    String? originalRefreshToken,
    WalletSessionSyncProvidersPayload? providers,
  }) async {
    final walletProvider = providers?.walletProvider;
    final generation = walletProvider?.beginAccountWalletLink();
    try {
      final result = await _performWalletLink(
        walletAddress: walletAddress,
        expectedUserId: expectedUserId,
        originalAuthToken: originalAuthToken,
        originalRefreshToken: originalRefreshToken,
        providers: providers,
        linkGeneration: generation,
      );
      if (generation != null) {
        walletProvider?.completeAccountWalletLink(generation);
      }
      return result;
    } on AccountWalletLinkSupersededException {
      // The account moved on. The link phase is cleared, never marked failed.
      if (generation != null) {
        walletProvider?.completeAccountWalletLink(generation);
      }
      rethrow;
    } catch (_) {
      if (generation != null) {
        walletProvider?.failAccountWalletLink(generation);
      }
      rethrow;
    }
  }

  Future<AccountWalletLinkResult> _performWalletLink({
    required String walletAddress,
    required String expectedUserId,
    required String originalAuthToken,
    String? originalRefreshToken,
    WalletSessionSyncProvidersPayload? providers,
    required int? linkGeneration,
  }) async {
    final normalizedWallet = walletAddress.trim();
    final normalizedUserId = expectedUserId.trim();
    final normalizedToken = originalAuthToken.trim();

    if (normalizedUserId.isEmpty) {
      throw const AccountWalletLinkStateException(
        'Your account session is missing. Sign in again from this screen before linking a wallet.',
      );
    }
    if (normalizedToken.isEmpty) {
      throw const AccountWalletLinkStateException(
        'Your account session expired. Refresh your session before linking a wallet.',
      );
    }
    if (normalizedWallet.isEmpty ||
        normalizedWallet.toLowerCase().startsWith('linked_auth:') ||
        !WalletUtils.looksLikeWallet(normalizedWallet)) {
      throw const AccountWalletLinkStateException(
        'A real public wallet address is required to link this account.',
      );
    }

    final walletProvider = providers?.walletProvider;
    // The link belongs to one account session generation. Every token commit
    // advances the epoch, so it is re-captured after each commit this link makes.
    var sessionEpoch = _backendApi.authSessionEpoch;
    bool isCurrent() {
      if (sessionEpoch != _backendApi.authSessionEpoch) return false;
      if (linkGeneration == null || walletProvider == null) return true;
      return walletProvider.isAccountWalletLinkAttemptCurrent(linkGeneration);
    }

    void ensureCurrent() {
      if (!isCurrent()) throw const AccountWalletLinkSupersededException();
    }

    // Once the bind request is issued, the remote outcome is unknown to this
    // session. A session that ends before a verdict must surface that unverified
    // outcome, never a silent superseded result. Pre-bind stages stay silent.
    AccountWalletLinkVerificationException unverifiedBindOutcome(
        String? detail) {
      return AccountWalletLinkVerificationException(
        'The wallet link request could not be confirmed. It may have reached '
        'the server. Check your account wallet status before trying again.'
        '${detail == null ? '' : ' Request error: $detail'}',
      );
    }

    // Force the original Google/email account token back before binding. A
    // wallet create/import/connect must never decide which account binds.
    try {
      await _backendApi.setAuthToken(normalizedToken,
          expectedEpoch: sessionEpoch);
    } on StateError {
      ensureCurrent();
      rethrow;
    }
    sessionEpoch = _backendApi.authSessionEpoch;
    final refreshToken = (originalRefreshToken ?? '').trim();
    if (refreshToken.isNotEmpty) {
      await _backendApi.setRefreshToken(refreshToken,
          forAccessToken: normalizedToken);
      ensureCurrent();
    }

    // Prove wallet ownership before binding. The backend requires a signed
    // challenge from non-wallet-signed sessions; without it every bind from a
    // Google/email onboarding session fails with 400. When a bind override is
    // injected without a signing override, the override owns the proof.
    String? walletProofSignature;
    if (_signWalletChallengeOverride != null || _bindWalletOverride == null) {
      try {
        walletProofSignature = await (_signWalletChallengeOverride != null
                ? _signWalletChallengeOverride(normalizedWallet)
                : _signChallengeWithActiveSigner(
                    walletProvider,
                    normalizedWallet,
                  ))
            .timeout(_challengeSignTimeout);
      } catch (_) {
        ensureCurrent();
        await _restoreOriginalToken(normalizedToken, refreshToken,
            expectedEpoch: sessionEpoch);
        rethrow;
      }
      ensureCurrent();
    }

    // Single bind attempt. Any failure after this point is ambiguous: the
    // server may already have linked the wallet, so the copy below asks the user
    // to check status and no retry happens here.
    Map<String, dynamic> bindPayload;
    try {
      bindPayload = await (_bindWalletOverride != null
              ? _bindWalletOverride(
                  normalizedWallet,
                  signature: walletProofSignature,
                )
              : _backendApi.bindAuthenticatedWallet(
                  normalizedWallet,
                  signature: walletProofSignature,
                ))
          .timeout(_bindTimeout);
    } catch (error) {
      if (isCurrent()) {
        await _restoreOriginalToken(normalizedToken, refreshToken,
            expectedEpoch: sessionEpoch);
      }
      throw unverifiedBindOutcome('$error');
    }

    final payload =
        bindPayload['data'] is Map ? bindPayload['data'] as Map : bindPayload;
    final returnedToken =
        (payload['token'] ?? bindPayload['token'] ?? '').toString();
    // The default transport commits its own guarded token pair, which advances
    // the epoch. Only a token that the current session already holds is
    // accepted as that commit. Otherwise the epoch must be unchanged.
    final committedByTransport =
        returnedToken.isNotEmpty && returnedToken == _backendApi.getAuthToken();
    if (!committedByTransport) {
      if (!isCurrent()) throw unverifiedBindOutcome(null);
      if (returnedToken.isNotEmpty) {
        try {
          await _backendApi.persistAuthTokensFromResponse(bindPayload,
              sessionEpoch: sessionEpoch);
        } catch (_) {
          // A failed token commit clears the session, so this is unverified
          // whether or not the session moved on its own.
          if (isCurrent()) {
            await _restoreOriginalToken(normalizedToken, refreshToken,
                expectedEpoch: sessionEpoch);
          }
          throw unverifiedBindOutcome(null);
        }
      }
    }
    sessionEpoch = _backendApi.authSessionEpoch;

    Map<String, dynamic> profileResponse;
    try {
      profileResponse = await (_fetchMyProfileOverride != null
              ? _fetchMyProfileOverride()
              : _backendApi.getMyProfile())
          .timeout(_verifyTimeout);
    } catch (error) {
      if (isCurrent()) {
        await _restoreOriginalToken(normalizedToken, refreshToken,
            expectedEpoch: sessionEpoch);
      }
      throw AccountWalletLinkVerificationException(
        'We could not confirm whether the wallet was linked. Check your '
        'account wallet status before trying again. Verification error: $error',
      );
    }
    // A stale profile answers for another account. The bind was already sent,
    // so this is the unverified outcome, not a silent supersede.
    if (!isCurrent()) throw unverifiedBindOutcome(null);

    if (profileResponse['success'] == false) {
      await _restoreOriginalToken(normalizedToken, refreshToken,
          expectedEpoch: sessionEpoch);
      throw AccountWalletLinkVerificationException(
        'Could not verify the wallet link with your account '
        '(${profileResponse['status'] ?? profileResponse['error'] ?? 'unknown error'}). '
        'Check your account wallet status before trying again.',
      );
    }

    final profilePayload = profileResponse['data'] is Map
        ? Map<String, dynamic>.from(profileResponse['data'] as Map)
        : Map<String, dynamic>.from(profileResponse);
    final verifiedUserId =
        (profilePayload['userId'] ?? profilePayload['user_id'] ?? '')
            .toString()
            .trim();
    final verifiedWallet = (profilePayload['walletAddress'] ??
            profilePayload['wallet_address'] ??
            '')
        .toString()
        .trim();

    if (verifiedUserId.isEmpty || verifiedUserId != normalizedUserId) {
      await _restoreOriginalToken(normalizedToken, refreshToken,
          expectedEpoch: sessionEpoch);
      throw AccountWalletLinkVerificationException(
        'Your profile did not confirm that this wallet is linked to the '
        'signed-in account. The bind request may have reached the server. '
        'Check your account wallet status before trying again.',
      );
    }
    if (!WalletUtils.equals(verifiedWallet, normalizedWallet)) {
      await _restoreOriginalToken(normalizedToken, refreshToken,
          expectedEpoch: sessionEpoch);
      throw AccountWalletLinkVerificationException(
        'Your profile has not confirmed the newly linked wallet yet. The '
        'bind request may have reached the server. Check your account wallet '
        'status before trying again.',
      );
    }

    // Verified: the originating account owns the wallet. Commit local state.
    await _commitVerifiedLink(
      walletAddress: normalizedWallet,
      userId: verifiedUserId,
      expectedSessionEpoch: sessionEpoch,
      isCurrent: isCurrent,
      walletProvider: walletProvider,
      profileProvider: providers?.profileProvider,
      chatProvider: providers?.chatProvider,
    );

    return AccountWalletLinkResult(
      userId: verifiedUserId,
      walletAddress: normalizedWallet,
      profilePayload: profilePayload,
      bindPayload: bindPayload,
    );
  }

  /// Default ownership proof: fetch a wallet challenge (unauthenticated) and
  /// sign it with the signer that onboarding just created/imported/connected.
  Future<String> _signChallengeWithActiveSigner(
    WalletProvider? walletProvider,
    String walletAddress,
  ) async {
    if (walletProvider == null ||
        !walletProvider.canTransact ||
        !WalletUtils.equals(
          walletProvider.currentWalletAddress,
          walletAddress,
        )) {
      throw const AccountWalletLinkStateException(
        'The wallet signer is not ready to prove ownership of this wallet. '
        'Retry the wallet step.',
      );
    }
    final challenge =
        await _backendApi.requestWalletAuthChallenge(walletAddress);
    return walletProvider.signMessage(challenge.message);
  }

  Future<void> _restoreOriginalToken(String token, String refreshToken,
      {required int expectedEpoch}) async {
    if (_backendApi.authSessionEpoch != expectedEpoch) return;
    try {
      await _backendApi.persistAuthTokensFromResponse({
        'token': token,
        if (refreshToken.isNotEmpty) 'refreshToken': refreshToken,
      }, sessionEpoch: expectedEpoch);
    } catch (_) {
      AppConfig.debugPrint(
          'AccountWalletLinkService: original session was not restored');
    }
  }

  /// Commits a verified link.
  ///
  /// Network hydration (profile, chat) runs first and outside the lease, so a
  /// slow request never holds logout or account switch. The account-scoped
  /// prefs and the provider identity then commit under the lease. A stale stage
  /// throws [AccountWalletLinkSupersededException] and rolls back its own writes.
  Future<void> _commitVerifiedLink({
    required String walletAddress,
    required String userId,
    required int expectedSessionEpoch,
    required bool Function() isCurrent,
    WalletProvider? walletProvider,
    ProfileProvider? profileProvider,
    ChatProvider? chatProvider,
  }) async {
    void ensureCurrent() {
      if (!isCurrent()) throw const AccountWalletLinkSupersededException();
    }

    ensureCurrent();
    if (profileProvider != null) {
      await _runNonFatal(
        'authenticated profile refresh',
        () =>
            profileProvider.loadAuthenticatedProfile().timeout(_verifyTimeout),
      );
      ensureCurrent();
    }

    if (chatProvider != null) {
      await _runNonFatal(
        'chat wallet commit',
        () => chatProvider.setCurrentWallet(
          walletAddress,
          shouldContinue: isCurrent,
        ),
      );
      ensureCurrent();
    }

    final committed = await _backendApi.withAuthSessionLease(
      expectedSessionEpoch,
      () async {
        ensureCurrent();
        final prefs = await SharedPreferences.getInstance();
        ensureCurrent();
        final values = <String, Object>{
          'wallet_address': walletAddress,
          'walletAddress': walletAddress,
          'wallet': walletAddress,
          'has_wallet': true,
          'user_id': userId,
        };
        final written = <String>[];
        try {
          try {
            for (final key in _accountPrefKeys) {
              ensureCurrent();
              await _writePrefValue(prefs, key, values[key]);
              written.add(key);
            }
          } on AccountWalletLinkSupersededException {
            rethrow;
          } catch (error) {
            AppConfig.debugPrint(
                'AccountWalletLinkService: prefs commit failed: $error');
          }

          ensureCurrent();
          if (walletProvider != null) {
            // Identity only: never loads wallet data, never syncs backend data,
            // and never touches the account token (see the provider contract).
            await _runNonFatal(
              'wallet identity commit',
              () => walletProvider.commitVerifiedAccountLinkedWalletIdentity(
                walletAddress,
                persist: false,
                shouldCommit: isCurrent,
                updatePreferredWallet: false,
              ),
            );
            ensureCurrent();
          }

          _backendApi.setPreferredWalletAddress(
            walletAddress,
            persist: false,
            expectedAuthSessionEpoch: expectedSessionEpoch,
          );
        } on AccountWalletLinkSupersededException {
          await _removeOwnedPrefValues(prefs, written, values);
          rethrow;
        }
      },
    );
    if (!committed) throw const AccountWalletLinkSupersededException();
  }

  Future<void> _writePrefValue(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      throw StateError('Unsupported preference value for $key');
    }
  }

  /// Removes the keys this superseded commit wrote, but only while they still
  /// hold this commit's values. Pre-link values are deliberately not restored:
  /// after a switch or logout they would be re-persisted under the wrong
  /// session. A key another writer has since replaced is not touched.
  Future<void> _removeOwnedPrefValues(
    SharedPreferences prefs,
    List<String> written,
    Map<String, Object> values,
  ) async {
    for (final key in written.reversed) {
      try {
        if (prefs.get(key) != values[key]) continue;
        await prefs.remove(key);
      } catch (error) {
        AppConfig.debugPrint(
            'AccountWalletLinkService: prefs rollback failed: $error');
      }
    }
  }

  Future<void> _runNonFatal(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      AppConfig.debugPrint('AccountWalletLinkService: $label failed: $e');
    }
  }
}
