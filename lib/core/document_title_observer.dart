import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Keeps the browser tab title describing the page that is actually visible.
///
/// A canonical entity URL is served with a semantic `<title>` that the app
/// retains through takeover so the title never flickers. Flutter only rewrites
/// the title when the `MaterialApp` rebuilds, and route changes do not rebuild
/// it, so without an owner the first entity's title would stay on `/map`,
/// `/settings` and every other entity.
///
/// Like [UrlCoherenceObserver] this tracks the page stack and reconciles after
/// each change. The title of the topmost page is, in order:
///
/// 1. the title a visible entity screen registered with [DocumentTitle];
/// 2. the retained server title, only for the page that took over the
///    canonical URL at launch (it follows that page through a replacement and
///    returns when the page becomes visible again);
/// 3. the localized application title.
class DocumentTitleObserver extends NavigatorObserver {
  DocumentTitleObserver({
    this.retainedTitle,
    this.retainedPath,
    required this.fallbackTitle,
  });

  /// Process-wide instance used by the app; tests build their own.
  static final DocumentTitleObserver shared = DocumentTitleObserver(
    fallbackTitle: () => 'art.kubus',
  );

  final String? Function() fallbackTitle;
  String? retainedTitle;
  String? retainedPath;

  /// The title the visible page should show, or null before the first page.
  final ValueNotifier<String?> title = ValueNotifier<String?>(null);

  final List<Route<dynamic>> _stack = <Route<dynamic>>[];
  final Map<Route<dynamic>, String> _entityTitles = <Route<dynamic>, String>{};
  Route<dynamic>? _retainedRoute;
  bool _retentionResolved = false;
  bool _scheduled = false;

  /// Registers (or clears, with a null/blank [value]) the semantic title of the
  /// entity shown by [route].
  void registerEntityTitle(Route<dynamic>? route, String? value) {
    if (route == null) return;
    final normalized = value?.trim();
    final changed = normalized == null || normalized.isEmpty
        ? _entityTitles.remove(route) != null
        : _entityTitles[route] != normalized;
    if (normalized != null && normalized.isNotEmpty) {
      _entityTitles[route] = normalized;
    }
    if (changed) _schedule();
  }

  String? _effectiveUrl() {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final name = _stack[i].settings.name?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  @visibleForTesting
  void reconcile() {
    if (_stack.isEmpty) return;
    final top = _stack.last;
    final path = retainedPath;
    if (!_retentionResolved) {
      _retentionResolved = true;
      final effective = _effectiveUrl();
      if (path != null && (effective == null || effective == path)) {
        _retainedRoute = top;
      }
    }
    final String? resolved;
    final registered = _entityTitles[top];
    if (registered != null) {
      resolved = registered;
    } else if (identical(top, _retainedRoute) && retainedTitle != null) {
      resolved = retainedTitle;
    } else {
      resolved = fallbackTitle();
    }
    if (resolved != null && resolved != title.value) title.value = resolved;
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      reconcile();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) return;
    _stack.add(route);
    _schedule();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) return;
    _stack.remove(route);
    _entityTitles.remove(route);
    _schedule();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) return;
    _stack.remove(route);
    _entityTitles.remove(route);
    _schedule();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is! PageRoute<dynamic> && oldRoute is! PageRoute<dynamic>) {
      return;
    }
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (oldRoute != null) _entityTitles.remove(oldRoute);
    if (newRoute is PageRoute<dynamic>) {
      if (index >= 0) {
        _stack[index] = newRoute;
      } else {
        _stack.add(newRoute);
      }
      if (identical(oldRoute, _retainedRoute)) _retainedRoute = newRoute;
    } else if (index >= 0) {
      _stack.removeAt(index);
    }
    _schedule();
  }
}

/// Declares the semantic document title of the entity shown by the enclosing
/// page route, for as long as that page exists.
class DocumentTitle extends StatefulWidget {
  const DocumentTitle({
    super.key,
    required this.title,
    required this.child,
    this.observer,
  });

  final String? title;
  final Widget child;
  final DocumentTitleObserver? observer;

  @override
  State<DocumentTitle> createState() => _DocumentTitleState();
}

class _DocumentTitleState extends State<DocumentTitle> {
  Route<dynamic>? _route;

  DocumentTitleObserver get _observer =>
      widget.observer ?? DocumentTitleObserver.shared;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _observer.registerEntityTitle(_route, widget.title);
  }

  @override
  void didUpdateWidget(DocumentTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _observer.registerEntityTitle(_route, widget.title);
  }

  @override
  void dispose() {
    _observer.registerEntityTitle(_route, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
