import 'package:art_kubus/main.dart' show isAppForegroundState;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Background polling (chat, notifications, presence, collab, public fallback)
/// and the security departure both follow this predicate. Only `resumed` may
/// count as foreground, so a web or desktop `hidden` event without a following
/// `paused` still pauses that work.
void main() {
  test('only resumed is foreground', () {
    expect(isAppForegroundState(AppLifecycleState.resumed), isTrue);
  });

  test('hidden is not foreground even without a following paused', () {
    expect(isAppForegroundState(AppLifecycleState.hidden), isFalse);
  });

  test('paused, inactive and detached are not foreground', () {
    expect(isAppForegroundState(AppLifecycleState.paused), isFalse);
    expect(isAppForegroundState(AppLifecycleState.inactive), isFalse);
    expect(isAppForegroundState(AppLifecycleState.detached), isFalse);
  });

  test('every lifecycle state is classified', () {
    final foreground = AppLifecycleState.values
        .where(isAppForegroundState)
        .toList(growable: false);
    expect(foreground, <AppLifecycleState>[AppLifecycleState.resumed]);
  });
}
