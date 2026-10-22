import 'dart:ui_web' as ui_web;

/// Web implementation: the same `history.go(-1)` the Back button performs.
void stepBrowserHistoryBack() {
  ui_web.urlStrategy?.go(-1);
}
