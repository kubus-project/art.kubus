import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures exactly what [PostAuthCoordinator] asked to resolve, standing in
/// for the real redirect logic so this test does not depend on a hydrated
/// profile/wallet session.
class _SpyAuthRedirectController extends AuthRedirectController {
  const _SpyAuthRedirectController(this.onResolve);

  final void Function({String? redirectRoute, Object? redirectArguments})
      onResolve;

  @override
  Future<PostAuthRedirectResult> resolvePostAuthRedirect({
    required SharedPreferences prefs,
    required Map<String, dynamic> payload,
    required bool hasHydratedProfile,
    required bool requiresWalletBackup,
    String? walletAddress,
    String? userId,
    String? redirectRoute,
    Object? redirectArguments,
    String? heuristicNextStepId,
    String? persona,
    bool removeAuthStack = true,
    AuthOrigin origin = AuthOrigin.emailPassword,
    bool requiresWalletSetup = false,
  }) async {
    onResolve(
      redirectRoute: redirectRoute,
      redirectArguments: redirectArguments,
    );
    return PostAuthRedirectResult(
      state: PostAuthRouteState.ready,
      routeName:
          (redirectRoute ?? '').trim().isEmpty ? '/main' : redirectRoute!,
      arguments: redirectArguments,
      completionRoute: redirectRoute,
    );
  }
}

Widget _harness({
  required PendingActionProvider pendingActionProvider,
  required Widget child,
}) {
  final walletProvider = WalletProvider(deferInit: true);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<SavedItemsProvider>(
        create: (_) => SavedItemsProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
      ),
      ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
      ChangeNotifierProvider<PendingActionProvider>.value(
        value: pendingActionProvider,
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'restores the pending intent\'s own route AND arguments together, '
    'not paired with an unrelated redirect',
    (tester) async {
      final pendingActionProvider = PendingActionProvider();
      final intent = PendingActionIntent.create(
        actionType: PendingActionType.save,
        targetType: PendingActionTargetType.event,
        targetId: 'event-42',
        returnRoute: '/e/event-42',
        returnArguments: const <String, String>{'eventId': 'event-42'},
        sourceScreen: 'map_marker',
      )!;
      await pendingActionProvider.capture(intent);

      String? capturedRoute;
      Object? capturedArguments;
      final spy = _SpyAuthRedirectController((
          {String? redirectRoute, Object? redirectArguments}) {
        capturedRoute = redirectRoute;
        capturedArguments = redirectArguments;
      });
      final coordinator = PostAuthCoordinator(redirectController: spy);

      late BuildContext capturedContext;
      await tester.pumpWidget(_harness(
        pendingActionProvider: pendingActionProvider,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ));

      // The coordinator awaits real timeouts (profile/wallet network calls)
      // that never trigger a widget rebuild, so pumpAndSettle alone would
      // return before they resolve. runAsync lets them actually complete.
      await tester.runAsync(() async {
        await coordinator.complete(
          context: capturedContext,
          origin: AuthOrigin.emailPassword,
          payload: const <String, dynamic>{
            'data': <String, dynamic>{
              'user': <String, dynamic>{'id': 'user-1'},
            },
          },
          // An unrelated redirect the caller happened to pass — the restored
          // pending intent must win over this, route AND args together, not
          // just the route.
          redirectRoute: '/main',
          redirectArguments: const <String, String>{'unrelated': 'value'},
          onStageChanged: (_) {},
        );
      });

      expect(capturedRoute, '/e/event-42');
      expect(capturedArguments, <String, String>{'eventId': 'event-42'});
    },
  );
}
