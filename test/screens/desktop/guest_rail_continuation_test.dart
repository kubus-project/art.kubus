import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guest rail continuation', () {
    test('continues to the requested destination only with a session', () {
      expect(shouldContinueToLockedDestination(hasAuthSession: true), isTrue);
    });

    test('stays put when the account journey was dismissed', () {
      expect(shouldContinueToLockedDestination(hasAuthSession: false), isFalse);
    });
  });
}
