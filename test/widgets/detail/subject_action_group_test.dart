import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/detail/subject_action_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('one-shot actions do not declare toggle semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(
      const SubjectActionGroup(
        label: 'Actions',
        actions: [
          SubjectAction(
            icon: Icons.share_outlined,
            label: 'Share',
            onPressed: _noop,
          ),
          SubjectAction(
            icon: Icons.navigation_outlined,
            label: 'Navigate',
            onPressed: _noop,
          ),
          SubjectAction(
            icon: Icons.map_outlined,
            label: 'Open on map',
            onPressed: _noop,
          ),
        ],
      ),
    ));

    for (final label in const ['Share', 'Navigate', 'Open on map']) {
      final actionSemantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == label,
      );
      expect(actionSemantics, findsOneWidget);
      expect(
          tester.widget<Semantics>(actionSemantics).properties.toggled, isNull);
    }
    semantics.dispose();
  });

  testWidgets('unselected stateful action declares a false toggle state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(
      const SubjectActionGroup(
        label: 'Actions',
        actions: [
          SubjectAction(
            icon: Icons.favorite_border,
            label: 'Like',
            selectedLabel: 'Liked',
            isSelected: false,
            onPressed: _noop,
          ),
        ],
      ),
    ));

    final action = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Like',
    );
    expect(action, findsOneWidget);
    expect(tester.widget<Semantics>(action).properties.toggled, isFalse);
    semantics.dispose();
  });

  group('rowWithPrimary layout (desktop artwork sidebar)', () {
    for (final width in const [320.0, 360.0, 420.0]) {
      testWidgets(
          'five actions form one row under a full-width primary at $width px',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(
          SizedBox(
            width: width,
            child: SubjectActionGroup(
              label: 'Social',
              layout: SubjectActionLayout.rowWithPrimary,
              actions: _fiveActions((_) {}),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final primary = tester.getRect(
          find.byKey(const ValueKey<String>('subject_action_primary:Like')),
        );
        expect(primary.width, closeTo(width, 0.5));

        final icons = [
          for (final label in _iconLabels)
            tester.getRect(
              find.byKey(ValueKey<String>('subject_action_icon:$label')),
            ),
        ];
        // One row: every icon button sits on the same line.
        expect(icons.map((r) => r.top.round()).toSet(), hasLength(1));
        // Equal widths, in order, all inside the group and below the primary.
        for (final rect in icons) {
          expect(rect.width, closeTo(icons.first.width, 0.5));
          expect(rect.top, greaterThanOrEqualTo(primary.bottom));
          expect(rect.right, lessThanOrEqualTo(width + 0.5));
        }
        for (var i = 1; i < icons.length; i++) {
          expect(icons[i].left, greaterThan(icons[i - 1].left));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('icon actions keep the localized spoken label and a tooltip',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        SizedBox(
          width: 360,
          child: SubjectActionGroup(
            label: 'Social',
            layout: SubjectActionLayout.rowWithPrimary,
            actions: _fiveActions((_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // The primary keeps its label; icon actions speak the same label.
      for (final spoken in [
        'Like',
        'Saved',
        'Discuss',
        'Share',
        'Open on map'
      ]) {
        expect(find.bySemanticsLabel(spoken), findsOneWidget, reason: spoken);
      }
      // Tooltips show the same text on hover and long press.
      expect(find.byTooltip('Discuss'), findsOneWidget);
      expect(find.byTooltip('Saved'), findsOneWidget);
      expect(find.byTooltip('Open on map'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('keyboard reaches the primary, then icon actions in order',
        (tester) async {
      final fired = <String>[];
      await tester.pumpWidget(_app(
        SizedBox(
          width: 360,
          child: SubjectActionGroup(
            label: 'Social',
            layout: SubjectActionLayout.rowWithPrimary,
            actions: _fiveActions(fired.add),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      for (final expected in _order) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(fired.last, expected);
      }
      expect(fired, _order);
    });
  });

  testWidgets('a row layout with no actions renders nothing and does not throw',
      (tester) async {
    await tester.pumpWidget(_app(
      const SubjectActionGroup(
        label: 'Spatial',
        actions: <SubjectAction>[],
        layout: SubjectActionLayout.rowWithPrimary,
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Spatial'), findsNothing);
  });

  testWidgets('a lone secondary action in the row layout keeps its label',
      (tester) async {
    await tester.pumpWidget(_app(
      const SubjectActionGroup(
        label: 'Spatial',
        layout: SubjectActionLayout.rowWithPrimary,
        actions: [
          SubjectAction(
            icon: Icons.map_outlined,
            label: 'Show on map',
            onPressed: _noop,
          ),
          SubjectAction(
            icon: Icons.navigation_outlined,
            label: 'Navigate',
            onPressed: _noop,
          ),
        ],
      ),
    ));
    await tester.pump();

    expect(find.text('Show on map'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );

void _noop() {}

const _iconLabels = ['Save', 'Discuss', 'Share', 'Open on map'];
const _order = ['Like', 'Save', 'Discuss', 'Share', 'Open on map'];

List<SubjectAction> _fiveActions(void Function(String label) onTap) => [
      SubjectAction(
        icon: Icons.favorite_border,
        label: 'Like',
        onPressed: () => onTap('Like'),
      ),
      SubjectAction(
        icon: Icons.bookmark_border,
        label: 'Save',
        selectedLabel: 'Saved',
        isSelected: true,
        onPressed: () => onTap('Save'),
      ),
      SubjectAction(
        icon: Icons.forum_outlined,
        label: 'Discuss',
        onPressed: () => onTap('Discuss'),
      ),
      SubjectAction(
        icon: Icons.share_outlined,
        label: 'Share',
        onPressed: () => onTap('Share'),
      ),
      SubjectAction(
        icon: Icons.map_outlined,
        label: 'Open on map',
        onPressed: () => onTap('Open on map'),
      ),
    ];
