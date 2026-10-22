import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';
import 'shell_routes.dart';

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
  });

  factory BrowserEntryRoute.fromUri(
    Uri uri, {
    Object? historyState,
    String? fallbackShellRoute,
  }) {
    final normalized = uri.path.isEmpty ? uri.replace(path: '/') : uri;
    final target = const ShareDeepLinkParser().parse(normalized);
    final intent = const ShareDeepLinkCodec().parseIntent(normalized);
    final serializedShell = _stateString(historyState, 'shellRoute');
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
      historyIndex: _stateInt(historyState, 'historyIndex'),
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
    super.routerReportsNewRouteInformation(
      RouteInformation(
        uri: routeInformation.uri,
        state: state is Map
            ? <Object?, Object?>{...state, 'historyIndex': history.cursor}
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
  /// position was [index]. An entry this page never created restarts the
  /// mirror at that entry.
  void browserNavigated(Uri uri, int? index) {
    if (index != null &&
        index >= 0 &&
        index < _uris.length &&
        sameLocation(_uris[index], uri)) {
      _cursor = index;
      return;
    }
    if (sameLocation(current, uri)) return;
    _uris
      ..clear()
      ..add(uri);
    _cursor = 0;
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
        _configuration = initialConfiguration;

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
  BrowserEntryRoute _configuration;
  bool _restoringRoute = false;
  Uri? _expectedBackUri;

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
    _expectedBackUri = null;
    final next = _configuration.withVisibleUri(uri);
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
    if (_restoringRoute) return;
    final next = _configuration.withVisibleUri(uri);
    if (next == _configuration) return;
    final mirror = history;
    final step = stepBrowserBack;
    if (mirror == null || step == null || !mirror.canStepBackTo(uri)) {
      reportVisibleUri(uri);
      return;
    }
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
    );
    // The browser Back this delegate asked for: the Navigator already shows
    // that page, so only the serialized configuration needs to follow.
    final expectedBack = _expectedBackUri;
    _expectedBackUri = null;
    final arrivedByInAppBack = expectedBack != null &&
        BrowserHistoryMirror.sameLocation(
            expectedBack, configuration.visibleUri);
    final changed = configuration != _configuration && !arrivedByInAppBack;
    final fragmentOnlyChange = configuration.visibleUri.replace(fragment: '') ==
            _configuration.visibleUri.replace(fragment: '') &&
        configuration.shellRoute == _configuration.shellRoute &&
        configuration.entityType == _configuration.entityType &&
        configuration.entityId == _configuration.entityId &&
        configuration.markerId == _configuration.markerId &&
        configuration.latitude == _configuration.latitude &&
        configuration.longitude == _configuration.longitude &&
        configuration.zoom == _configuration.zoom;
    _configuration = configuration;
    final navigator = navigatorKey.currentState;
    // Browser hash-only navigation changes the address, not the selected
    // Flutter screen. Keep the new fragment in the serialized configuration
    // without replaying a deep-link bootstrap or replacing the live page.
    if (changed && !fragmentOnlyChange && navigator != null) {
      if (_restoreCooldownTimer != null) {
        _deferredRestore = configuration;
      } else {
        _runRestore(configuration, navigator);
      }
    }
    notifyListeners();
  }

  void _runRestore(BrowserEntryRoute configuration, NavigatorState navigator) {
    _restoringRoute = true;
    try {
      restoreRoute(configuration, navigator);
    } finally {
      _restoringRoute = false;
    }
    if (restoreCooldown == Duration.zero) return;
    _restoreCooldownTimer = Timer(restoreCooldown, () {
      _restoreCooldownTimer = null;
      final deferred = _deferredRestore;
      _deferredRestore = null;
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
