import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';
import 'shell_routes.dart';

/// Flutter's web engine stores each Router entry as `{serialCount, state}` in
/// the browser history, and a reload hands that wrapper back as the entry's
/// `history.state`. The entry's own state is the inner map. Popstate reports
/// arrive already unwrapped, so this is idempotent.
Object? unwrapEngineHistoryState(Object? state) {
  if (state is Map && state.containsKey('serialCount')) return state['state'];
  return state;
}

/// The URL describes the visible page; [shellRoute] describes the app surface
/// that owns it. The other fields are a serializable summary of a public entity
/// or map selection, so browser history can restore the same app state.
@immutable
class BrowserEntryRoute {
  const BrowserEntryRoute({
    required this.visibleUri,
    required this.shellRoute,
    this.entityType,
    this.entityId,
    this.markerId,
    this.latitude,
    this.longitude,
    this.zoom,
    this.historyIndex,
    this.historyBack,
  });

  factory BrowserEntryRoute.fromUri(
    Uri uri, {
    Object? historyState,
    String? fallbackShellRoute,
  }) {
    final normalized = uri.path.isEmpty ? uri.replace(path: '/') : uri;
    final target = const ShareDeepLinkParser().parse(normalized);
    final intent = const ShareDeepLinkCodec().parseIntent(normalized);
    final entryState = unwrapEngineHistoryState(historyState);
    final serializedShell = _stateString(entryState, 'shellRoute');
    final shellRoute = _shellRouteFor(
      normalized,
      target: target,
      intent: intent,
      serializedShell: serializedShell,
      fallbackShellRoute: fallbackShellRoute,
    );

    return BrowserEntryRoute(
      visibleUri: normalized,
      shellRoute: shellRoute,
      entityType: target?.type.analyticsTargetType ??
          (intent?.type == AppRouteIntentType.map ? 'map' : null),
      entityId: target?.id,
      markerId: target?.type == ShareEntityType.marker ? target!.id : null,
      latitude: intent?.lat,
      longitude: intent?.lng,
      zoom: intent?.zoom,
      historyIndex: _stateInt(entryState, 'historyIndex'),
      historyBack: _stateUri(entryState, 'historyBack'),
    );
  }

  final Uri visibleUri;
  final String shellRoute;
  final String? entityType;
  final String? entityId;
  final String? markerId;
  final double? latitude;
  final double? longitude;
  final double? zoom;

  /// Position of this entry among the entries this page created, as recorded
  /// by [BrowserHistoryMirror]. Not part of the route's identity.
  final int? historyIndex;

  /// The address of the entry directly below this one, when this page recorded
  /// it. A reload keeps the browser's entries and this state, so it tells the
  /// reloaded page which entry an in-app Back should step to. Not identity.
  final Uri? historyBack;

  Map<String, Object?> toHistoryState() => <String, Object?>{
        'version': 1,
        'visibleUri': visibleUri.toString(),
        'shellRoute': shellRoute,
        if (entityType != null) 'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        if (markerId != null) 'markerId': markerId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (zoom != null) 'zoom': zoom,
      };

  RouteInformation toRouteInformation() => RouteInformation(
        uri: visibleUri,
        state: toHistoryState(),
      );

  BrowserEntryRoute withVisibleUri(Uri uri) => BrowserEntryRoute.fromUri(
        uri,
        fallbackShellRoute: shellRoute,
      );

  static String _shellRouteFor(
    Uri uri, {
    required ShareDeepLinkTarget? target,
    required AppRouteIntent? intent,
    required String? serializedShell,
    required String? fallbackShellRoute,
  }) {
    if (target != null) return ShellRoutes.internalShellEntryForTarget(target);
    if (intent?.type == AppRouteIntentType.map) return ShellRoutes.map;
    if (ShellRoutes.initializerWrapped.contains(uri.path)) return uri.path;
    if (_isSupportedShellRoute(serializedShell)) return serializedShell!;
    if (_isSupportedShellRoute(fallbackShellRoute)) {
      return fallbackShellRoute!;
    }
    return ShellRoutes.resolvePreferredShellRoute(uri.path);
  }

  static bool _isSupportedShellRoute(String? route) =>
      route == ShellRoutes.main ||
      route == ShellRoutes.map ||
      route == ShellRoutes.community ||
      route == ShellRoutes.analytics;

  static int? _stateInt(Object? state, String key) {
    if (state is! Map) return null;
    final value = state[key];
    return value is int ? value : null;
  }

  static Uri? _stateUri(Object? state, String key) {
    final value = _stateString(state, key);
    return value == null ? null : Uri.tryParse(value);
  }

