import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_context_icon.dart';
import 'package:art_kubus/widgets/creator/creator_kit.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 5A management workspace: one header, one edit column and ONE rail
/// whose sections are separated by hairlines, not stacked tinted cards.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final theme = ThemeProvider();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: theme,
      child: MaterialApp(
        theme: theme.darkTheme,
        home: Scaffold(body: child),
      ),
    ));
    await tester.pump();
  }

  Widget rail() => ListView(
        children: const [
          DesktopCreatorSidebarSection(
            title: 'Readiness',
            child: DesktopCreatorReadinessChecklist(
              contextType: DesktopCreatorContextType.artwork,
              items: [
                DesktopCreatorReadinessItem(
                    label: 'Title', complete: true, icon: Icons.title),
                DesktopCreatorReadinessItem(
                    label: 'Cover image',
                    complete: false,
                    icon: Icons.image_outlined),
              ],
            ),
          ),
          DesktopCreatorSidebarSection(
            title: 'Actions',
            child: SizedBox(height: 44),
          ),
        ],
      );

  testWidgets('rail sections are flat, one workspace, typographic headings',
      (tester) async {
    await pump(
      tester,
      DesktopCreatorShell(
        title: 'Riverside mural',
        mainContent: const SizedBox.expand(),
        sidebar: rail(),
      ),
    );

    // No glass anywhere in the management workspace.
    expect(find.byType(LiquidGlassCard), findsNothing);
    expect(find.byType(LiquidGlassPanel), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);

    // One header title.
    expect(find.text('Riverside mural'), findsOneWidget);

    // Section headings are typographic: no icon tile repeats the title.
    expect(
      find.descendant(
        of: find.byType(DesktopCreatorSidebarSection),
        matching: find.byType(KubusContextIcon),
      ),
      findsNothing,
    );
    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);

    // Sections are divided by a hairline, not boxed in tinted fills.
    final sectionBoxes = tester.widgetList<DecoratedBox>(find.descendant(
      of: find.byType(DesktopCreatorSidebarSection),
      matching: find.byType(DecoratedBox),
    ));
    final outer = sectionBoxes
        .map((b) => b.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border is Border && d.color == null);
    expect(outer, isNotEmpty);
  });

  testWidgets('readiness states truthfully: green check, amber open mark',
      (tester) async {
    await pump(tester, rail());
    final roles = KubusColorRoles.of(tester.element(find.text('Title')));
    final done = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
    final open =
        tester.widget<Icon>(find.byIcon(Icons.radio_button_unchecked_rounded));
    Color hue(Color c) => HSVColor.fromColor(c).withValue(1).toColor();
    expect(HSVColor.fromColor(hue(done.color!)).hue,
        closeTo(HSVColor.fromColor(roles.positiveAction).hue, 12));
    expect(HSVColor.fromColor(hue(open.color!)).hue,
        closeTo(HSVColor.fromColor(roles.warningAction).hue, 12));
    // No per-row tinted tile.
    expect(find.byIcon(Icons.title), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });
}
