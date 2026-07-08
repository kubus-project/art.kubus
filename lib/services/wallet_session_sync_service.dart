import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_wallet_link_service.dart';
import 'backend_api_service.dart';
import 'wallet_session_sync_dependencies.dart';

class WalletSessionSyncService {
  const WalletSessionSyncService();

  static const Duration _walletBindTimeout = Duration(seconds: 6);
  static const Duration _profileRefreshTimeout = Duration(seconds: 5);

  Future<void> _persistAuthResponse(
    BackendApiService backendApi,
    Object? response,
  ) async {
    if (response is! Map) return;
    final body = Map<String, dynamic>.from(response);
    final payload = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final token = (payload['token'] ?? body['token'] ?? '').toString().trim();
    if (token.isNotEmpty) {
      await backendApi.setAuthToken(token);
    }
    final refreshToken = (payload['refreshToken'] ??
            payload['refresh_token'] ??
            body['refreshToken'] ??
            body['refresh_token'] ??
            '')
        .toString()
        .trim();
    if (refreshToken.isNotEmpty) {
      await backendApi.setRefreshToken(refreshToken);
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
        debugPrint('WalletSessionSyncService: $label failed: $e');
      }
    }
  }

  /// Binds [walletAddress] into local session state and (optionally) the
  /// backend account.
  ///
  /// Two modes:
  ///
  /// * Default (wallet-auth) mode keeps the historical behavior used by
  ///   wallet-rooted sign-in flows. It writes wallet prefs eagerly and may
  ///   auto-register a wallet profile. It MUST NOT be called from onboarding
  ///   Google/email flows; those flows must use [accountLinkMode] so a
  ///   wallet can never replace or duplicate the signed-in account.
  /// * [accountLinkMode] runs the strict [AccountWalletLinkService]
  ///   transaction: no prefs, no preferred-wallet routing change, and no
  ///   provider identity update happen before `/api/auth/bind-wallet` is
  ///   verified through `/api/profiles/me` for [expectedUserId].
  Future<void> bindAuthenticatedWallet({
    required WalletSessionSyncProvidersPayload providers,
    required String walletAddress,
    Object? userId,
    bool loadProfile = true,
    bool syncBackend = false,
    bool requireBackendSync = false,
    bool accountLinkMode = false,
    String? expectedUserId,
    String? originalAuthToken,
    String? originalRefreshToken,
    Future<Object?> Function(String walletAddress)? syncBackendWallet,
    Future<Map<String, dynamic>> Function()? fetchAuthenticatedProfile,
  }) async {
    final normalizedWallet = walletAddress.trim();
    if (normalizedWallet.isEmpty ||
        normalizedWallet.toLowerCase().startsWith('linked_auth:')) {
      return;
    }

    if (accountLinkMode) {
      if (!syncBackend || !requireBackendSync) {
        throw ArgumentError(
          'accountLinkMode requires syncBackend and requireBackendSync.',
        );
      }
      final normalizedExpectedUserId = (expectedUserId ?? '').trim();
      final normalizedOriginalToken = (originalAuthToken ?? '').trim();
      if (normalizedExpectedUserId.isEmpty) {
        throw ArgumentError('accountLinkMode requires expectedUserId.');
      }
      if (normalizedOriginalToken.isEmpty) {
        throw ArgumentError('accountLinkMode requires originalAuthToken.');
      }
      // When a bind override is injected it owns the whole transport,
      // including any wallet-ownership proof; the signature is not forwarded.
      Future<Map<String, dynamic>> Function(String wallet, {String? signature})?
          bindOverride;
      if (syncBackendWallet != null) {
        bindOverride = (wallet, {String? signature}) async {
          final response = await syncBackendWallet(wallet);
          return response is Map
              ? Map<String, dynamic>.from(response)
              : <String, dynamic>{};
        };
      }
      await AccountWalletLinkService(
        bindWallet: bindOverride,
        fetchMyProfile: fetchAuthenticatedProfile,
      ).linkWalletToCurrentAccount(
        walletAddress: normalizedWallet,
        expectedUserId: normalizedExpectedUserId,
        originalAuthToken: normalizedOriginalToken,
        originalRefreshToken: originalRefreshToken,
        providers: providers,
      );
      return;
    }

    final walletProvider = providers.walletProvider;
    final profileProvider = providers.profileProvider;
    final chatProvider = providers.chatProvider;

    final backendApi = BackendApiService();
    backendApi.setPreferredWalletAddress(normalizedWallet);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', normalizedWallet);
      await prefs.setString('walletAddress', normalizedWallet);
      await prefs.setString('wallet', normalizedWallet);
      await prefs.setBool('has_wallet', true);

      final normalizedUserId = (userId ?? '').toString().trim();
      if (normalizedUserId.isNotEmpty) {
        await prefs.setString('user_id', normalizedUserId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'WalletSessionSyncService: failed to persist wallet state: $e');
      }
    }

    if (syncBackend) {
      Future<void> bindBackendWallet() async {
        final response = await (syncBackendWallet ??
            (wallet) => backendApi
                .bindAuthenticatedWallet(wallet)
                .timeout(_walletBindTimeout))(
          normalizedWallet,
        );
        await _persistAuthResponse(backendApi, response);
      }

      if (requireBackendSync) {
        await bindBackendWallet();
      } else {
        await _runNonFatal('backend wallet bind', bindBackendWallet);
      }
    }

    if ((walletProvider.currentWalletAddress ?? '').trim() !=
        normalizedWallet) {
      await _runNonFatal(
        'wallet bind',
        () => walletProvider
            .setReadOnlyWalletIdentity(
              normalizedWallet,
              loadData: true,
              syncBackend: false,
            )
            .timeout(_walletBindTimeout),
      );
    }

    if (loadProfile && syncBackend) {
      await _runNonFatal(
        'authenticated profile refresh',
        () => profileProvider
            .loadAuthenticatedProfile()
            .timeout(_profileRefreshTimeout),
      );
    } else if (loadProfile) {
      // Read-only profile refresh. Auto-registering a wallet profile here
      // could create a second wallet-root account while a Google/email
      // session is active; wallet accounts are only created through the
      // explicit wallet challenge/sign/login flow.
      await _runNonFatal(
        'profile refresh',
        () => profileProvider
            .loadProfile(
              normalizedWallet,
              allowWalletAutoRegister: false,
            )
            .timeout(_profileRefreshTimeout),
      );
    }

    await _runNonFatal(
      'chat wallet bind',
      () => chatProvider.setCurrentWallet(normalizedWallet),
    );
  }
}