  static String? _stateString(Object? state, String key) {
    if (state is! Map) return null;
    final value = state[key];
    if (value is! String) return null;
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is BrowserEntryRoute &&
      visibleUri.toString() == other.visibleUri.toString() &&
      shellRoute == other.shellRoute &&
      entityType == other.entityType &&
      entityId == other.entityId &&
      markerId == other.markerId &&
      latitude == other.latitude &&
      longitude == other.longitude &&
      zoom == other.zoom;

  @override
  int get hashCode => Object.hash(
        visibleUri.toString(),
        shellRoute,
        entityType,
        entityId,
        markerId,
        latitude,
        longitude,
        zoom,
      );
}

class BrowserEntryRouteInformationParser
    extends RouteInformationParser<BrowserEntryRoute> {
  const BrowserEntryRouteInformationParser();

  @override
  Future<BrowserEntryRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) =>
      SynchronousFuture<BrowserEntryRoute>(
        BrowserEntryRoute.fromUri(
          routeInformation.uri,
          historyState: routeInformation.state,
        ),
      );

  @override
  RouteInformation restoreRouteInformation(BrowserEntryRoute configuration) =>
      configuration.toRouteInformation();
}

/// Initializes multi-entry browser history before building the root Navigator
/// and seeds the provider's engine comparison with the complete launch URI.
/// The replace reporting type is essential for startup query/fragment values:
/// they belong to the current external entry and must not create a duplicate.
class StartupBrowserRouteInformationProvider
    extends PlatformRouteInformationProvider {
  StartupBrowserRouteInformationProvider(
    BrowserEntryRoute initialRoute, {
    BrowserHistoryMirror? history,
  })  : history = history ?? BrowserHistoryMirror(),
        super(initialRouteInformation: initialRoute.toRouteInformation()) {
    // A reload keeps the browser's entries: start the mirror where the page
    // was, with the entry below it when this page recorded one.
    this.history.restore(
          initialRoute.visibleUri,
          below: initialRoute.historyBack,
        );
    routerReportsNewRouteInformation(
      initialRoute.toRouteInformation(),
      type: RouteInformationReportingType.neglect,
    );
  }

  /// The entries this page has created, kept in step with every engine report.
  final BrowserHistoryMirror history;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    // Mirror exactly what the framework does with this report (see
    // PlatformRouteInformationProvider): none replaces only an identical
    // location, so this stays correct when several changes coalesce in a frame.
    final replace = switch (type) {
      RouteInformationReportingType.neglect => true,
      RouteInformationReportingType.navigate => false,
      RouteInformationReportingType.none => BrowserHistoryMirror.sameLocation(
          history.current, routeInformation.uri),
    };
    history.recordReport(routeInformation.uri, replace: replace);
    final state = routeInformation.state;
    final below = history.below;
    super.routerReportsNewRouteInformation(
      RouteInformation(
        uri: routeInformation.uri,
        state: state is Map
            ? <Object?, Object?>{
                ...state,
                'historyIndex': history.cursor,
                if (below != null) 'historyBack': below.toString(),
              }
            : state,
      ),
      type: type,
    );
  }
}

/// The entries this page has added to the browser history, in order, with the
/// one currently shown. The browser does not let a page inspect its history, so
/// this mirrors every report the Router makes. It lets an in-app Back step the
/// browser back to the entry below when that entry is the page being returned
/// to, instead of pushing a duplicate of it (history: Home, artwork, Home).
class BrowserHistoryMirror {
  final List<Uri> _uris = <Uri>[];
  int _cursor = 0;

  /// Index of the current entry; also stored in each entry's history state.
  int get cursor => _cursor;

  Uri? get current => _uris.isEmpty ? null : _uris[_cursor];

  /// The entry directly below the current one, or null.
  Uri? get below => _cursor > 0 ? _uris[_cursor - 1] : null;

  /// Starts the mirror at the entry a (re)loaded page shows, seeding the entry
  /// below it when the page recorded one. Without that seed the first in-app
  /// Back would push a second copy of the page below.
  void restore(Uri current, {Uri? below}) {
    _uris
      ..clear()
      ..addAll(below == null ? <Uri>[current] : <Uri>[below, current]);
    _cursor = below == null ? 0 : 1;
  }

  /// Whether [a] and [b] are the same browser location (path, query, fragment).
  static bool sameLocation(Uri? a, Uri? b) {
    if (a == null || b == null) return false;
    if (a.path != b.path || a.fragment != b.fragment) return false;
    final left = a.queryParametersAll;
    final right = b.queryParametersAll;
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      final other = right[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      final sortedLeft = List<String>.of(entry.value)..sort();
      final sortedRight = List<String>.of(other)..sort();
      for (var i = 0; i < sortedLeft.length; i++) {
        if (sortedLeft[i] != sortedRight[i]) return false;
      }
    }
    return true;
  }

