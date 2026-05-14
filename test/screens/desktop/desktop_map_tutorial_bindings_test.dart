import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop filters tutorial step targets the filter button key', () {
    final source =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();
    final filterStepMatch = RegExp(
      r"MapTutorialStepBinding\(\s*id: 'filters',([\s\S]*?)\n\s*\),\s*MapTutorialStepBinding\(",
    ).firstMatch(source);

    expect(filterStepMatch, isNotNull);
    final filterStepSource = filterStepMatch!.group(1)!;

    expect(filterStepSource, contains('_tutorialFiltersButtonKey'));
    expect(filterStepSource, isNot(contains('_tutorialSearchPanelKey')));
    expect(
      source,
      contains('key: _tutorialFiltersButtonKey'),
      reason: 'The tutorial key should remain attached to the visible filter '
          'button wrapper.',
    );
  });
}
