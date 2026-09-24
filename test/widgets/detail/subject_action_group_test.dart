import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/detail/subject_action_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in const [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('wraps labeled actions without overflow at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(
        SizedBox(
          width: width,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: SubjectActionGroup(
              label: 'Community',
              actions: [
                SubjectAction(
                  icon: Icons.favorite_border,
                  label: 'Like',
                  onPressed: _noop,
                ),
                SubjectAction(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  selectedLabel: 'Saved',
                  isSelected: true,
                  onPressed: _noop,
                ),
                SubjectAction(
                  icon: Icons.forum_outlined,
                  label: 'Discuss',
                  onPressed: _noop,
                ),
                SubjectAction(
                  icon: Icons.share_outlined,
                  label: 'Deli z drugimi',
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Like'), findsOneWidget);
      expect(find.text('Deli z drugimi'), findsOneWidget);
      final saveText = find.text('Saved');
      expect(saveText, findsOneWidget);
      expect(tester.getSize(saveText).height, lessThanOrEqualTo(48));
      final saveButton = find
          .ancestor(
            of: saveText,
            matching: find.byType(ConstrainedBox),
          )
          .first;
      expect(tester.getSize(saveButton).height, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('active action state is exposed as a semantic toggle',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(
      const SubjectActionGroup(
        label: 'Social',
        actions: [
          SubjectAction(
            icon: Icons.bookmark,
            label: 'Save',
            selectedLabel: 'Saved',
            isSelected: true,
            onPressed: _noop,
          ),
        ],
      ),
    ));

    final savedData =
        tester.getSemantics(find.bySemanticsLabel('Saved')).getSemanticsData();
    expect(savedData.flagsCollection.isButton.toString(), 'true');
    expect(
      savedData.flagsCollection.isToggled.toString(),
      'Tristate.isTrue',
    );
    semantics.dispose();
  });
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );

void _noop() {}
