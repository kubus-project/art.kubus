import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Release builds must not expose developer role simulation.
///
/// Widget tests always run in debug mode, so `kDebugMode` cannot be flipped
/// here. Instead this guard checks the source contract: every product
/// reference to the role-simulation UI sits behind a `kDebugMode` check.
void main() {
  test('role simulation UI is only reachable behind kDebugMode', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.contains('/l10n/')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Entry points only: the tile title and the sheet opener/definition.
        // Strings inside the (guarded) sheet body are not entry points.
        if (!lines[i].contains('settingsRoleSimulationTileTitle') &&
            !lines[i].contains('_showRoleSimulationSheet')) {
          continue;
        }
        hits.add('$normalized:${i + 1}');
        final window =
            lines.sublist((i - 6).clamp(0, lines.length), i + 1).join('\n');
        final isDefinition =
            lines[i].trimLeft().startsWith('void _showRoleSimulationSheet');
        final guardedNearby = window.contains('kDebugMode');
        expect(
          isDefinition || guardedNearby,
          isTrue,
          reason: 'Unguarded role-simulation reference at $normalized:${i + 1}',
        );
        if (isDefinition) {
          final body = lines.sublist(i, (i + 3).clamp(0, lines.length));
          expect(
            body.join('\n'),
            contains('if (!kDebugMode) return;'),
            reason: 'Role simulation sheet must refuse to open in release.',
          );
        }
      }
    }
    expect(hits, isNotEmpty, reason: 'Guard lost track of the debug tile.');
  });
}
