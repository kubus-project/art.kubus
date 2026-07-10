// ignore_for_file: kubus_no_raw_backdropfilter
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../screens/community/user_profile_screen.dart' as mobile;
import '../screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop;
import '../screens/desktop/desktop_shell.dart';
import '../models/profile_package.dart';
import '../services/profile_package_service.dart';
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

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: KubusGlassEffects.blurSigmaLight,
            sigmaY: KubusGlassEffects.blurSigmaLight,
          ),
          child: ColoredBox(
            color: scheme.scrim.withValues(alpha: 0.32),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).maybePop(),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KubusSpacing.lg),
                    child: GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: () {},
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
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.14),
                              ),
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
                                presentation:
                                    DesktopProfilePresentation.communityOverlay,
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
