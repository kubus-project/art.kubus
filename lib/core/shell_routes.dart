import 'package:flutter/widgets.dart';

import '../main_app.dart';
import '../screens/activity/advanced_analytics_screen.dart';
import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';
import 'shell_entry_screen.dart';

/// Canonical shell entry routes.
///
/// This file exists to keep the "shell routes" contract defined in exactly one
/// place, so `main.dart` and `AppInitializer` don't duplicate allowlists.
///
/// Notes:
/// - Adding a new shell entry URL should happen here.
/// - Keep this limited to shell entry points (not every app route).
class ShellRoutes {
  ShellRoutes._();

  static const String main = '/main';
  static const String map = '/map';
  static const String community = '/community';
  static const String analytics = '/analytics';

  /// Routes that should go through [AppInitializer] on cold start so providers
  /// hydrate before the shell renders.
  static const Set<String> initializerWrapped = <String>{
    main,
    map,
    community,
    analytics,
  };

  static bool shouldWrapInitialUri(Uri uri) {
    // Analytics is a cold entry only after AppInitializer has hydrated the
    // existing provider tree. Query values are deliberately inert here.
    if (uri.path == analytics) return true;
    if (!initializerWrapped.contains(uri.path)) return false;
    return uri.queryParameters.keys.every(_isBenignLaunchParameter);
  }

  static bool _isBenignLaunchParameter(String rawKey) {
    final key = rawKey.trim().toLowerCase();
    return key.startsWith('utm_') ||
        key == 'mode' ||
        key == 'intent' ||
        key == 'lang' ||
        key == 'locale';
  }

  static bool isInternalShellAlias(String path) {
    final normalized = path.trim();
    return normalized == main || normalized == map || normalized == community;
  }

  static String internalShellEntryForTarget(ShareDeepLinkTarget target) {
    return target.type == ShareEntityType.marker ? map : main;
  }

  /// Resolve which shell route the app should land on after initialization.
  static String resolvePreferredShellRoute(String? preferred) {
    final normalized = (preferred ?? '').trim();
    if (normalized == map) return map;
    if (normalized == community) return community;
    return main;
  }

  /// Build redirect arguments for sign-in flows that should return to the shell.
  static Map<String, String>? signInRedirectArguments(String? preferred) {
    final normalized = (preferred ?? '').trim();
    if (normalized == map || normalized == main || normalized == community) {
      return <String, String>{'redirectRoute': normalized};
    }
    return null;
  }

  /// Shell entry route builders.
  static final Map<String, WidgetBuilder> builders = <String, WidgetBuilder>{
    main: (_) => const MainApp(),
    // Internal alias for marker-oriented shell entry. Public marker links keep
    // their canonical `/m/<id>` route identity.
    map: (_) => const ShellEntryScreen.map(),
    community: (_) => const ShellEntryScreen.community(),
    analytics: (_) => const AdvancedAnalyticsScreen(
          statType: 'views',
          initialContext: AnalyticsExperienceContext.profile,
        ),
  };
}
