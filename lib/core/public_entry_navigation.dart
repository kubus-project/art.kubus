import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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
  _Entry? _shellReturn;
  String? _startupBrowserRoute;
  bool _entryWasClaimed = false;
  bool _exitAttempted = false;

  /// How the app leaves the page; replaced in tests.
  @visibleForTesting
  Future<void> Function() exitApp = SystemNavigator.pop;

  /// Frozen launch URL shared with the web Router's initial route provider.
  /// It is read without consuming it; initial-route generation consumes it once.
  String? get startupBrowserRoute => _startupBrowserRoute;

  /// Captures the browser URL before Flutter's route-information normalization
  /// can drop a fragment from its initial Navigator route. Consume this once
  /// during initial-route generation; later in-app entries must own their own
  /// query and fragment values.
  void captureStartupBrowserRoute(Uri uri) {
    _startupBrowserRoute ??= Uri(
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }

  /// Returns the frozen launch URL only for the same initial path, and always
  /// clears it so it can never leak onto a later entity navigation.
  String? takeStartupBrowserRouteFor(String path) {
    final route = _startupBrowserRoute;
    _startupBrowserRoute = null;
    if (route == null || Uri.tryParse(route)?.path != path) return null;
    return route;
  }

  /// Records the entity a canonical public URL opened, with the exact browser
  /// route (query and fragment kept) that address it.
  void setEntry({
    required ShareEntityType type,
    required String entityId,
    required String browserRoute,
    required String shellRoute,
  }) {
    final id = entityId.trim();
    if (id.isEmpty ||
        browserRoute.trim().isEmpty ||
        shellRoute.trim().isEmpty) {
      return;
    }
    final current = _entry;
    if (current != null &&
        current.matches(type, id) &&
        current.browserRoute == browserRoute &&
        current.shellRoute == shellRoute) {
      return;
    }
    if (current != null && !current.matches(type, id)) {
      // A new provider seed owns the entry now. Dispose its prior entity's URL
      // claims immediately; the old widgets may take another frame to leave.
      _claims.removeWhere(
        (claim) => current.matches(claim.type, claim.entityId),
      );
    }
    _entry = _Entry(type, id, browserRoute, shellRoute);
    _shellReturn = null;
    _entryWasClaimed = false;
    _exitAttempted = false;
    notifyListeners();
  }

  /// Claims the address bar for [type]/[entityId] while [context]'s route is
  /// current and [isShowing] (if given) holds. Returns a token for [release].
  ///
  /// [localizedPath] builds the entity's canonical path in the app language;
  /// the entry entity keeps its original query and fragment when the locale
  /// changes.
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
  void release(Object? token, {bool retireEntryIfUnused = false}) {
    if (token is! _EntityClaim) return;
    if (!_claims.remove(token)) return;
    if (retireEntryIfUnused &&
        (token.route == null || !token.route!.isActive) &&
        _entry?.matches(token.type, token.entityId) == true) {
      final retiringEntry = _entry;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final entry = _entry;
        if (entry == null || !identical(entry, retiringEntry)) return;
        if (_claims.any((claim) =>
            claim.element.mounted &&
            entry.matches(claim.type, claim.entityId))) {
          return;
        }
        _shellReturn = entry;
        _entry = null;
        _entryWasClaimed = false;
        notifyListeners();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    }
    notifyListeners();
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
    if (entry != null && entry.matches(claim.type, claim.entityId)) {
      _entryWasClaimed = true;
      final original = Uri.tryParse(entry.browserRoute);
      final localized = Uri.tryParse(claim.defaultUrl);
      if (original == null ||
          localized == null ||
          original.path == localized.path) {
        return entry.browserRoute;
      }
      return localized
          .replace(
            query: original.hasQuery ? original.query : null,
            fragment: original.hasFragment ? original.fragment : null,
          )
          .toString();
    }
    final shellReturn = _shellReturn;
    if (_exitAttempted &&
        shellReturn != null &&
        shellReturn.matches(claim.type, claim.entityId)) {
      return shellReturn.browserRoute;
    }
    return claim.defaultUrl;
  }

  /// Keeps the original address while its exact entry has not painted yet.
  /// This prevents the shell's internal route from replacing a canonical URL
  /// while data is still loading and the readiness wrapper is not mounted.
  String? get pendingEntryUrl =>
      _entry != null && !_entryWasClaimed ? _entry!.browserRoute : null;

  /// Returns the shell route beneath a completed public entry when the shell's
  /// Navigator route still carries the entry's canonical name.
  String? underlyingShellRouteFor(String? currentRoute) {
    final entry = _entry;
    final shellReturn = _shellReturn;
    if (_topVisibleClaim != null) return null;
    if (entry != null && !_entryWasClaimed) return null;
    final routeOwner = entry ?? shellReturn;
    if (routeOwner == null) {
      return null;
    }
    final routePath = Uri.tryParse(currentRoute ?? '')?.path;
    final entryPath = Uri.tryParse(routeOwner.browserRoute)?.path;
    if (routePath == null || routePath != entryPath) return null;
    return routeOwner.shellRoute;
  }

  /// Whether the entity the visitor arrived on is still the top screen.
  bool get entryIsTop {
    final entry = _entry;
    final claim = _topVisibleClaim;
    return entry != null &&
        !_exitAttempted &&
        claim != null &&
        entry.matches(claim.type, claim.entityId);
  }

  /// Drops the startup entry when a map selection replaces that marker in the
  /// map's single selection slot. Ordinary detail routes keep their entry claim
  /// mounted underneath, so they do not call this method.
  void abandonEntry(ShareEntityType type, String entityId) {
    final entry = _entry;
    if (entry == null || !entry.matches(type, entityId.trim())) return;
    _shellReturn = entry;
    _entry = null;
    _entryWasClaimed = false;
    _exitAttempted = false;
    notifyListeners();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!entryIsTop) return false;
    // One exit: if leaving is refused, later Backs behave normally in-app.
    _exitAttempted = true;
    _shellReturn = _entry;
    await exitApp();
    return true;
  }

  @visibleForTesting
  void resetForTest() {
    _claims.clear();
    _entry = null;
    _shellReturn = null;
    _startupBrowserRoute = null;
    _entryWasClaimed = false;
    _exitAttempted = false;
    exitApp = SystemNavigator.pop;
  }
}

class _Entry {
  const _Entry(this.type, this.entityId, this.browserRoute, this.shellRoute);

  final ShareEntityType type;
  final String entityId;
  final String browserRoute;
  final String shellRoute;

  bool matches(ShareEntityType candidateType, String candidateId) =>
      candidateType == type && candidateId == entityId;
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
