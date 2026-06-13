import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/detail/expandable_detail_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final String _longText = List.generate(
  40,
  (i) =>
      'Paragraph $i of a long curatorial essay describing the exhibition '
      'concept, the participating artists, and the historical context.',
).join('\n');

Widget _wrap({required Widget child, double width = 360}) {
  return MaterialApp(
    // InkSparkle's fragment shader cannot load in the widget-test environment.
    theme: ThemeData(splashFactory: InkSplash.splashFactory),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ExpandableDetailText)))!;

Text _bodyText(WidgetTester tester) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byType(ExpandableDetailText),
      matching: find.text(_longText),
    ),
  );
}

void main() {
  testWidgets('clamps long text initially and shows the expand toggle',
      (tester) async {
    await tester.pumpWidget(
      _wrap(child: ExpandableDetailText(text: _longText)),
    );

    final l10n = _l10n(tester);
    expect(_bodyText(tester).maxLines, 8);
    expect(find.text(l10n.detailShowMore), findsOneWidget);
    expect(find.text(l10n.detailShowLess), findsNothing);
  });

  testWidgets('tapping Show more expands and Show less collapses again',
      (tester) async {
    await tester.pumpWidget(
      _wrap(child: ExpandableDetailText(text: _longText)),
    );
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.detailShowMore));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_bodyText(tester).maxLines, isNull);
    expect(find.text(l10n.detailShowLess), findsOneWidget);
    expect(find.text(l10n.detailShowMore), findsNothing);

    await tester.tap(find.text(l10n.detailShowLess));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_bodyText(tester).maxLines, 8);
    expect(find.text(l10n.detailShowMore), findsOneWidget);
  });

  testWidgets('short text renders plainly without a toggle', (tester) async {
    const shortText = 'A short description.';
    await tester.pumpWidget(
      _wrap(child: const ExpandableDetailText(text: shortText)),
    );

    final l10n = _l10n(tester);
    expect(find.text(shortText), findsOneWidget);
    expect(find.text(l10n.detailShowMore), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('respects a custom collapsedMaxLines', (tester) async {
    await tester.pumpWidget(
      _wrap(
        child: ExpandableDetailText(text: _longText, collapsedMaxLines: 3),
      ),
    );

    expect(_bodyText(tester).maxLines, 3);
  });

  testWidgets('does not overflow on a narrow width, collapsed or expanded',
      (tester) async {
    await tester.pumpWidget(
      _wrap(width: 220, child: ExpandableDetailText(text: _longText)),
    );
    final l10n = _l10n(tester);

    // The framework fails the test automatically on RenderFlex overflow;
    // exercise both states to cover them.
    await tester.tap(find.text(l10n.detailShowMore));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.detailShowLess), findsOneWidget);

    await tester.tap(find.text(l10n.detailShowLess));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.detailShowMore), findsOneWidget);
  });
}
