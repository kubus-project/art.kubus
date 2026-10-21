import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Desktop dialogs open through `showKubusDialog` so every one gets the shared
/// barrier, transition, safe area and root-navigator behaviour. A bare Material
/// `showDialog` under `lib/screens/desktop` is a regression to the unstyled
/// route.
void main() {
  test('no desktop screen opens a bare Material showDialog', () {
    final violations = <String>[];
    final bareShowDialog =
        RegExp(r'(?<![A-Za-z0-9_])showDialog\s*(<[^>]*>)?\s*\(');
    for (final entity
        in Directory('lib/screens/desktop').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (bareShowDialog.hasMatch(line)) {
          violations.add('${entity.path.replaceAll(r'\', '/')}:${i + 1}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'use showKubusDialog (lib/widgets/glass_components.dart)');
  });
}
