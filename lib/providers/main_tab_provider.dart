import 'package:flutter/foundation.dart';

/// Stores the selected tab index for the mobile MainApp shell.
///
/// Keeping this in a provider allows deep links (and other non-UI entry points)
/// to select the correct tab without bypassing the shell.
class MainTabProvider extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  /// Backward-compatible alias used by parts of the UI.
  ///
  /// Prefer [index] going forward.
  int get currentIndex => _index;

  void setIndex(int value) {
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }
}
