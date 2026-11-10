import 'package:art_kubus/widgets/detail/shared_settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every settings switch was a nameless "switch" to screen readers (found by
/// the 2026-11-09 analytics E2E: the Analytics withdrawal switch could not be
/// found by its name). The row is one node: title, subtitle, toggle state.
void main() {
  testWidgets('a settings switch is announced with its title and subtitle',
      (tester) async {
    final handle = tester.ensureSemantics();
    var value = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SharedSettingsToggleRow(
            title: 'Analytics',
            subtitle: 'Help improve the app',
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    ));

    final node = tester.getSemantics(find.byType(Switch));
    final data = node.getSemanticsData();
    expect(data.label, contains('Analytics'));
    expect(data.label, contains('Help improve the app'));
    expect(node, isSemantics(isToggled: true, hasToggledState: true));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(tester.getSemantics(find.byType(Switch)),
        isSemantics(isToggled: false, hasToggledState: true));
    handle.dispose();
  });
}
