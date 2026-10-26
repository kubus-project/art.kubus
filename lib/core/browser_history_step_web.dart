import 'dart:ui_web' as ui_web;

/// Web implementation: the same `history.go(-1)` the Back button performs.
void stepBrowserHistoryBack() {
  ui_web.urlStrategy?.go(-1);
}

/// Web implementation: the state the Router stored with the current entry.
Object? currentBrowserHistoryState() => ui_web.urlStrategy?.getState();
