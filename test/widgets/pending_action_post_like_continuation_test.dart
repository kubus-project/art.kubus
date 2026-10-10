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

class _CountingExecutor implements PendingActionExecutor {
  int calls = 0;
  PendingActionIntent? lastIntent;

  @override
  Future<PendingActionExecutionResult> execute({
    required PendingActionIntent intent,
    required ArtworkProvider artworkProvider,
    required SavedItemsProvider savedItemsProvider,
  }) async {
    calls += 1;
    lastIntent = intent;
    return const PendingActionExecutionResult(
      PendingActionOutcome.completed,
    );
  }
}

PendingActionIntent _postLike() => PendingActionIntent.create(
      actionType: PendingActionType.like,
      targetType: PendingActionTargetType.post,
      targetId: 'post-1',
      returnRoute: '/p/post-1',
      sourceScreen: 'community_feed',
    )!;

Widget _host({
  required PendingActionProvider pendingActions,
  Locale locale = const Locale('en'),
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PendingActionProvider>.value(
          value: pendingActions),
      ChangeNotifierProvider<ArtworkProvider>(create: (_) => ArtworkProvider()),
      ChangeNotifierProvider<SavedItemsProvider>(
          create: (_) => SavedItemsProvider()),
    ],
    child: MaterialApp(
      locale: locale,
      navigatorKey: navigatorKey,
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: PendingActionContinuationHost(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const Scaffold(body: Center(child: Text('restored post'))),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingExecutor executor;
  late PendingActionProvider pendingActions;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    executor = _CountingExecutor();
    pendingActions = PendingActionProvider(executor: executor);
  });

  Future<void> restoreAndSettle(WidgetTester tester) async {
    await pendingActions.capture(_postLike());
    await pendingActions.restore();
    await tester.pump();
    await tester.pump(PendingActionContinuationHost.settleDelay);
    await tester.pumpAndSettle();
  }

  testWidgets('a restored post like is offered as a post, not an artwork',
      (tester) async {
    await tester.pumpWidget(_host(pendingActions: pendingActions));
    await restoreAndSettle(tester);

    expect(find.text('Like this post?'), findsOneWidget);
    expect(find.text('Like this artwork?'), findsNothing);
    expect(executor.calls, 0);
  });

  testWidgets('confirming a post like applies it exactly once', (tester) async {
    await tester.pumpWidget(_host(pendingActions: pendingActions));
    await restoreAndSettle(tester);

    final confirm = find.widgetWithText(FilledButton, 'Like');
    await tester.tap(confirm);
    // A second tap while the first confirmation is still running must not
    // start another mutation.
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(executor.calls, 1);
    expect(executor.lastIntent?.identityKey, 'like:post:post-1');
    expect(pendingActions.pending, isNull);
  });

  testWidgets('the post like confirmation reads in Slovenian', (tester) async {
    await tester.pumpWidget(
      _host(pendingActions: pendingActions, locale: const Locale('sl')),
    );
    await restoreAndSettle(tester);

    expect(find.text('Želiš všečkati to objavo?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
