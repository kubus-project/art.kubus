import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/contextual_auth_gate.dart';
import 'package:art_kubus/services/pending_action_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness({
  required Widget child,
  PendingActionProvider? pendingActions,
  Map<String, WidgetBuilder> routes = const <String, WidgetBuilder>{},
}) {
  final app = MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: routes,
    home: Scaffold(body: child),
  );
  if (pendingActions == null) return app;
  return ChangeNotifierProvider<PendingActionProvider>.value(
    value: pendingActions,
    child: app,
  );
}

void main() {
  setUp(() {
    BackendApiService().setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the gate leads with the value of the attempted action',
      (tester) async {
    await tester.pumpWidget(_harness(
      child: Builder(
        builder: (context) => Column(
          children: [
            const Text('public artwork'),
            TextButton(
              onPressed: () => const ContextualAuthGate().ensureAuthenticated(
                context,
                actionLabel: 'save',
                returnRoute: '/a/art-1',
                actionType: PendingActionType.save,
                targetType: PendingActionTargetType.artwork,
                targetId: 'art-1',
              ),
              child: const Text('save'),
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    // Value-first, not a requirement notice.
    expect(find.text('Save this artwork to your collection'), findsOneWidget);
    expect(find.textContaining('Sign-in required'), findsNothing);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('the headline adapts to the action and target', (tester) async {
    await tester.pumpWidget(_harness(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: 'follow',
            returnRoute: '/u/artist-1',
            actionType: PendingActionType.follow,
            targetType: PendingActionTargetType.user,
            targetId: 'artist-1',
          ),
          child: const Text('follow'),
        ),
      ),
    ));

    await tester.tap(find.text('follow'));
    await tester.pumpAndSettle();

    expect(find.text('Follow this artist'), findsOneWidget);
  });

  testWidgets('dismissing returns to the same entity and runs no mutation',
      (tester) async {
    bool? result;
    var mutationRuns = 0;
    await tester.pumpWidget(_harness(
      child: Builder(
        builder: (context) => Column(
          children: [
            const Text('public artwork'),
            TextButton(
              onPressed: () async {
                result = await const ContextualAuthGate().ensureAuthenticated(
                  context,
                  actionLabel: 'save',
                  returnRoute: '/a/art-1',
                  actionType: PendingActionType.save,
                  targetType: PendingActionTargetType.artwork,
                  targetId: 'art-1',
                );
                if (result == true) mutationRuns += 1;
              },
              child: const Text('save'),
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(mutationRuns, 0);
    expect(find.text('public artwork'), findsOneWidget);
    expect(find.text('Save this artwork to your collection'), findsNothing);
  });

  testWidgets('choosing a method routes to registration with the return route',
      (tester) async {
    var mutationRuns = 0;
    Object? registerArguments;

    await tester.pumpWidget(_harness(
      routes: <String, WidgetBuilder>{
        '/register': (context) {
          registerArguments = ModalRoute.of(context)?.settings.arguments;
          return const Scaffold(body: Text('register route'));
        },
      },
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final authenticated =
                await const ContextualAuthGate().ensureAuthenticated(
              context,
              actionLabel: 'follow',
              returnRoute: '/u/profile-1',
              actionType: PendingActionType.follow,
              targetType: PendingActionTargetType.user,
              targetId: 'profile-1',
            );
            if (authenticated) mutationRuns += 1;
          },
          child: const Text('follow'),
        ),
      ),
    ));

    await tester.tap(find.text('follow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('register route'), findsOneWidget);
    // The mutation is deliberately never replayed by the gate itself.
    expect(mutationRuns, 0);
    expect(
      (registerArguments as Map?)?['redirectRoute'],
      '/u/profile-1',
    );
  });

  testWidgets('an existing-account choice routes to sign-in', (tester) async {
    await tester.pumpWidget(_harness(
      routes: <String, WidgetBuilder>{
        '/sign-in': (_) => const Scaffold(body: Text('sign-in route')),
      },
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: 'save',
            returnRoute: '/a/art-1',
            actionType: PendingActionType.save,
            targetType: PendingActionTargetType.artwork,
            targetId: 'art-1',
          ),
          child: const Text('save'),
        ),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('sign-in route'), findsOneWidget);
  });

  testWidgets('the attempted action is captured for later continuation',
      (tester) async {
    final pendingActions = PendingActionProvider();

    await tester.pumpWidget(_harness(
      pendingActions: pendingActions,
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: 'save',
            returnRoute: '/m/marker-9',
            actionType: PendingActionType.save,
            targetType: PendingActionTargetType.artwork,
            targetId: 'art-1',
            targetLabel: 'Blue Wall',
            markerId: 'marker-9',
            sourceScreen: 'map_marker',
          ),
          child: const Text('save'),
        ),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    final captured = pendingActions.pending;
    expect(captured, isNotNull);
    expect(captured!.actionType, PendingActionType.save);
    expect(captured.targetType, PendingActionTargetType.artwork);
    expect(captured.targetId, 'art-1');
    expect(captured.returnRoute, '/m/marker-9');
    expect(captured.markerId, 'marker-9');
    expect(captured.sourceScreen, 'map_marker');

    // ...and it survives to storage so it outlives the auth round trip.
    final stored = await const PendingActionService().read();
    expect(stored?.targetId, 'art-1');

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });

  testWidgets('privileged actions capture no replayable intent',
      (tester) async {
    final pendingActions = PendingActionProvider();

    await tester.pumpWidget(_harness(
      pendingActions: pendingActions,
      child: Builder(
        builder: (context) => TextButton(
          // Claiming street art is privileged: no descriptors are supplied, so
          // nothing about it may cross the authentication boundary.
          onPressed: () => const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: 'claim',
            returnRoute: '/map',
          ),
          child: const Text('claim'),
        ),
      ),
    ));

    await tester.tap(find.text('claim'));
    await tester.pumpAndSettle();

    expect(find.text('Create a free account to claim'), findsOneWidget);
    expect(pendingActions.pending, isNull);
    expect(await const PendingActionService().read(), isNull);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });

  testWidgets('an authenticated visitor is never gated', (tester) async {
    BackendApiService().setAuthTokenForTesting('token');
    addTearDown(() => BackendApiService().setAuthTokenForTesting(null));

    bool? result;
    await tester.pumpWidget(_harness(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await const ContextualAuthGate().ensureAuthenticated(
              context,
              actionLabel: 'save',
              returnRoute: '/a/art-1',
              actionType: PendingActionType.save,
              targetType: PendingActionTargetType.artwork,
              targetId: 'art-1',
            );
          },
          child: const Text('save'),
        ),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Save this artwork to your collection'), findsNothing);
  });
}
