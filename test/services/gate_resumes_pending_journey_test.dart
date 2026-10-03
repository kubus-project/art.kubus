import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/onboarding_completion_navigation.dart';
import 'package:art_kubus/providers/deferred_onboarding_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/contextual_auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A visitor opens a public entity (deep link or search) while an interrupted
/// account journey is armed, then taps a protected action. The journey must
/// resume *above* the entity, the attempted action must already be captured,
/// and completing it must return to that exact entity.
class _Probe {
  ResumedProbe? resumed;
}

class ResumedProbe {
  ResumedProbe({
    required this.step,
    required this.route,
    required this.args,
    required this.requirements,
    required this.wallet,
    required this.navigation,
  });

  final String step;
  final String route;
  final Object? args;
  final ProtectedActionRequirements requirements;
  final bool wallet;
  final OnboardingCompletionNavigation navigation;
}

class _PushObserver extends NavigatorObserver {
  final List<String> events = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('push ${route.settings.name}');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      events.add('replace ${newRoute?.settings.name}');
}

void main() {
  late _Probe probe;
  late DeferredOnboardingProvider deferred;
  late PendingActionProvider pending;
  late _PushObserver observer;
  var mutationRuns = 0;

  Widget app(Widget Function(BuildContext) action) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<PendingActionProvider>.value(value: pending),
        ChangeNotifierProvider<DeferredOnboardingProvider>.value(
          value: deferred,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: <NavigatorObserver>[observer],
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const Text('public artwork'),
              Builder(builder: action),
            ],
          ),
        ),
      ),
    );
  }

  setUp(() {
    BackendApiService().setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mutationRuns = 0;
    probe = _Probe();
    observer = _PushObserver();
    pending = PendingActionProvider();
    deferred = DeferredOnboardingProvider(
      onboardingBuilder: ({
        required forceDesktop,
        required initialStepId,
        required completionRoute,
        required completionArguments,
        required requirements,
        required requiresWalletSetup,
        required completionNavigation,
      }) {
        probe.resumed = ResumedProbe(
          step: initialStepId,
          route: completionRoute,
          args: completionArguments,
          requirements: requirements,
          wallet: requiresWalletSetup,
          navigation: completionNavigation,
        );
        return const Scaffold(body: Text('resumed account journey'));
      },
    );
    // An interrupted email verification, recovered at startup.
    deferred.enableForProtectedAction(initialStepId: 'verifyEmail');
  });

  testWidgets(
      'Save on a public entity captures the action, then resumes the journey '
      'above the entity and returns to it', (tester) async {
    await tester.pumpWidget(app(
      (context) => TextButton(
        onPressed: () async {
          final ok = await const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: 'save',
            returnRoute: '/en/artworks/art-1',
            actionType: PendingActionType.save,
            targetType: PendingActionTargetType.artwork,
            targetId: 'art-1',
          );
          if (ok) mutationRuns += 1;
        },
        child: const Text('save'),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    // The attempted action survives.
    expect(pending.pending, isNotNull);
    expect(pending.pending!.actionType, PendingActionType.save);
    expect(pending.pending!.targetId, 'art-1');
    expect(pending.pending!.returnRoute, '/en/artworks/art-1');

    // The interrupted journey resumes at its own step, above the entity.
    expect(find.text('resumed account journey'), findsOneWidget);
    expect(find.text('public artwork', skipOffstage: false), findsOneWidget,
        reason: 'the entity must stay on the stack beneath the journey');
    expect(observer.events.where((e) => e.startsWith('replace')), isEmpty);
    expect(observer.events.last, 'push /onboarding');

    // Completion returns to the exact entity for explicit confirmation.
    final resumed = probe.resumed!;
    expect(resumed.step, 'verifyEmail');
    expect(resumed.route, '/en/artworks/art-1');
    expect(
      resumed.navigation,
      OnboardingCompletionNavigation.returnToOrigin,
    );
    expect(resumed.requirements, ProtectedActionRequirements.accountOnly);

    // No mutation runs, and nothing duplicates it.
    expect(mutationRuns, 0);
  });

  testWidgets('the journey is resumed once; the next attempt gets the sheet',
      (tester) async {
    await tester.pumpWidget(app(
      (context) => TextButton(
        onPressed: () => const ContextualAuthGate().ensureAuthenticated(
          context,
          actionLabel: 'save',
          returnRoute: '/en/artworks/art-1',
          actionType: PendingActionType.save,
          targetType: PendingActionTargetType.artwork,
          targetId: 'art-1',
        ),
        child: const Text('save'),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('resumed account journey'), findsOneWidget);

    Navigator.of(tester.element(find.text('resumed account journey'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(observer.events.where((e) => e == 'push /onboarding'), hasLength(1));
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets(
      'a wallet action resumes the journey with the wallet scope and captures '
      'no replayable intent', (tester) async {
    await tester.pumpWidget(app(
      (context) => TextButton(
        onPressed: () => const ContextualAuthGate().ensureAuthenticated(
          context,
          actionLabel: 'infrastructure',
          returnRoute: '/wallet/availability-node',
          requirements: ProtectedActionRequirements.wallet,
        ),
        child: const Text('open'),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(pending.pending, isNull);
    final resumed = probe.resumed!;
    expect(resumed.route, '/wallet/availability-node');
    expect(resumed.requirements, ProtectedActionRequirements.wallet);
    expect(resumed.wallet, isTrue);
  });

  testWidgets('the resumed scope keeps the wider of journey and action',
      (tester) async {
    deferred.reset();
    deferred.enableForProtectedAction(
      initialStepId: 'account',
      requirements: ProtectedActionRequirements.accountOnly,
    );

    await tester.pumpWidget(app(
      (context) => TextButton(
        onPressed: () => const ContextualAuthGate().ensureAuthenticated(
          context,
          actionLabel: 'message',
          returnRoute: '/u/profile-1',
          requirements: ProtectedActionRequirements.participant,
        ),
        child: const Text('dm'),
      ),
    ));

    await tester.tap(find.text('dm'));
    await tester.pumpAndSettle();

    expect(
        probe.resumed!.requirements, ProtectedActionRequirements.participant);
  });
}
