import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Desktop dialogs must use the shared glass dialog route (barrier, blur
/// policy, transition), not a bare Material showDialog.
void main() {
  test('desktop screens do not call the bare showDialog', () {
    final offenders = <String>[];
    final pattern = RegExp(r'(?<![A-Za-z])showDialog\s*[<(]');
    for (final entity in Directory('lib/screens/desktop').listSync(
      recursive: true,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'use showKubusDialog: $offenders');
  });
}
