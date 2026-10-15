import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Ink>(find.byType(Ink)).decoration! as BoxDecoration;

void main() {
  testWidgets('is a rounded rectangle on the control radius, never a circle',
      (tester) async {
    await tester.pumpWidget(_wrap(KubusIconActionButton(
      icon: Icons.send_rounded,
      tooltip: 'Send',
      onPressed: () {},
    )));
    expect(
      _decoration(tester).borderRadius,
      BorderRadius.circular(KubusRadius.control),
    );
    expect(_decoration(tester).shape, BoxShape.rectangle);
  });

  testWidgets('keeps a 48 px target by default and never below 44',
      (tester) async {
    await tester.pumpWidget(_wrap(KubusIconActionButton(
      icon: Icons.send_rounded,
      tooltip: 'Send',
      onPressed: () {},
    )));
    expect(tester.getSize(find.byType(Ink)), const Size(48, 48));

    await tester.pumpWidget(_wrap(KubusIconActionButton(
      icon: Icons.send_rounded,
      tooltip: 'Send',
      size: 32,
      onPressed: () {},
    )));
    expect(tester.getSize(find.byType(Ink)), const Size(44, 44));
  });

  testWidgets(
      'taps, has an accessible name, and blocks taps while disabled '
      'or loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(KubusIconActionButton(
      icon: Icons.send_rounded,
      tooltip: 'Send',
      onPressed: () => taps++,
    )));
    await tester.tap(find.byType(KubusIconActionButton));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Send'), findsOneWidget);

    await tester.pumpWidget(_wrap(const KubusIconActionButton(
      icon: Icons.send_rounded,
      tooltip: 'Send',
      onPressed: null,
    )));
    await tester.tap(find.byType(KubusIconActionButton), warnIfMissed: false);
    expect(taps, 1);

    await tester.pumpWidget(_wrap(KubusIconActionButton(
      icon: Icons.send_rounded,
      tooltip: 'Send',
      isLoading: true,
      onPressed: () => taps++,
    )));
    expect(find.byType(InlineLoading), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    await tester.tap(find.byType(KubusIconActionButton), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('keyboard focus activates it with Enter', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(KubusIconActionButton(
      icon: Icons.send_rounded,
      tooltip: 'Send',
      onPressed: () => taps++,
    )));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  group('app theme', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final dark in <bool>[false, true]) {
      test(
          '${dark ? 'dark' : 'light'} Material buttons share the control '
          'shape', () {
        final provider = ThemeProvider();
        final theme = dark ? provider.darkTheme : provider.lightTheme;
        final expected = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.control),
        );
        final none = <WidgetState>{};
        final shapes = <String, OutlinedBorder?>{
          'text': theme.textButtonTheme.style?.shape?.resolve(none),
          'filled': theme.filledButtonTheme.style?.shape?.resolve(none),
          'outlined': theme.outlinedButtonTheme.style?.shape?.resolve(none),
          'icon': theme.iconButtonTheme.style?.shape?.resolve(none),
          'elevated': theme.elevatedButtonTheme.style?.shape?.resolve(none),
        };
        shapes.forEach((name, shape) {
          expect(shape, expected, reason: '$name button shape');
        });
      });
    }
  });
}