  void recordReport(Uri uri, {required bool replace}) {
    if (_uris.isEmpty) {
      _uris.add(uri);
      _cursor = 0;
    } else if (replace) {
      _uris[_cursor] = uri;
    } else {
      _uris.removeRange(_cursor + 1, _uris.length);
      _uris.add(uri);
      _cursor = _uris.length - 1;
    }
  }

  /// Whether the entry directly below the current one shows [uri].
  bool canStepBackTo(Uri uri) =>
      _cursor > 0 && sameLocation(_uris[_cursor - 1], uri);

  /// The browser moved (Back, Forward, a link) to [uri], whose recorded
  /// position was [index]. When that position does not match what this page
  /// recorded, the mirror restarts at [uri], seeded with [below] (the entry the
  /// page recorded under it), so an in-app Back still steps instead of adding a
  /// duplicate of the entry below.
  void browserNavigated(Uri uri, int? index, {Uri? below}) {
    if (index != null &&
        index >= 0 &&
        index < _uris.length &&
        sameLocation(_uris[index], uri)) {
      _cursor = index;
      return;
    }
    if (sameLocation(current, uri)) return;
    restore(uri, below: below);
  }
}

typedef BrowserRouteRestore = void Function(
  BrowserEntryRoute configuration,
  NavigatorState navigator,
);

/// Bridges the existing imperative root Navigator to the framework Router.
/// The nested Navigator remains the app's navigation owner, while this Router
/// exclusively owns browser route reporting and popstate restoration.
class BrowserEntryRouterDelegate extends RouterDelegate<BrowserEntryRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<BrowserEntryRoute> {
  BrowserEntryRouterDelegate({
    required BrowserEntryRoute initialConfiguration,
    required this.onGenerateInitialRoutes,
    required this.onGenerateRoute,
    required this.observers,
    required this.restoreRoute,
    this.history,
    this.stepBrowserBack,
    this.restoreCooldown = const Duration(milliseconds: 800),
    GlobalKey<NavigatorState>? navigatorKey,
  })  : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
        _configuration = initialConfiguration,
        _shownRoute = initialConfiguration;

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final InitialRouteListFactory onGenerateInitialRoutes;
  final RouteFactory onGenerateRoute;
  final List<NavigatorObserver> observers;
  final BrowserRouteRestore restoreRoute;

  /// Mirror of the browser entries this page created; with [stepBrowserBack]
  /// it lets an in-app Back move the browser back instead of adding an entry.
  final BrowserHistoryMirror? history;
  final VoidCallback? stepBrowserBack;

  /// A page restored from the address needs its startup (providers, shell,
  /// entity) to run undisturbed: a second restore that lands while it is still
  /// starting can leave the shell showing instead of the entity the address
  /// names. History traversals arriving inside this window are coalesced and
  /// only the latest is restored once it has elapsed.
  final Duration restoreCooldown;

  Timer? _restoreCooldownTimer;
  BrowserEntryRoute? _deferredRestore;

  /// The address the browser shows: the latest traversal or visible report.
  BrowserEntryRoute _configuration;

  /// The page the Navigator shows. It trails [_configuration] while a restore
  /// is deferred, and it is what a traversal is compared against.
  BrowserEntryRoute _shownRoute;
  bool _restoringRoute = false;
  Uri? _expectedBackUri;

  /// The last visible address reported while a restore was deferred. It is
  /// replayed if the traversal that deferred the restore lands back on the page
  /// on screen, so an in-app change made meanwhile is not lost from the address.
  Uri? _droppedVisibleUri;

  @override
  BrowserEntryRoute get currentConfiguration => _configuration;

  bool get isRestoringRoute => _restoringRoute;

  /// Called by the visibility observer when the existing Navigator or shell
  /// selects a different address. Router then decides whether to push or
  /// replace the browser entry from the route configuration.
  ///
  /// [replace] rewrites the current browser entry instead of adding one, for
  /// corrections the visitor did not navigate to.
  void reportVisibleUri(Uri uri, {bool replace = false}) {
    if (_restoringRoute) return;
    if (_deferredRestore != null) {
      // While a traversal waits out the cooldown, the address already names the
      // page the browser moved to. A report from the page still starting up
      // would overwrite that entry and the deferred restore would re-push it.
      _droppedVisibleUri = uri;
      return;
    }
    _expectedBackUri = null;
    final next = _configuration.withVisibleUri(uri);
    _shownRoute = next;
    if (next == _configuration) return;
    _configuration = next;
    final context = navigatorKey.currentContext;
    if (replace && context != null && context.mounted) {
      Router.neglect(context, notifyListeners);
    } else {
      notifyListeners();
    }
  }

