import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/share/share_types.dart';

/// Keeps browser history coherent for app-native public entry
/// (docs/APP_NATIVE_PUBLIC_ENTRY.md).
///
/// Flutter web keeps the whole app in one browser history entry: a Back that
/// arrives while the app can still pop something pops it in-app, and only a
/// Back at the app's root leaves the page. A canonical public entry
/// (`/en/artworks/{id}` opened from another site) shows its entity above the
/// app shell, on mobile as a pushed route and on desktop as a shell
/// sub-screen, and the map shows a marker as a selection. So the first Back
/// used to pop the entity in-app and reveal Home (or close the marker) while
/// the address bar still showed the entity, and a second Back was needed to
/// leave.
///
/// Two rules fix that:
///
/// * The entity a visitor arrived on is the bottom of their Back stack. While
///   it is still the top screen, a browser Back leaves the app the way it would
///   leave any web page ([didPopRoute] runs before the app's Navigator because
///   [install] registers it before `runApp`). In-app back buttons call the
///   Navigator directly and are unaffected.
/// * The address bar describes the visible entity. Entity screens [claim] their
///   URL while they are the top screen; [UrlCoherenceObserver] reports the
///   topmost visible claim, replacing the current entry (never adding one).
class PublicEntryNavigation extends ChangeNotifier with WidgetsBindingObserver {
  PublicEntryNavigation._();

  static final PublicEntryNavigation instance = PublicEntryNavigation._();

  static bool _installed = false;

  /// Registers the Back handler. Call once before `runApp` so it is offered the
  /// browser Back before the app's Navigator. A no-op off the web.
  static void install() {
    if (!kIsWeb || _installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(instance);
  }

  final List<_EntityClaim> _claims = <_EntityClaim>[];
  _Entry? _entry;

  /// How the app leaves the page; replaced in tests.
  @visibleForTesting
  Future<void> Function() exitApp = SystemNavigator.pop;

  /// Records the entity a canonical public URL opened, with the exact browser
  /// route (query and fragment kept) that address it.
  void setEntry({
    required ShareEntityType type,
    required String entityId,
    required String browserRoute,
  }) {
    _entry = _Entry(type, entityId.trim(), browserRoute);
    notifyListeners();
  }

  /// Claims the address bar for [type]/[entityId] while [context]'s route is
  /// current and [isShowing] (if given) holds. Returns a token for [release].
  ///
  /// [localizedPath] builds the entity's canonical path in the app language;
  /// the entry entity keeps the exact route it was opened at.
  Object claim(
    BuildContext context, {
    required ShareEntityType type,
    required String entityId,
    required String Function(String languageCode) localizedPath,
    bool Function()? isShowing,
  }) {
    final languageCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final claim = _EntityClaim(
      type: type,
      entityId: entityId.trim(),
      route: ModalRoute.of(context),
      element: context,
      defaultUrl: localizedPath(languageCode == 'sl' ? 'sl' : 'en'),
      isShowing: isShowing,
    );
    _claims.add(claim);
    notifyListeners();
    return claim;
  }

  /// Releases a [claim] when its screen leaves the tree. Null is ignored.
  void release(Object? token) {
    if (token is! _EntityClaim) return;
    if (_claims.remove(token)) notifyListeners();
  }

  /// Re-evaluates claims after a visibility input outside the route stack
  /// (for example a map selection) changed.
  void visibilityChanged() => notifyListeners();

  _EntityClaim? get _topVisibleClaim {
    for (var i = _claims.length - 1; i >= 0; i--) {
      final claim = _claims[i];
      if (claim.isVisible) return claim;
    }
    return null;
  }

  /// The URL of the entity screen the visitor is looking at, or null when no
  /// entity screen is the top screen.
  String? get visibleEntityUrl {
    final claim = _topVisibleClaim;
    if (claim == null) return null;
    final entry = _entry;
    if (entry != null && entry.matches(claim)) return entry.browserRoute;
    return claim.defaultUrl;
  }

  /// Whether the entity the visitor arrived on is still the top screen.
  bool get entryIsTop {
    final entry = _entry;
    final claim = _topVisibleClaim;
    return entry != null && claim != null && entry.matches(claim);
  }

  @override
  Future<bool> didPopRoute() async {
    if (!entryIsTop) return false;
    // One exit: if leaving is refused, later Backs behave normally in-app.
    _entry = null;
    await exitApp();
    return true;
  }

  @visibleForTesting
  void resetForTest() {
    _claims.clear();
    _entry = null;
    exitApp = SystemNavigator.pop;
  }
}

class _Entry {
  const _Entry(this.type, this.entityId, this.browserRoute);

  final ShareEntityType type;
  final String entityId;
  final String browserRoute;

  bool matches(_EntityClaim claim) =>
      claim.type == type && claim.entityId == entityId;
}

class _EntityClaim {
  _EntityClaim({
    required this.type,
    required this.entityId,
    required this.route,
    required this.element,
    required this.defaultUrl,
    required this.isShowing,
  });

  final ShareEntityType type;
  final String entityId;
  final ModalRoute<dynamic>? route;
  final BuildContext element;
  final String defaultUrl;
  final bool Function()? isShowing;

  /// Mounted, on the current route (a covered mobile route is not current; a
  /// covered desktop sub-screen is unmounted), and still showing this entity.
  bool get isVisible =>
      element.mounted &&
      (route?.isCurrent ?? true) &&
      (isShowing?.call() ?? true);
}
