import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(
  WidgetTester tester, {
  required Size view,
  KubusDialogSize? size,
  Widget? content,
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showKubusDialog<void>(
            context: context,
            builder: (ctx) {
              final actions = [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ];
              final body = content ?? const Text('Body');
              return size == null
                  ? KubusAlertDialog(
                      title: const Text('Title'),
                      content: body,
                      actions: actions,
                    )
                  : KubusAlertDialog(
                      size: size,
                      title: const Text('Title'),
                      content: body,
                      actions: actions,
                    );
            },
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Size _panel(WidgetTester tester) => tester.getSize(find.descendant(
      of: find.byType(KubusAlertDialog),
      matching: find.byType(LiquidGlassPanel),
    ));

void main() {
  for (final c in <(double, KubusDialogSize)>[
    (1440, KubusDialogSize.compact),
    (1920, KubusDialogSize.compact),
    (1440, KubusDialogSize.standard),
    (1920, KubusDialogSize.standard),
    (1920, KubusDialogSize.wide),
  ]) {
    testWidgets(
        '${c.$2.name} dialog stays within ${c.$2.maxWidth} on ${c.$1}px',
        (tester) async {
      await _open(tester, view: Size(c.$1, 900), size: c.$2);
      final w = _panel(tester).width;
      expect(w, lessThanOrEqualTo(c.$2.maxWidth));
      expect(w, greaterThan(280));
    });
  }

  testWidgets('the default width class is the standard form width',
      (tester) async {
    await _open(tester, view: const Size(1920, 900));
    expect(_panel(tester).width, KubusDialogSize.standard.maxWidth);
  });

  for (final w in <double>[320, 390]) {
    testWidgets('phones use the available width minus the inset ($w px)',
        (tester) async {
      await _open(tester, view: Size(w, 800));
      expect(_panel(tester).width, w - 2 * KubusSpacing.lg);
    });
  }

  testWidgets('long content scrolls on a short viewport without overflow',
      (tester) async {
    await _open(
      tester,
      view: const Size(1024, 380),
      content:
          Text(List.filled(120, 'Long paragraph that must scroll. ').join()),
    );
    expect(tester.takeException(), isNull);
    expect(_panel(tester).height, lessThanOrEqualTo(380));
    expect(find.text('Close'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('Escape dismisses a dismissible dialog and restores the page',
      (tester) async {
    await _open(tester, view: const Size(1440, 900));
    expect(find.text('Title'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
