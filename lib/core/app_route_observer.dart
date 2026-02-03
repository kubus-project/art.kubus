import 'package:flutter/material.dart';

/// Global [RouteObserver] used for [RouteAware] screens.
///
/// Keep navigation side-effects (pause/resume polling, release GPU resources,
/// etc.) local to the screens that care, rather than scattering observers.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
