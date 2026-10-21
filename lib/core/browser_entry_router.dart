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
  StartupBrowserRouteInformationProvider(BrowserEntryRoute initialRoute)
      : super(initialRouteInformation: initialRoute.toRouteInformation()) {
    routerReportsNewRouteInformation(
      initialRoute.toRouteInformation(),
      type: RouteInformationReportingType.neglect,
    );
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
    GlobalKey<NavigatorState>? navigatorKey,
  })  : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
        _configuration = initialConfiguration;

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final InitialRouteListFactory onGenerateInitialRoutes;
  final RouteFactory onGenerateRoute;
  final List<NavigatorObserver> observers;
  final BrowserRouteRestore restoreRoute;

  BrowserEntryRoute _configuration;
  bool _restoringRoute = false;

  @override
  BrowserEntryRoute get currentConfiguration => _configuration;

  bool get isRestoringRoute => _restoringRoute;

  /// Called by the visibility observer when the existing Navigator or shell
  /// selects a different address. Router then decides whether to push or
  /// replace the browser entry from the route configuration.
  void reportVisibleUri(Uri uri) {
    if (_restoringRoute) return;
    final next = _configuration.withVisibleUri(uri);
    if (next == _configuration) return;
    _configuration = next;
    notifyListeners();
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
    final changed = configuration != _configuration;
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
      _restoringRoute = true;
      try {
        restoreRoute(configuration, navigator);
      } finally {
        _restoringRoute = false;
      }
    }
    notifyListeners();
  }
}
