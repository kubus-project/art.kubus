import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/app_navigator.dart';
import '../core/mobile_shell_registry.dart';
import '../services/auth/auth_deep_link_parser.dart';
import '../services/share/share_deep_link_parser.dart';
import '../utils/share_deep_link_navigation.dart';
import '../screens/desktop/desktop_shell_registry.dart';
import 'auth_deep_link_provider.dart';
import 'deep_link_provider.dart';

/// Listens for incoming platform deep links (Android App Links / custom schemes)
/// and forwards them into the existing share-deep-link flow.
///
/// - On cold start: seeds [DeepLinkProvider] so [AppInitializer] can open it.
/// - While running: navigates immediately using [appNavigatorKey] when possible.
class PlatformDeepLinkListenerProvider extends ChangeNotifier {
  final AppLinks _appLinks = AppLinks();

  DeepLinkProvider? _deepLinkProvider;
  AuthDeepLinkProvider? _authDeepLinkProvider;
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;
  String? _lastHandledSignature;
  DateTime? _lastHandledAt;

  void bindProviders({
    required DeepLinkProvider deepLinkProvider,
    required AuthDeepLinkProvider authDeepLinkProvider,
  }) {
    _deepLinkProvider = deepLinkProvider;
    _authDeepLinkProvider = authDeepLinkProvider;
    _ensureInitialized();
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    // Web deep links are handled via the Navigator initial route.
    if (kIsWeb) return;

    // Cold start link.
    unawaited(_seedInitialLink());

    // Runtime links.
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (Object err, StackTrace st) {
        if (kDebugMode) {
          debugPrint('PlatformDeepLinkListenerProvider: uriLinkStream error: $err');
        }
      },
    );
  }

  Future<void> _seedInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return;
      _handleUri(uri, allowImmediateNavigation: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformDeepLinkListenerProvider: getInitialLink failed: $e');
      }
    }
  }

  void _handleUri(Uri uri, {bool allowImmediateNavigation = true}) {
    final raw = uri.toString().trim();
    if (raw.isEmpty) return;

    AuthDeepLinkTarget? authTarget;
    try {
      authTarget = const AuthDeepLinkParser().parse(uri);
    } catch (_) {
      authTarget = null;
    }

    if (authTarget != null) {
      final signature = 'auth:${authTarget.signature()}';
      final now = DateTime.now();
      final lastAt = _lastHandledAt;
      if (_lastHandledSignature == signature &&
          lastAt != null &&
          now.difference(lastAt) < const Duration(seconds: 2)) {
        return;
      }
      _lastHandledSignature = signature;
      _lastHandledAt = now;

      final navigator = appNavigatorKey.currentState;
      final desktopShellContext = DesktopShellRegistry.instance.context;
      final mobileShellContext = MobileShellRegistry.instance.context;
      final canNavigateNow =
          allowImmediateNavigation &&
          (desktopShellContext != null ||
              mobileShellContext != null ||
              (navigator != null && navigator.mounted));

      if (canNavigateNow) {
        final ctx = desktopShellContext ?? mobileShellContext ?? navigator!.context;
        switch (authTarget.type) {
          case AuthDeepLinkType.verifyEmail:
            Navigator.of(ctx).pushNamed(
              '/verify-email',
              arguments: {
                'token': authTarget.token,
                if (authTarget.email != null) 'email': authTarget.email,
              },
            );
            break;
          case AuthDeepLinkType.resetPassword:
            Navigator.of(ctx).pushNamed(
              '/reset-password',
              arguments: {'token': authTarget.token},
            );
            break;
        }
        return;
      }

      _authDeepLinkProvider?.setPending(authTarget);
      return;
    }

    ShareDeepLinkTarget? target;
    try {
      target = const ShareDeepLinkParser().parse(uri);
    } catch (_) {
      target = null;
    }

    if (target == null) return;

    // De-dupe repeats (Android may dispatch the same URI more than once; and
    // some link sources trigger both initial+stream events).
    final signature = '${target.type.name}:${target.id}';
    final now = DateTime.now();
    final lastAt = _lastHandledAt;
    if (_lastHandledSignature == signature &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastHandledSignature = signature;
    _lastHandledAt = now;

    final deepLinkProvider = _deepLinkProvider;

    final navigator = appNavigatorKey.currentState;
    final desktopShellContext = DesktopShellRegistry.instance.context;
    final mobileShellContext = MobileShellRegistry.instance.context;
    final canNavigateNow =
        allowImmediateNavigation &&
        (desktopShellContext != null ||
            mobileShellContext != null ||
            (navigator != null && navigator.mounted));

    if (canNavigateNow) {
      // Navigate immediately if the app is already running.
      final ctx = desktopShellContext ?? mobileShellContext ?? navigator!.context;
      unawaited(ShareDeepLinkNavigation.open(ctx, target));
      return;
    }

    // Otherwise, seed for AppInitializer to consume (cold start / early startup).
    deepLinkProvider?.setPending(target);
  }

  @override
  void dispose() {
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
    super.dispose();
  }
}
