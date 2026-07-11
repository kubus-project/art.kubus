import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/community/user_profile_screen.dart' as mobile;
import '../screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop;
import '../screens/desktop/desktop_shell.dart';
import '../models/profile_package.dart';
import '../services/profile_package_service.dart';
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
    final initialCriticalPackageFuture = _prefetchCriticalProfilePackage(
      userId,
      username: username,
    );
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

  static Future<void> openCommunityOverlay(
    BuildContext context, {
    required String userId,
    String? username,
    String? heroTag,
    Future<ProfileCriticalPackage?>? initialCriticalPackageFuture,
  }) async {
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
