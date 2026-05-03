import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/auth_success_handoff_service.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('non-embedded auth success pushes the loading screen route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _buildApp(
        Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('home')),
            );
          },
        ),
      ),
    );

    final service = AuthSuccessHandoffService();
    await service.handle(
      navigator: navigatorKey.currentState!,
      isMounted: () => true,
      screenWidth: 1440,
      payload: const <String, dynamic>{'data': <String, dynamic>{}},
      origin: AuthOrigin.emailPassword,
      embedded: false,
      modalReauth: false,
      requiresWalletBackup: false,
    );

    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
  });
}