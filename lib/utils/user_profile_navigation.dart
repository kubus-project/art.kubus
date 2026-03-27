import 'dart:ui';

import 'package:flutter/material.dart';

import '../screens/community/user_profile_screen.dart' as mobile;
import '../screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop;
import '../screens/desktop/desktop_shell.dart';
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
  static Future<void> open(
    BuildContext context, {
    required String userId,
    String? username,
    String? heroTag,
  }) async {
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
          )
        : mobile.UserProfileScreen(
            userId: userId,
            username: username,
            heroTag: heroTag,
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
  }) async {
    if (userId.trim().isEmpty) return;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(KubusRadius.xl);

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
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(KubusSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 520,
                      maxWidth: 920,
                      maxHeight: 920,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
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
                          child: desktop.UserProfileScreen(
                            userId: userId,
                            username: username,
                            heroTag: heroTag,
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
