import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop home quick actions use the shared executor', () {
    final source =
        File('lib/screens/desktop/desktop_home_screen.dart').readAsStringSync();

    expect(source, contains('HomeQuickActionExecutor.execute'));
    expect(source, contains('HomeQuickActionSurface.desktopHome'));
    expect(source, contains('resolveSuggestedQuickActionKeys'));
    expect(source, isNot(contains('navigationProvider.navigateToScreen')));
    expect(source, isNot(contains('_suggestedQuickActionKeys')));
  });
}
