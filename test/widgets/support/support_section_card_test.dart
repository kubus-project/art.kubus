import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/support/support_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('SupportSectionCard renders methods and opens the tiers dialog', (tester) async {
    await tester.pumpWidget(wrapWithApp(const SupportSectionCard()));

    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Ko-fi'), findsOneWidget);
    expect(find.text('PayPal'), findsOneWidget);
    expect(find.text('GitHub Sponsors'), findsOneWidget);

    await tester.tap(find.text('More info'));
    await tester.pumpAndSettle();

    expect(find.text('What your support enables'), findsOneWidget);
    expect(find.text('€5'), findsOneWidget);
    expect(find.text('€15'), findsOneWidget);
    expect(find.text('€50'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('What your support enables'), findsNothing);
  });
}
