import 'package:flutter/material.dart';

import 'telemetry_service.dart';

class TelemetryRouteObserver extends NavigatorObserver {
  TelemetryRouteObserver();

  void _handle(Route<dynamic>? route) {
    if (route == null) return;
    if (route is! PageRoute) return;
    if (route is PopupRoute) return;
    TelemetryService().notifyRoute(route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handle(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _handle(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _handle(previousRoute);
  }
}

