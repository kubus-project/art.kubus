import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Remembers when an activation key (Enter, numpad Enter or Space) was last
/// pressed or released, so a surface opened by that activation can be told
/// apart from one opened by a pointer.
///
/// `FocusManager.highlightMode` is not enough for this: it switches to
/// traditional on any key press, and mouse input leaves it unchanged, so a
/// mouse click after a key press looks like a keyboard activation.
///
/// [install] must run before the first key press that should count, which is
/// why the map screens call it from `initState`. It is idempotent.
class KeyboardActivationTracker {
  KeyboardActivationTracker._();

  /// How long after an activation key event an opened surface still counts as
  /// keyboard-initiated. A card opens within a frame or two of the key event;
  /// the window only has to cover that and a key release.
  static const Duration window = Duration(milliseconds: 600);

  static final Set<LogicalKeyboardKey> _activationKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
  };

  static DateTime? _lastActivationAt;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static void install() {
    // Remove before adding so the handler is registered once. Re-registering
    // also survives HardwareKeyboard.clearState(), which the test binding calls
    // between cases.
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  static bool _handleKeyEvent(KeyEvent event) {
    if (_activationKeys.contains(event.logicalKey)) {
      _lastActivationAt = clock();
    }
    // Observe only: the key is still dispatched to the focus tree.
    return false;
  }

  /// Whether an activation key event happened within [window], consuming it.
  ///
  /// Consuming means one keyboard activation opens at most one focus session:
  /// a card rebuilt by the same activation does not take focus again.
  static bool consumeRecentActivation() {
    final at = _lastActivationAt;
    if (at == null) return false;
    _lastActivationAt = null;
    return clock().difference(at) <= window;
  }

  @visibleForTesting
  static void resetForTests() {
    _lastActivationAt = null;
    clock = DateTime.now;
  }
}
