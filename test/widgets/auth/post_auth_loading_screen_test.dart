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

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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
}
