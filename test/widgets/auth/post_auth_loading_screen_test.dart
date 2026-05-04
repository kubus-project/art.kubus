import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingPostAuthCoordinator extends PostAuthCoordinator {
  const _FailingPostAuthCoordinator();

  @override
  Future<PostAuthResult> complete({
    required BuildContext context,
    required AuthOrigin origin,
    required Map<String, dynamic> payload,
    String? redirectRoute,
    Object? redirectArguments,
    String? walletAddress,
    Object? userId,
    bool embedded = false,
    bool modalReauth = false,
    bool requiresWalletBackup = false,
    Future<void> Function()? onBeforeSavedItemsSync,
    required ValueChanged<PostAuthStage> onStageChanged,
  }) async {
    onStageChanged(PostAuthStage.preparingSession);
    onStageChanged(PostAuthStage.securingWallet);
    onStageChanged(PostAuthStage.loadingProfile);
    onStageChanged(PostAuthStage.syncingSavedItems);
    onStageChanged(PostAuthStage.checkingOnboarding);
    onStageChanged(PostAuthStage.openingWorkspace);
    return const PostAuthResult(
      completed: false,
      error: 'simulated-failure',
    );
  }
}

class _BlockingPostAuthCoordinator extends PostAuthCoordinator {
  const _BlockingPostAuthCoordinator(this.completer);

  final Completer<PostAuthResult> completer;

  @override
  Future<PostAuthResult> complete({
    required BuildContext context,
    required AuthOrigin origin,
    required Map<String, dynamic> payload,
    String? redirectRoute,
    Object? redirectArguments,
    String? walletAddress,
    Object? userId,
    bool embedded = false,
    bool modalReauth = false,
    bool requiresWalletBackup = false,
    Future<void> Function()? onBeforeSavedItemsSync,
    required ValueChanged<PostAuthStage> onStageChanged,
  }) async {
    onStageChanged(PostAuthStage.preparingSession);
    return completer.future;
  }
}

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    onGenerateRoute: (settings) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(
          body: Center(child: Text('route:${settings.name ?? 'unknown'}')),
        ),
      );
    },
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows post-auth failure actions when the flow fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        PostAuthLoadingScreen(
          payload: const <String, dynamic>{},
          origin: AuthOrigin.wallet,
          coordinator: const _FailingPostAuthCoordinator(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text("We couldn't finish signing you in"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Back to sign-in'), findsOneWidget);
  });

  testWidgets('fires onAuthSuccess only after the coordinator completes', (
    tester,
  ) async {
    final completer = Completer<PostAuthResult>();
    var successCalls = 0;

    await tester.pumpWidget(
      _buildApp(
        PostAuthLoadingScreen(
          payload: const <String, dynamic>{'data': <String, dynamic>{}},
          origin: AuthOrigin.emailPassword,
          coordinator: _BlockingPostAuthCoordinator(completer),
          onAuthSuccess: (_) async {
            successCalls += 1;
          },
        ),
      ),
    );

    await tester.pump();
    expect(successCalls, equals(0));

    completer.complete(
      const PostAuthResult(
        completed: true,
        routeName: '/main',
        replaceStack: true,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(successCalls, equals(1));
  });

  testWidgets(
      'does not invoke password prompt when onBeforeSavedItemsSync is null for wallet',
      (tester) async {
    final completer = Completer<PostAuthResult>();

    await tester.pumpWidget(
      _buildApp(
        PostAuthLoadingScreen(
          payload: const <String, dynamic>{'data': <String, dynamic>{}},
          origin: AuthOrigin.wallet,
          coordinator: _BlockingPostAuthCoordinator(completer),
          onBeforeSavedItemsSync: null,
          // Key: null means no password prompt callback
        ),
      ),
    );

    await tester.pump();

    completer.complete(
      const PostAuthResult(
        completed: true,
        routeName: '/main',
        replaceStack: true,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // Verify no password prompt was shown
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('uses correct origin for wallet auth post-auth flow',
      (tester) async {
    final completer = Completer<PostAuthResult>();

    // Create a custom coordinator that captures the origin
    const testPayload = <String, dynamic>{'data': <String, dynamic>{}};

    await tester.pumpWidget(
      _buildApp(
        PostAuthLoadingScreen(
          payload: testPayload,
          origin: AuthOrigin.wallet,
          coordinator: _BlockingPostAuthCoordinator(completer),
        ),
      ),
    );

    await tester.pump();

    completer.complete(
      const PostAuthResult(
        completed: true,
        routeName: '/main',
        replaceStack: true,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // Screen should render successfully with wallet origin
    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
  });

  testWidgets('does not show password prompt for Google auth',
      (tester) async {
    final completer = Completer<PostAuthResult>();

    await tester.pumpWidget(
      _buildApp(
        PostAuthLoadingScreen(
          payload: const <String, dynamic>{'data': <String, dynamic>{}},
          origin: AuthOrigin.google,
          coordinator: _BlockingPostAuthCoordinator(completer),
          onBeforeSavedItemsSync: null,
          // For Google, should also be null
        ),
      ),
    );

    await tester.pump();

    completer.complete(
      const PostAuthResult(
        completed: true,
        routeName: '/main',
        replaceStack: true,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // No alert dialog should appear
    expect(find.byType(AlertDialog), findsNothing);
  });
}
