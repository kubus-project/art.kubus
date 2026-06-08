import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import 'app_bootstrap_service.dart';
import 'backend_api_service.dart';

class WalletSessionSyncService {
  const WalletSessionSyncService();

  static const Duration _walletBindTimeout = Duration(seconds: 6);
  static const Duration _profileRefreshTimeout = Duration(seconds: 5);
  static const Duration _warmUpTimeout = Duration(seconds: 8);

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

  Future<void> bindAuthenticatedWallet({
    required BuildContext context,
    required String walletAddress,
    Object? userId,
    bool warmUp = true,
    bool loadProfile = true,
    bool syncBackend = false,
    Future<Object?> Function(String walletAddress)? syncBackendWallet,
  }) async {
    final normalizedWallet = walletAddress.trim();
    if (normalizedWallet.isEmpty || normalizedWallet.toLowerCase().startsWith('linked_auth:')) return;
    final walletProvider = context.read<WalletProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final chatProvider = context.read<ChatProvider>();

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
      await _runNonFatal(
        'backend wallet bind',
        () async {
          final response = await (syncBackendWallet ??
                  (wallet) => backendApi
                      .bindAuthenticatedWallet(wallet)
                      .timeout(_walletBindTimeout))(
                normalizedWallet,
              );
          await _persistAuthResponse(backendApi, response);
        },
      );
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
      await _runNonFatal(
        'profile refresh',
        () => profileProvider
            .loadProfile(
              normalizedWallet,
              allowWalletAutoRegister: true,
            )
            .timeout(_profileRefreshTimeout),
      );
    }

    await _runNonFatal(
      'chat wallet bind',
      () => chatProvider.setCurrentWallet(normalizedWallet),
    );

    if (warmUp) {
      if (!context.mounted) return;
      await _runNonFatal(
        'bootstrap warm-up',
        () => const AppBootstrapService()
            .warmUp(
              context: context,
              walletAddress: normalizedWallet,
            )
            .timeout(_warmUpTimeout),
      );
    }
  }
}
