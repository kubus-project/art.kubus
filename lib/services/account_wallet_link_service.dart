import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/wallet_utils.dart';
import 'backend_api_service.dart';

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
/// 3. POSTs `/api/auth/bind-wallet` with the signature under that token.
/// 4. Persists the bind response token.
/// 5. GETs `/api/profiles/me` and verifies the returned `userId` equals the
///    original account id and the returned wallet equals the linked wallet.
/// 6. Only after verification commits wallet prefs and provider state.
///
/// On any failure the original token is restored and no wallet prefs are
/// written; callers stay on the WalletConnect step and surface the error
/// inline. This service must never navigate.
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

  Future<AccountWalletLinkResult> linkWalletToCurrentAccount({
    required BuildContext context,
    required String walletAddress,
    required String expectedUserId,
    required String originalAuthToken,
    String? originalRefreshToken,
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

    // Capture providers before any await so the transaction does not depend
    // on the widget staying mounted.
    WalletProvider? walletProvider;
    ProfileProvider? profileProvider;
    ChatProvider? chatProvider;
    try {
      walletProvider = context.read<WalletProvider>();
      profileProvider = context.read<ProfileProvider>();
      chatProvider = context.read<ChatProvider>();
    } catch (_) {
      // Providers are optional for the backend transaction itself; commit
      // steps that need them are skipped when unavailable.
    }

    // Force the original Google/email account token back before binding. A
    // wallet create/import/connect must never decide which account binds.
    await _backendApi.setAuthToken(normalizedToken);
    final refreshToken = (originalRefreshToken ?? '').trim();
    if (refreshToken.isNotEmpty) {
      await _backendApi.setRefreshToken(refreshToken);
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
      } catch (error) {
        await _restoreOriginalToken(normalizedToken, refreshToken);
        rethrow;
      }
    }

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
      await _restoreOriginalToken(normalizedToken, refreshToken);
      rethrow;
    }
    await _persistAuthResponse(bindPayload);

    Map<String, dynamic> profileResponse;
    try {
      profileResponse = await (_fetchMyProfileOverride != null
              ? _fetchMyProfileOverride()
              : _backendApi.getMyProfile())
          .timeout(_verifyTimeout);
    } catch (error) {
      await _restoreOriginalToken(normalizedToken, refreshToken);
      throw AccountWalletLinkVerificationException(
        'Could not verify the wallet link with your account: $error',
      );
    }

    if (profileResponse['success'] == false) {
      await _restoreOriginalToken(normalizedToken, refreshToken);
      throw AccountWalletLinkVerificationException(
        'Could not verify the wallet link with your account '
        '(${profileResponse['status'] ?? profileResponse['error'] ?? 'unknown error'}).',
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
      await _restoreOriginalToken(normalizedToken, refreshToken);
      throw AccountWalletLinkVerificationException(
        'Wallet link verification failed: the wallet was not linked to your '
        'signed-in account. No changes were saved — try again.',
      );
    }
    if (!WalletUtils.equals(verifiedWallet, normalizedWallet)) {
      await _restoreOriginalToken(normalizedToken, refreshToken);
      throw AccountWalletLinkVerificationException(
        'Wallet link verification failed: your account does not report the '
        'new wallet yet. No changes were saved — try again.',
      );
    }

    // Verified: the original account owns the wallet. Commit local state.
    await _commitVerifiedLink(
      walletAddress: normalizedWallet,
      userId: verifiedUserId,
      walletProvider: walletProvider,
      profileProvider: profileProvider,
      chatProvider: chatProvider,
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

  Future<void> _restoreOriginalToken(String token, String refreshToken) async {
    try {
      await _backendApi.setAuthToken(token);
      if (refreshToken.isNotEmpty) {
        await _backendApi.setRefreshToken(refreshToken);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountWalletLinkService: token restore failed: $e');
      }
    }
  }

  Future<void> _persistAuthResponse(Object? response) async {
    if (response is! Map) return;
    final body = Map<String, dynamic>.from(response);
    final payload = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final token = (payload['token'] ?? body['token'] ?? '').toString().trim();
    if (token.isNotEmpty) {
      await _backendApi.setAuthToken(token);
    }
    final refreshToken = (payload['refreshToken'] ??
            payload['refresh_token'] ??
            body['refreshToken'] ??
            body['refresh_token'] ??
            '')
        .toString()
        .trim();
    if (refreshToken.isNotEmpty) {
      await _backendApi.setRefreshToken(refreshToken);
    }
  }

  Future<void> _commitVerifiedLink({
    required String walletAddress,
    required String userId,
    WalletProvider? walletProvider,
    ProfileProvider? profileProvider,
    ChatProvider? chatProvider,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', walletAddress);
      await prefs.setString('walletAddress', walletAddress);
      await prefs.setString('wallet', walletAddress);
      await prefs.setBool('has_wallet', true);
      await prefs.setString('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountWalletLinkService: prefs commit failed: $e');
      }
    }

    _backendApi.setPreferredWalletAddress(walletAddress);

    if (walletProvider != null) {
      // After a verified bind only the safe commit path may run: it never
      // loads wallet data, never syncs backend data, and never touches the
      // account auth token (setReadOnlyWalletIdentity(loadData: true) is
      // prohibited here — its data sync can bootstrap a second account).
      await _runNonFatal(
        'wallet identity commit',
        () => walletProvider.commitVerifiedAccountLinkedWalletIdentity(
          walletAddress,
        ),
      );
    }

    if (profileProvider != null) {
      await _runNonFatal(
        'authenticated profile refresh',
        () => profileProvider
            .loadAuthenticatedProfile()
            .timeout(_verifyTimeout),
      );
    }

    if (chatProvider != null) {
      await _runNonFatal(
        'chat wallet commit',
        () => chatProvider.setCurrentWallet(walletAddress),
      );
    }
  }

  Future<void> _runNonFatal(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountWalletLinkService: $label failed: $e');
      }
    }
  }
}
