import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/contextual_auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    BackendApiService().setAuthTokenForTesting(null);
  });

  testWidgets('cancelling contextual auth keeps the public entity visible',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('public artwork'),
              TextButton(
                onPressed: () async {
                  result = await const ContextualAuthGate().ensureAuthenticated(
                    context,
                    actionLabel: 'save',
                    returnRoute: '/a/art-1',
                  );
                },
                child: const Text('save'),
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in required for save'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('public artwork'), findsOneWidget);
    expect(find.text('Sign-in required for save'), findsNothing);
  });

  testWidgets('contextual auth opens sign-in without replaying the mutation',
      (tester) async {
    var mutationRuns = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: <String, WidgetBuilder>{
        '/sign-in': (_) => const Scaffold(body: Text('sign-in route')),
      },
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final authenticated =
                  await const ContextualAuthGate().ensureAuthenticated(
                context,
                actionLabel: 'follow',
                returnRoute: '/u/profile-1',
              );
              if (authenticated) mutationRuns += 1;
            },
            child: const Text('follow'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('follow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to art.kubus'));
    await tester.pumpAndSettle();

    expect(find.text('sign-in route'), findsOneWidget);
    expect(mutationRuns, 0);
  });
}
