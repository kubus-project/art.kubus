import 'package:flutter/widgets.dart';

import '../main_app.dart';
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

  /// Routes that should go through [AppInitializer] on cold start so providers
  /// hydrate before the shell renders.
  static const Set<String> initializerWrapped = <String>{
    main,
    map,
  };

  static bool shouldWrapInitialUri(Uri uri) {
    return uri.queryParameters.isEmpty && initializerWrapped.contains(uri.path);
  }

  static bool isInternalShellAlias(String path) {
    final normalized = path.trim();
    return normalized == main || normalized == map;
  }

  static String internalShellEntryForTarget(ShareDeepLinkTarget target) {
    return target.type == ShareEntityType.marker ? map : main;
  }

  /// Resolve which shell route the app should land on after initialization.
  static String resolvePreferredShellRoute(String? preferred) {
    final normalized = (preferred ?? '').trim();
    if (normalized == map) return map;
    return main;
  }

  /// Build redirect arguments for sign-in flows that should return to the shell.
  static Map<String, String>? signInRedirectArguments(String? preferred) {
    final normalized = (preferred ?? '').trim();
    if (normalized == map || normalized == main) {
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
  };
}
