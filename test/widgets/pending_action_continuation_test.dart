import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/widgets/auth/pending_action_continuation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingExecutor implements PendingActionExecutor {
  RecordingExecutor({this.outcome = PendingActionOutcome.completed});

  PendingActionOutcome outcome;
  int calls = 0;

  @override
  Future<PendingActionExecutionResult> execute({
    required PendingActionIntent intent,
    required ArtworkProvider artworkProvider,
    required SavedItemsProvider savedItemsProvider,
  }) async {
    calls += 1;
    return PendingActionExecutionResult(outcome);
  }
}

PendingActionIntent _intent({
  PendingActionType action = PendingActionType.save,
  PendingActionTargetType target = PendingActionTargetType.artwork,
  String? label,
}) =>
    PendingActionIntent.create(
      actionType: action,
      targetType: target,
      targetId: 'target-1',
      targetLabel: label,
      returnRoute: '/a/target-1',
      sourceScreen: 'map_marker',
    )!;

Widget _host({
  required PendingActionProvider pendingActions,
  required ArtworkProvider artworkProvider,
  required SavedItemsProvider savedItemsProvider,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
}) {
  // The host lives in MaterialApp.builder, above the Navigator, so it reaches
  // the navigator through this key — exactly as main.dart wires it.
  final navigatorKey = GlobalKey<NavigatorState>();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PendingActionProvider>.value(
          value: pendingActions),
      ChangeNotifierProvider<ArtworkProvider>.value(value: artworkProvider),
      ChangeNotifierProvider<SavedItemsProvider>.value(
          value: savedItemsProvider),
    ],
    child: MaterialApp(
      locale: locale,
      navigatorKey: navigatorKey,
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(size: size),
        child: PendingActionContinuationHost(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const Scaffold(body: Center(child: Text('restored artwork'))),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingExecutor executor;
  late PendingActionProvider pendingActions;
  late ArtworkProvider artworkProvider;
  late SavedItemsProvider savedItemsProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    executor = RecordingExecutor();
    pendingActions = PendingActionProvider(executor: executor);
    artworkProvider = ArtworkProvider();
    savedItemsProvider = SavedItemsProvider();
  });

  Future<void> pumpAndSettleConfirmation(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(PendingActionContinuationHost.settleDelay);
    await tester.pumpAndSettle();
  }

  testWidgets('offers the original action back after authentication',
      (tester) async {
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
    ));

    await pendingActions.capture(_intent(label: 'Blue Wall'));
    await pendingActions.restore();
    await pumpAndSettleConfirmation(tester);

    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('Save this artwork?'), findsOneWidget);
    expect(find.text('Blue Wall'), findsOneWidget);
    // The entity underneath is still there — context was never lost.
    expect(find.text('restored artwork'), findsOneWidget);
    // Nothing has run yet.
    expect(executor.calls, 0);
  });

  testWidgets('confirming applies the action exactly once', (tester) async {
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
    ));

    await pendingActions.capture(_intent());
    await pendingActions.restore();
    await pumpAndSettleConfirmation(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(executor.calls, 1);
    expect(find.text('Saved to your collection'), findsOneWidget);
    expect(pendingActions.pending, isNull);
  });

  testWidgets('cancelling the confirmation does not apply the action',
      (tester) async {
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
    ));

    await pendingActions.capture(_intent());
    await pendingActions.restore();
    await pumpAndSettleConfirmation(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Not now'));
    await tester.pumpAndSettle();

    expect(executor.calls, 0);
    expect(pendingActions.pending, isNull);
    expect(find.text('restored artwork'), findsOneWidget);
  });

  testWidgets('a gone target explains what changed instead of failing silently',
      (tester) async {
    executor.outcome = PendingActionOutcome.targetUnavailable;
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
    ));

    await pendingActions.capture(_intent());
    await pendingActions.restore();
    await pumpAndSettleConfirmation(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no longer available'),
      findsOneWidget,
    );
  });

  testWidgets('the follow confirmation names the right action', (tester) async {
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
    ));

    await pendingActions.capture(_intent(
      action: PendingActionType.follow,
      target: PendingActionTargetType.user,
    ));
    await pendingActions.restore();
    await pumpAndSettleConfirmation(tester);

    expect(find.text('Follow this artist?'), findsOneWidget);
  });

  testWidgets('renders in Slovenian without overflowing a narrow phone',
      (tester) async {
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
      locale: const Locale('sl'),
      size: const Size(360, 740),
    ));

    await pendingActions.capture(_intent(label: 'Modra stena'));
    await pendingActions.restore();
    await pumpAndSettleConfirmation(tester);

    expect(find.text('Vse je pripravljeno'), findsOneWidget);
    expect(find.text('Želiš shraniti to umetnino?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders on a desktop viewport', (tester) async {
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
      size: const Size(1440, 900),
    ));

    await pendingActions.capture(_intent());
    await pendingActions.restore();
    await pumpAndSettleConfirmation(tester);

    expect(find.text('Save this artwork?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows nothing when there is no pending action', (tester) async {
    await tester.pumpWidget(_host(
      pendingActions: pendingActions,
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
    ));

    await pumpAndSettleConfirmation(tester);

    expect(find.text("You're all set"), findsNothing);
    expect(find.text('restored artwork'), findsOneWidget);
  });
}
