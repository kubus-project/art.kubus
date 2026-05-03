import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/user_persona.dart';
import '../providers/profile_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/security_gate_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/auth_onboarding_service.dart';
import '../services/auth_redirect_controller.dart';
import '../services/security/post_auth_security_setup_service.dart';
import '../services/telemetry/telemetry_service.dart';

enum PostAuthStage {
  preparingSession,
  securingWallet,
  loadingProfile,
  syncingSavedItems,
  checkingOnboarding,
  openingWorkspace,
  failed,
}

class PostAuthResult {
  const PostAuthResult({
    required this.completed,
    this.routeName,
    this.arguments,
    this.replaceStack = true,
    this.error,
    this.onboardingStepId,
  });

  final bool completed;
  final String? routeName;
  final Object? arguments;
  final bool replaceStack;
  final Object? error;
  final String? onboardingStepId;

  static const failed = PostAuthResult(completed: false);
}

class PostAuthCoordinator {
  const PostAuthCoordinator();

  Future<PostAuthResult> complete({
    required BuildContext context,
    required AuthOrigin origin,
    required Map<String, dynamic> payload,
    String? redirectRoute,
    Object? redirectArguments,
    String? walletAddress,
    Object? userId,
    bool embedded = false,
    bool modalReauth = false,
    bool requiresWalletBackup = false,
    Future<void> Function()? onBeforeSavedItemsSync,
    required ValueChanged<PostAuthStage> onStageChanged,
  }) async {
    void setStage(PostAuthStage stage) {
      onStageChanged(stage);
    }

    try {
      final navigator = Navigator.of(context);
      final walletProvider = context.read<WalletProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final securityGateProvider = context.read<SecurityGateProvider>();
      final savedItemsProvider = context.read<SavedItemsProvider>();
      final prefs = await SharedPreferences.getInstance();
      final data = _mapOrNull(payload['data']) ?? payload;
      final user = _mapOrNull(data['user']) ?? data;
      final normalizedWallet = _walletAddressForFlow(
        walletAddress: walletAddress,
        walletProvider: walletProvider,
        payload: payload,
      );
      final normalizedUserId = (userId ?? user['id'] ?? '').toString().trim();

      setStage(PostAuthStage.preparingSession);
      if (normalizedUserId.isNotEmpty) {
        await prefs.setString('user_id', normalizedUserId);
        TelemetryService().setActorUserId(normalizedUserId);
      }

      setStage(PostAuthStage.securingWallet);
      if (!modalReauth) {
        final wallet = normalizedWallet.isNotEmpty
            ? normalizedWallet
            : (walletProvider.currentWalletAddress ?? '').trim();
        final shouldRequireBackup = requiresWalletBackup ||
            (AuthOnboardingService.payloadIndicatesNewAccount(payload) &&
                wallet.isNotEmpty);
        if (shouldRequireBackup && wallet.isNotEmpty && walletProvider.hasSigner) {
          try {
            await walletProvider.setMnemonicBackupRequired(
              required: true,
              walletAddress: wallet,
            );
          } catch (e) {
            AppConfig.debugPrint(
              'PostAuthCoordinator: failed to set wallet backup-required state: $e',
            );
          }
        }

        final securityOk = await const PostAuthSecuritySetupService()
            .ensurePostAuthSecuritySetup(
          navigator: navigator,
          walletProvider: walletProvider,
          securityGateProvider: securityGateProvider,
        );
        if (!context.mounted || !securityOk) {
          return const PostAuthResult(
            completed: false,
            error: 'security-setup-cancelled',
          );
        }
      }

      setStage(PostAuthStage.loadingProfile);
      final walletForProfile = normalizedWallet.isNotEmpty
          ? normalizedWallet
          : (walletProvider.currentWalletAddress ?? '').trim();
      if (walletForProfile.isNotEmpty) {
        try {
          await profileProvider
              .loadProfile(walletForProfile)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          AppConfig.debugPrint(
            'PostAuthCoordinator: profile load skipped/failed: $e',
          );
        }
      }

      if (onBeforeSavedItemsSync != null) {
        await onBeforeSavedItemsSync();
        if (!context.mounted) {
          return const PostAuthResult(completed: false);
        }
      }

      setStage(PostAuthStage.syncingSavedItems);
      try {
        await savedItemsProvider.refreshFromBackend();
      } catch (e) {
        AppConfig.debugPrint(
          'PostAuthCoordinator: saved items refresh skipped/failed: $e',
        );
      }

      setStage(PostAuthStage.checkingOnboarding);
      final routeResult = await const AuthRedirectController()
          .resolvePostAuthRedirect(
        prefs: prefs,
        payload: payload,
        hasHydratedProfile: profileProvider.hasHydratedProfile,
        requiresWalletBackup: requiresWalletBackup,
        walletAddress: walletForProfile.isEmpty ? null : walletForProfile,
        userId: normalizedUserId.isEmpty ? null : normalizedUserId,
        redirectRoute: redirectRoute,
        redirectArguments: redirectArguments,
        heuristicNextStepId: profileProvider.nextStructuredOnboardingStepId,
        persona: profileProvider.userPersona?.storageValue,
      );

      setStage(PostAuthStage.openingWorkspace);
      return PostAuthResult(
        completed: true,
        routeName: routeResult.routeName,
        arguments: routeResult.arguments,
        replaceStack: routeResult.removeAuthStack,
        onboardingStepId: routeResult.onboardingStepId,
      );
    } catch (e) {
      AppConfig.debugPrint('PostAuthCoordinator: failed: $e');
      onStageChanged(PostAuthStage.failed);
      return PostAuthResult(completed: false, error: e);
    }
  }

  Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _walletAddressForFlow({
    required String? walletAddress,
    required WalletProvider walletProvider,
    required Map<String, dynamic> payload,
  }) {
    final candidate = (walletAddress ?? '').trim();
    if (candidate.isNotEmpty) return candidate;
    final data = _mapOrNull(payload['data']) ?? payload;
    final user = _mapOrNull(data['user']) ?? data;
    final fromPayload = (user['walletAddress'] ?? user['wallet_address'] ?? '')
        .toString()
        .trim();
    if (fromPayload.isNotEmpty) return fromPayload;
    return (walletProvider.currentWalletAddress ?? '').trim();
  }
}
