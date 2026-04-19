import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/main_tab_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../../screens/desktop/web3/desktop_wallet_screen.dart';
import '../../widgets/kubus_snackbar.dart';
import 'home_quick_action_models.dart';
import 'home_quick_action_registry.dart';

class HomeQuickActionExecutor {
  static Future<bool> execute(
    BuildContext context,
    String key, {
    required HomeQuickActionSurface source,
  }) async {
    final definition = HomeQuickActionRegistry.maybeOf(key);
    if (definition == null) {
      _showUnknownAction(context, key);
      return false;
    }

    final target = _targetFor(context, definition, source);
    if (!_passesCapabilities(context, definition)) return false;

    final handled = _executeTarget(context, definition, target);
    if (handled) {
      _trackVisit(context, definition.key);
    }
    return handled;
  }

  static HomeQuickActionTarget _targetFor(
    BuildContext context,
    HomeQuickActionDefinition definition,
    HomeQuickActionSurface source,
  ) {
    switch (source) {
      case HomeQuickActionSurface.mobileHome:
        return definition.mobileTarget;
      case HomeQuickActionSurface.desktopHome:
        return definition.desktopTarget;
      case HomeQuickActionSurface.legacyProvider:
        return DesktopBreakpoints.isDesktop(context)
            ? definition.desktopTarget
            : definition.mobileTarget;
    }
  }

  static bool _executeTarget(
    BuildContext context,
    HomeQuickActionDefinition definition,
    HomeQuickActionTarget target,
  ) {
    switch (target.type) {
      case HomeQuickActionTargetType.mobileTab:
        final index = target.mobileTabIndex;
        if (index == null) return false;
        try {
          context.read<MainTabProvider>().setIndex(index);
          return true;
        } catch (_) {
          return _pushScreenTarget(context, definition, target);
        }
      case HomeQuickActionTargetType.desktopShellRoute:
        final route = target.desktopShellRoute;
        if (route == null || route.isEmpty) return false;
        return _openDesktopShellRoute(context, route);
      case HomeQuickActionTargetType.pushScreen:
        return _pushScreenTarget(context, definition, target);
      case HomeQuickActionTargetType.pushDesktopSubscreen:
        return _pushDesktopSubscreenTarget(context, definition, target);
      case HomeQuickActionTargetType.infoDialog:
      case HomeQuickActionTargetType.unsupported:
        _showInfo(context, definition, target);
        return false;
    }
  }

  static bool _pushScreenTarget(
    BuildContext context,
    HomeQuickActionDefinition definition,
    HomeQuickActionTarget target,
  ) {
    final builder = target.screenBuilder;
    if (builder == null) return false;
    final navigator = Navigator.of(context);
    unawaited(
      navigator.push(
        MaterialPageRoute(builder: builder),
      ),
    );
    return true;
  }

  static bool _pushDesktopSubscreenTarget(
    BuildContext context,
    HomeQuickActionDefinition definition,
    HomeQuickActionTarget target,
  ) {
    final builder = target.screenBuilder;
    if (builder == null) return false;

    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushSubScreen(
        title: _titleFor(context, definition, target),
        child: builder(context),
      );
      return true;
    }

    final navigator = Navigator.of(context);
    unawaited(
      navigator.push(
        MaterialPageRoute(builder: builder),
      ),
    );
    return true;
  }

  static bool _openDesktopShellRoute(BuildContext context, String route) {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.navigateToRoute(route);
      return true;
    }

    final navigator = Navigator.of(context);
    if (route == '/wallet') {
      unawaited(
        navigator.push(
          MaterialPageRoute(builder: (_) => const DesktopWalletScreen()),
        ),
      );
      return true;
    }

    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder: (_) => DesktopShell(
            initialIndex: _desktopIndexForRoute(route),
          ),
        ),
      ),
    );
    return true;
  }

  static int _desktopIndexForRoute(String route) {
    switch (route) {
      case '/explore':
        return 1;
      case '/community':
        return 2;
      case '/artist-studio':
        return 3;
      case '/institution':
        return 4;
      case '/governance':
        return 5;
      case '/marketplace':
        return 6;
      default:
        return 0;
    }
  }

  static bool _passesCapabilities(
    BuildContext context,
    HomeQuickActionDefinition definition,
  ) {
    for (final capability in definition.capabilities) {
      switch (capability) {
        case HomeQuickActionCapability.signedIn:
          if (!_isSignedIn(context)) {
            _showSnackBar(
              context,
              AppLocalizations.of(context)!.walletActionSignInRequiredToast,
            );
            return false;
          }
          break;
        case HomeQuickActionCapability.walletConnected:
          if (!_isWalletConnected(context)) {
            _showSnackBar(
              context,
              AppLocalizations.of(context)!
                  .walletActionConnectWalletRequiredToast,
            );
            return false;
          }
          break;
        case HomeQuickActionCapability.arSupportedOnDevice:
          if (!_isArSupportedOnDevice) {
            _showInfo(context, definition, definition.desktopTarget);
            return false;
          }
          break;
      }
    }
    return true;
  }

  static bool _isSignedIn(BuildContext context) {
    try {
      return context.read<ProfileProvider>().isSignedIn;
    } catch (_) {
      return false;
    }
  }

  static bool _isWalletConnected(BuildContext context) {
    try {
      return context.read<WalletProvider>().hasWalletIdentity;
    } catch (_) {
      return false;
    }
  }

  static bool get _isArSupportedOnDevice {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  static String _titleFor(
    BuildContext context,
    HomeQuickActionDefinition definition,
    HomeQuickActionTarget target,
  ) {
    final explicit = target.title?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final l10n = AppLocalizations.of(context)!;
    return definition.labelKey.resolve(l10n);
  }

  static void _trackVisit(BuildContext context, String key) {
    try {
      context.read<NavigationProvider>().trackScreenVisit(key);
    } catch (_) {}
  }

  static void _showUnknownAction(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    _showSnackBar(
      context,
      l10n.navigationUnableToNavigateToScreen(key),
    );
  }

  static void _showInfo(
    BuildContext context,
    HomeQuickActionDefinition definition,
    HomeQuickActionTarget target,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final title = target.title?.trim().isNotEmpty == true
        ? target.title!.trim()
        : definition.labelKey.resolve(l10n);
    final message = target.message?.trim().isNotEmpty == true
        ? target.message!.trim()
        : l10n.navigationUnableToNavigateToScreen(
            definition.labelKey.resolve(l10n),
          );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonGotIt),
            ),
          ],
        );
      },
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
