import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'public_entry_navigation.dart';

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
/// Entity screens are mostly unnamed (and on desktop they live in the shell's
/// own stack, not the Navigator), so they [PublicEntryNavigation.claim] their
/// URL while they are the top screen; the topmost visible claim wins over the
/// named page beneath it.
class UrlCoherenceObserver extends NavigatorObserver {
  UrlCoherenceObserver({
    bool? enabled,
    void Function(String url)? report,
    PublicEntryNavigation? entityUrls,
    String? Function()? currentBrowserUrl,
  })  : _enabled = enabled ?? kIsWeb,
        _report = report ?? _reportToEngine,
        _entityUrls = entityUrls ?? PublicEntryNavigation.instance,
        _currentBrowserUrl =
            currentBrowserUrl ?? (kIsWeb ? _browserUrl : _noBrowserUrl) {
    if (_enabled) _entityUrls.addListener(_schedule);
  }

  final bool _enabled;
  final void Function(String url) _report;
  final PublicEntryNavigation _entityUrls;
  final String? Function() _currentBrowserUrl;
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];
  String? _shownUrl;
  bool _scheduled = false;

  /// The URL the observer believes the address bar currently shows.
  @visibleForTesting
  String? get shownUrl => _shownUrl;

  /// The URL the visible page should be showing, from the current stack.
  @visibleForTesting
  String? get desiredUrl {
    final entityUrl = _entityUrls.visibleEntityUrl;
    if (entityUrl != null) return entityUrl;
    final pendingEntryUrl = _entityUrls.pendingEntryUrl;
    if (pendingEntryUrl != null) return pendingEntryUrl;
    for (var i = _stack.length - 1; i >= 0; i--) {
      final route = _stack[i];
      if (route is! PageRoute<dynamic>) continue;
      final name = route.settings.name?.trim();
      if (name != null && name.isNotEmpty) {
        return _entityUrls.underlyingShellRouteFor(name) ?? name;
      }
    }
    return null;
  }

  void dispose() {
    if (_enabled) _entityUrls.removeListener(_schedule);
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
    // and this is always the last write for the stack it describes. Flutter's
    // initial-route replacement can report from a later callback in that same
    // frame, though, so verify the live browser URL once more on the next
    // frame. This matters for public entries: the shell is the underlying app
    // route, while the original entity URL must stay visible until the entry
    // claim is deliberately superseded.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _sync();
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
      SchedulerBinding.instance.ensureVisualUpdate();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _sync() {
    final desired = desiredUrl;
    if (desired == null) return;
    // The browser is on the URL that opened the app. Off the web (and in
    // tests) assume the first named page is that URL.
    final current = _currentBrowserUrl();
    _shownUrl ??= current ?? desired;
    // Navigator can update browser history after the first post-frame report.
    // Compare with the live location as well as our last write so that an
    // unchanged pending entry claim repairs that later shell-route overwrite.
    if (desired == _shownUrl && (current == null || current == desired)) return;
    if (current == desired) {
      _shownUrl = desired;
      return;
    }
    _shownUrl = desired;
    _report(desired);
  }

  static String? _noBrowserUrl() => null;

  static String? _browserUrl() {
    final base = Uri.base;
    return Uri(
      path: base.path,
      query: base.hasQuery ? base.query : null,
      fragment: base.hasFragment ? base.fragment : null,
    ).toString();
  }

  static void _reportToEngine(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    SystemNavigator.routeInformationUpdated(uri: uri, replace: true);
  }
}