  /// Called when an in-app Back (a Navigator pop) made [uri] visible. When the
  /// browser entry below is that page, step the browser back to it so the
  /// history stays [.., Home] rather than gaining a second Home; otherwise it is
  /// an ordinary visible-address change.
  void reportVisibleBack(Uri uri) {
    // Same window as reportVisibleUri: the browser already names the page a
    // deferred restore will show, so this visible change must not reach it.
    if (_restoringRoute) return;
    if (_deferredRestore != null) {
      _droppedVisibleUri = uri;
      return;
    }
    final next = _configuration.withVisibleUri(uri);
    if (next == _configuration) return;
    final mirror = history;
    final step = stepBrowserBack;
    if (mirror == null || step == null || !mirror.canStepBackTo(uri)) {
      reportVisibleUri(uri);
      return;
    }
    _shownRoute = next;
    _configuration = next;
    _expectedBackUri = uri;
    step();
  }

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        initialRoute: _configuration.visibleUri.toString(),
        onGenerateInitialRoutes: (_, initialRoute) =>
            onGenerateInitialRoutes(_configuration.visibleUri.toString()),
        onGenerateRoute: onGenerateRoute,
        observers: observers,
        reportsRouteUpdateToEngine: false,
      );

  @override
  Future<void> setNewRoutePath(BrowserEntryRoute configuration) async {
    history?.browserNavigated(
      configuration.visibleUri,
      configuration.historyIndex,
      below: configuration.historyBack,
    );
    // The browser Back this delegate asked for: the Navigator already shows
    // that page, so only the serialized configuration needs to follow.
    final expectedBack = _expectedBackUri;
    _expectedBackUri = null;
    final arrivedByInAppBack = expectedBack != null &&
        BrowserHistoryMirror.sameLocation(
            expectedBack, configuration.visibleUri);
    // Compared with the page on screen, never with the address of a restore
    // still waiting out the cooldown: a fragment-only change to a deferred
    // page must not replay that page's older fragment.
    final sameScreen = _sameScreen(configuration, _shownRoute);
    _configuration = configuration;
    final navigator = navigatorKey.currentState;
    if (arrivedByInAppBack || sameScreen) {
      // Browser hash-only navigation, or the browser returned to the page on
      // screen. The Navigator already shows it, so a restore still waiting out
      // the cooldown is stale. A visible change reported while that restore was
      // pending still applies: replay it instead of leaving the address stale.
      final pending = _deferredRestore != null;
      _deferredRestore = null;
      final dropped = _droppedVisibleUri;
      _droppedVisibleUri = null;
      if (pending && dropped != null) reportVisibleUri(dropped);
    } else if (navigator != null) {
      if (_restoreCooldownTimer != null) {
        _deferredRestore = configuration;
        _droppedVisibleUri = null;
      } else {
        _runRestore(configuration, navigator);
      }
    }
    notifyListeners();
  }

  /// Whether [a] and [b] show the same page. The fragment is not part of it:
  /// browser hash-only navigation changes the address, not the selected screen.
  static bool _sameScreen(BrowserEntryRoute a, BrowserEntryRoute b) =>
      a.visibleUri.replace(fragment: '') ==
          b.visibleUri.replace(fragment: '') &&
      a.shellRoute == b.shellRoute &&
      a.entityType == b.entityType &&
      a.entityId == b.entityId &&
      a.markerId == b.markerId &&
      a.latitude == b.latitude &&
      a.longitude == b.longitude &&
      a.zoom == b.zoom;

  void _runRestore(BrowserEntryRoute configuration, NavigatorState navigator) {
    _restoringRoute = true;
    try {
      restoreRoute(configuration, navigator);
    } finally {
      _restoringRoute = false;
    }
    _shownRoute = configuration;
    if (restoreCooldown == Duration.zero) return;
    _restoreCooldownTimer = Timer(restoreCooldown, () {
      _restoreCooldownTimer = null;
      final deferred = _deferredRestore;
      _deferredRestore = null;
      _droppedVisibleUri = null;
      final current = navigatorKey.currentState;
      if (deferred != null && current != null) _runRestore(deferred, current);
    });
  }

  @override
  void dispose() {
    _restoreCooldownTimer?.cancel();
    _restoreCooldownTimer = null;
    _deferredRestore = null;
    super.dispose();
  }
}
