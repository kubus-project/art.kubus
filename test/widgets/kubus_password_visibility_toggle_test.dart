import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/common/kubus_password_visibility_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHost({
  required Locale locale,
  required bool obscured,
  required VoidCallback onPressed,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Center(
        child: KubusPasswordVisibilityToggle(
          obscured: obscured,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

SemanticsData _toggleSemantics(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}\$'));
  expect(finder, findsOneWidget, reason: 'no toggle named "$label"');
  return tester.getSemantics(finder).getSemanticsData();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in const [Locale('en'), Locale('sl')]) {
    final l10n = lookupAppLocalizations(locale);

    testWidgets(
        '[${locale.languageCode}] toggle is a named button whose label follows the obscured state',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      var obscured = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _buildHost(
            locale: locale,
            obscured: obscured,
            onPressed: () => setState(() {
              obscured = !obscured;
              taps++;
            }),
          ),
        ),
      );

      // Obscured: the control offers to show the password.
      final show = _toggleSemantics(tester, l10n.formShowPassword);
      expect(show.flagsCollection.isButton, isTrue);
      expect(show.hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel(l10n.formHidePassword), findsNothing);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(taps, 1);
      expect(obscured, isFalse);

      // Visible: the same control offers to hide it.
      final hide = _toggleSemantics(tester, l10n.formHidePassword);
      expect(hide.flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel(l10n.formShowPassword), findsNothing);

      handle.dispose();
    });
  }
}
