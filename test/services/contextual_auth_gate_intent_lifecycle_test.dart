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

Widget _harness(
    {required PendingActionProvider pendingActions, required Widget child}) {
  return ChangeNotifierProvider<PendingActionProvider>.value(
    value: pendingActions,
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: <String, WidgetBuilder>{
        '/onboarding': (_) => const Scaffold(body: Text('onboarding route')),
      },
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _likeButton(PendingActionProvider pendingActions) => _harness(
      pendingActions: pendingActions,
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: 'like',
            returnRoute: '/p/post-1',
            actionType: PendingActionType.like,
            targetType: PendingActionTargetType.post,
            targetId: 'post-1',
          ),
          child: const Text('like'),
        ),
      ),
    );

void main() {
  setUp(() {
    BackendApiService().setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('captured intent lifecycle', () {
    testWidgets('dismissing the gate drops the intent it captured',
        (tester) async {
      final pendingActions = PendingActionProvider();
      await tester.pumpWidget(_likeButton(pendingActions));

      await tester.tap(find.text('like'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // A dismissed gate must not leave a like that a later, unrelated
      // sign-in would offer back to the visitor.
      expect(pendingActions.pending, isNull);
      expect(await const PendingActionService().read(), isNull);
    });

    testWidgets('a repeated tap before the gate opens shows a single gate',
        (tester) async {
      final pendingActions = PendingActionProvider();
      await tester.pumpWidget(_likeButton(pendingActions));

      await tester.tap(find.text('like'));
      await tester.tap(find.text('like'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Not now'), findsOneWidget);
    });

    test('an intent removed at sign-out is never offered afterwards', () async {
      final pendingActions = PendingActionProvider();
      await pendingActions.capture(_like());

      // Sign-out removes the stored intent (SettingsService.logout does this
      // through the same service call).
      await const PendingActionService().clear();
      await pendingActions.restore();

      expect(pendingActions.isAwaitingConfirmation, isFalse);
      expect(pendingActions.pending, isNull);
    });

    test('an intent older than its window is not offered', () async {
      final pendingActions = PendingActionProvider();
      final stale = PendingActionIntent.create(
        actionType: PendingActionType.like,
        targetType: PendingActionTargetType.post,
        targetId: 'post-1',
        returnRoute: '/p/post-1',
        sourceScreen: 'community_feed',
        nowUtc: DateTime.now().toUtc().subtract(
              PendingActionIntent.ttl + const Duration(minutes: 1),
            ),
      )!;
      await pendingActions.capture(stale);
      await pendingActions.restore();

      expect(pendingActions.isAwaitingConfirmation, isFalse);
      expect(pendingActions.pending, isNull);
    });
  });
}

PendingActionIntent _like() => PendingActionIntent.create(
      actionType: PendingActionType.like,
      targetType: PendingActionTargetType.post,
      targetId: 'post-1',
      returnRoute: '/p/post-1',
      sourceScreen: 'community_feed',
    )!;
