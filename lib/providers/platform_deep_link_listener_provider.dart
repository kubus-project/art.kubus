import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../core/app_navigator.dart';
import '../services/share/share_deep_link_parser.dart';
import '../utils/share_deep_link_navigation.dart';
import 'deep_link_provider.dart';

/// Listens for incoming platform deep links (Android App Links / custom schemes)
/// and forwards them into the existing share-deep-link flow.
///
/// - On cold start: seeds [DeepLinkProvider] so [AppInitializer] can open it.
/// - While running: navigates immediately using [appNavigatorKey] when possible.
class PlatformDeepLinkListenerProvider extends ChangeNotifier {
  final AppLinks _appLinks = AppLinks();

  DeepLinkProvider? _deepLinkProvider;
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;
  String? _lastHandled;

  void bindDeepLinkProvider(DeepLinkProvider provider) {
    _deepLinkProvider = provider;
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

    // De-dupe repeats (Android may dispatch the same URI more than once).
    if (_lastHandled == raw) return;
    _lastHandled = raw;

    ShareDeepLinkTarget? target;
    try {
      target = const ShareDeepLinkParser().parse(uri);
    } catch (_) {
      target = null;
    }

    if (target == null) return;

    final deepLinkProvider = _deepLinkProvider;

    final navigator = appNavigatorKey.currentState;
    final canNavigateNow = allowImmediateNavigation && navigator != null && navigator.mounted;

    if (canNavigateNow) {
      // Navigate immediately if the app is already running.
      unawaited(ShareDeepLinkNavigation.open(navigator.context, target));
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
