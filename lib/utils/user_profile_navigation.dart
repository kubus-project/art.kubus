import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/community/user_profile_screen.dart' as mobile;
import '../screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop;
import '../screens/desktop/desktop_shell.dart';
import '../models/profile_package.dart';
import '../core/mobile_shell_registry.dart';
import '../providers/profile_provider.dart';
import '../screens/desktop/community/desktop_profile_screen.dart'
    as desktop_owner;
import '../services/profile_package_service.dart';
import '../utils/home/home_quick_action_executor.dart';
import '../utils/home/home_quick_action_models.dart';
import '../utils/wallet_utils.dart';
import '../widgets/glass_components.dart';
import 'design_tokens.dart';

enum DesktopProfilePresentation {
  shellSubScreen,
  communityOverlay,
}

class DesktopProfilePresentationScope extends InheritedWidget {
  const DesktopProfilePresentationScope({
    super.key,
    required this.presentation,
    required super.child,
  });

  final DesktopProfilePresentation presentation;

  static DesktopProfilePresentation? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DesktopProfilePresentationScope>()
        ?.presentation;
  }

  @override
  bool updateShouldNotify(DesktopProfilePresentationScope oldWidget) {
    return presentation != oldWidget.presentation;
  }
}

class UserProfileNavigation {
  static Future<ProfileCriticalPackage?>? _prefetchCriticalProfilePackage(
    String userId, {
    String? username,
  }) {
    final trimmed = userId.trim();
    final normalizedUsername = username?.trim();
    if (trimmed.isEmpty &&
        (normalizedUsername == null || normalizedUsername.isEmpty)) {
      return null;
    }
    try {
      final future = ProfilePackageService.prefetchPublicProfileCriticalPackage(
        trimmed,
        username: normalizedUsername,
      );
      unawaited(
        future.then((critical) async {
          if (critical == null) return;
          await ProfilePackageService.prefetchPublicProfileExtendedPackage(
            critical.user.id,
            user: critical.user,
          );
        }),
      );
      return future;
    } catch (_) {}
    return null;
  }

  static Future<void> open(
    BuildContext context, {
    required String userId,
    String? username,
    String? heroTag,
  }) async {
    if (_targetsCurrentUser(context, userId)) {
      await _openOwnerProfile(context);
      return;
    }

    final initialCriticalPackageFuture = _prefetchCriticalProfilePackage(
      userId,
      username: username,
    );
    if (userId.trim().isEmpty && initialCriticalPackageFuture != null) {
      final resolved = await initialCriticalPackageFuture;
      if (!context.mounted) return;
      if (resolved != null && _targetsCurrentUser(context, resolved.user.id)) {
        await _openOwnerProfile(context);
        return;
      }
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      final presentation = DesktopProfilePresentationScope.maybeOf(context);
      if (presentation == DesktopProfilePresentation.communityOverlay) {
        await openCommunityOverlay(
          context,
          userId: userId,
          username: username,
          heroTag: heroTag,
          initialCriticalPackageFuture: initialCriticalPackageFuture,
        );
        return;
      }

      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        shellScope.pushScreen(
          desktop.UserProfileScreen(
            userId: userId,
            username: username,
            heroTag: heroTag,
            initialCriticalPackageFuture: initialCriticalPackageFuture,
          ),
        );
        return;
      }
    }

    final Widget profileScreen = isDesktop
        ? desktop.UserProfileScreen(
            userId: userId,
            username: username,
            heroTag: heroTag,
            initialCriticalPackageFuture: initialCriticalPackageFuture,
          )
        : mobile.UserProfileScreen(
            userId: userId,
            username: username,
            heroTag: heroTag,
            initialCriticalPackageFuture: initialCriticalPackageFuture,
          );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => profileScreen),
    );
  }

  /// Match only stable account identifiers and linked wallet/public actor IDs.
  /// Display names and usernames are intentionally excluded because they can
  /// collide or change independently of account ownership.
  static bool _targetsCurrentUser(BuildContext context, String targetId) {
    final target = _identityKey(targetId);
    if (target.isEmpty) return false;
    try {
      final provider = context.read<ProfileProvider>();
      if (!provider.isSignedIn) return false;
      final current = provider.currentUser;
      if (current == null) return false;
      final linkedIdentifiers = <String?>[
        current.userId,
        current.id,
        current.walletAddress,
        current.publicActorId,
      ];
      return linkedIdentifiers.any((identifier) {
        final key = _identityKey(identifier);
        return key.isNotEmpty && key == target;
      });
    } catch (_) {
      return false;
    }
  }

  static String _identityKey(String? identifier) {
    final value = WalletUtils.canonical(identifier);
    if (value.isEmpty) return '';
    // Wallet keys are case-sensitive; account IDs are treated as
    // case-insensitive stable identifiers.
    return WalletUtils.looksLikeWallet(value) ? value : value.toLowerCase();
  }

  static Future<void> _openOwnerProfile(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 900) {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        shellScope.pushScreen(const desktop_owner.ProfileScreen());
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const desktop_owner.ProfileScreen(),
          ),
        );
      }
      return;
    }

    await HomeQuickActionExecutor.execute(
      context,
      'profile',
      source: HomeQuickActionSurface.mobileHome,
    );
    // A detail route may sit above the tab shell. Selecting a tab underneath
    // it alone leaves the visitor looking at the old detail screen.
    final shellContext = MobileShellRegistry.instance.context;
    if (shellContext != null && shellContext.mounted) {
      final shellRoute = ModalRoute.of(shellContext);
      if (shellRoute != null) {
        Navigator.of(shellContext)
            .popUntil((route) => identical(route, shellRoute));
      }
    }
  }

  static Future<void> openCommunityOverlay(
    BuildContext context, {
    required String userId,
    String? username,
    String? heroTag,
    Future<ProfileCriticalPackage?>? initialCriticalPackageFuture,
  }) async {
    if (_targetsCurrentUser(context, userId)) {
      await _openOwnerProfile(context);
      return;
    }
    final normalizedUsername = username?.trim();
    if (userId.trim().isEmpty &&
        (normalizedUsername == null || normalizedUsername.isEmpty)) {
      return;
    }
    final criticalFuture = initialCriticalPackageFuture ??
        _prefetchCriticalProfilePackage(
          userId,
          username: normalizedUsername,
        );
    if (userId.trim().isEmpty && criticalFuture != null) {
      final resolved = await criticalFuture;
      if (!context.mounted) return;
      if (resolved != null && _targetsCurrentUser(context, resolved.user.id)) {
        await _openOwnerProfile(context);
        return;
      }
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(KubusRadius.xl);
    final isDark = theme.brightness == Brightness.dark;

    // Canonical glass dialog: showKubusDialog applies the shared backdrop
    // blur, barrier dismissal, and fade/scale transition.
    await showKubusDialog<void>(
      context: context,
      barrierColor: scheme.scrim.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 520,
              maxWidth: 980,
              maxHeight: 900,
            ),
            child: Material(
              color: scheme.surface.withValues(
                alpha: isDark ? 0.78 : 0.92,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(
                    alpha: isDark ? 0.82 : 0.94,
                  ),
                  borderRadius: radius,
                  border: KubusBorders.glass(context),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.24),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: DesktopProfilePresentationScope(
                    presentation: DesktopProfilePresentation.communityOverlay,
                    child: desktop.UserProfileScreen(
                      userId: userId,
                      username: username,
                      heroTag: heroTag,
                      initialCriticalPackageFuture: criticalFuture,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
