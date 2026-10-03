import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Keeps the browser URL describing the page that is actually visible.
///
/// Flutter's Navigator tells the engine about a route only while the top route
/// carries a name, and only when that name differs from the last one it
/// reported. Most detail screens are pushed unnamed, so after a protected
/// action opened `/onboarding` (or `/sign-in`) and the visitor pressed Back,
/// the entity became visible again while the address bar kept saying
/// `/onboarding`: copying the link or refreshing then opened discovery instead
/// of the entity. The same de-duplication also stops the engine from being told
/// about a second visit to a route with the same name.
///
/// After every stack change this observer works out the URL that should be
/// showing, which is the name of the topmost named page route (an unnamed
/// detail screen inherits the page beneath it), and reports it when it differs
/// from what the address bar was last told. It never changes navigation, only
/// what the URL says.
///
/// Limit: an entity opened in-app is still an unnamed route, so after Back the
/// address is the page it was opened from (for example `/map`), not the
/// entity. An entity reached through its canonical link keeps that link,
/// because the shell route beneath it carries the canonical name.
class UrlCoherenceObserver extends NavigatorObserver {
  UrlCoherenceObserver({
    bool? enabled,
    void Function(String url)? report,
  })  : _enabled = enabled ?? kIsWeb,
        _report = report ?? _reportToEngine;

  final bool _enabled;
  final void Function(String url) _report;
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];
  String? _shownUrl;
  bool _scheduled = false;

  /// The URL the observer believes the address bar currently shows.
  @visibleForTesting
  String? get shownUrl => _shownUrl;

  /// The URL the visible page should be showing, from the current stack.
  @visibleForTesting
  String? get desiredUrl {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final route = _stack[i];
      if (route is! PageRoute<dynamic>) continue;
      final name = route.settings.name?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Dialogs, sheets and popups are not pages: they cannot change the URL and
    // must not force a frame on a hot path.
    if (route is! PageRoute<dynamic>) return;
    _stack.add(route);
    _schedule();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) return;
    _stack.remove(route);
    _schedule();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) return;
    _stack.remove(route);
    _schedule();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is! PageRoute<dynamic> && oldRoute is! PageRoute<dynamic>) {
      return;
    }
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute != null && newRoute is PageRoute<dynamic>) {
      if (index >= 0) {
        _stack[index] = newRoute;
      } else {
        _stack.add(newRoute);
      }
    } else if (index >= 0) {
      _stack.removeAt(index);
    }
    _schedule();
  }

  void _schedule() {
    if (!_enabled || _scheduled) return;
    _scheduled = true;
    // Run after the frame so the Navigator's own report has already happened
    // and this is always the last write for the stack it describes.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _sync();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _sync() {
    final desired = desiredUrl;
    if (desired == null) return;
    if (_shownUrl == null) {
      // First named page: the browser is already on the URL that produced it.
      _shownUrl = desired;
      return;
    }
    if (desired == _shownUrl) return;
    _shownUrl = desired;
    _report(desired);
  }

  static void _reportToEngine(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    SystemNavigator.routeInformationUpdated(uri: uri, replace: true);
  }
}
