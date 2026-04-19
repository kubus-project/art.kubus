import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile home quick actions use the shared executor', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(source, contains('HomeQuickActionExecutor.execute'));
    expect(source, contains('HomeQuickActionSurface.mobileHome'));
    expect(source, contains('resolveSuggestedQuickActionKeys'));
    expect(source, isNot(contains('_suggestedQuickActionKeys')));
  });
}
