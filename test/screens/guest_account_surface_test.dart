import 'package:art_kubus/main_app.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guest account exposes sign-in, registration, and settings',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routes: <String, WidgetBuilder>{
          '/register': (_) => const Scaffold(body: Text('register-screen')),
        },
        home: const GuestAccountScreen(),
      ),
    );

    expect(find.byKey(const Key('guest_account_sign_in')), findsOneWidget);
    expect(
        find.byKey(const Key('guest_account_create_account')), findsOneWidget);
    expect(find.byKey(const Key('guest_account_settings')), findsOneWidget);

    await tester.tap(find.byKey(const Key('guest_account_create_account')));
    await tester.pumpAndSettle();
    expect(find.text('register-screen'), findsOneWidget);
  });
}
