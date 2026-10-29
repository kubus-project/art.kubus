import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/common/subject_options_sheet.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens [showSubjectOptionsSheet] from a single control, so each test drives
/// the same entry point the studio uses.
Widget _harness({
  required SubjectOptionsPresentation presentation,
  required List<String> log,
  FocusNode? openerFocus,
  bool reduceMotion = false,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    themeMode: themeMode,
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            focusNode: openerFocus,
            onPressed: () => showSubjectOptionsSheet(
              context: context,
              title: 'Mural',
              subtitle: 'Artwork',
              presentation: presentation,
              actions: [
                SubjectOptionsAction(
                  id: 'edit',
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onSelected: () => log.add('edit'),
                ),
                SubjectOptionsAction(
                  id: 'delete',
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  isDestructive: true,
                  onSelected: () => log.add('delete'),
                ),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('centered management dialog (desktop opt-in)', () {
    testWidgets(
        'sits centered in the viewport and stays within the standard width',
        (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      final log = <String>[];
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: log,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsOneWidget);
      // The dialog's own constrained panel is what is centered and capped; the
      // route box around it spans the whole viewport.
      final panel = find.descendant(
        of: find.byType(KubusAlertDialog),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox &&
              widget.constraints.maxWidth == KubusDialogSize.standard.maxWidth,
        ),
      );
      expect(panel, findsOneWidget);
      final rect = tester.getRect(panel);
      expect((rect.center.dx - 720).abs(), lessThan(2));
      expect((rect.center.dy - 450).abs(), lessThan(2));
      expect(rect.width, lessThanOrEqualTo(KubusDialogSize.standard.maxWidth));
    });

    testWidgets('Escape dismisses without choosing an option', (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      final log = <String>[];
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: log,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('the close control and the scrim both dismiss', (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      final log = <String>[];
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: log,
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(KubusAlertDialog), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(KubusAlertDialog), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('choosing an option runs it once and closes the dialog',
        (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      final log = <String>[];
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: log,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsNothing);
      expect(log, <String>['edit']);
    });

    testWidgets('a destructive option uses the error colour', (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: <String>[],
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
      expect(icon.color, ThemeData.light(useMaterial3: true).colorScheme.error);
    });

    testWidgets('focus returns to the control that opened the dialog',
        (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      final opener = FocusNode(debugLabel: 'opener');
      addTearDown(opener.dispose);
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: <String>[],
        openerFocus: opener,
      ));
      opener.requestFocus();
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(opener.hasPrimaryFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(opener.hasPrimaryFocus, isTrue);
    });

    testWidgets('reduced motion removes the entrance transition',
        (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: <String>[],
        reduceMotion: true,
      ));
      await tester.tap(find.text('Open'));
      // One frame only: with motion reduced the dialog is already fully shown.
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(KubusAlertDialog),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1.0);
    });

    testWidgets('renders in the dark theme without errors', (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.centeredDialog,
        log: <String>[],
        themeMode: ThemeMode.dark,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the shared presentation is unchanged for other callers', () {
    testWidgets('adaptive on a phone keeps the draggable bottom sheet',
        (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.adaptive,
        log: <String>[],
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('adaptive on a wide window keeps the bottom-aligned sheet',
        (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(_harness(
        presentation: SubjectOptionsPresentation.adaptive,
        log: <String>[],
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });
  });
}
