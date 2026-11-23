import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/utils/home/home_quick_action_executor.dart';
import 'package:art_kubus/utils/home/home_quick_action_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/account_session_fixture.dart';
import '../../support/forced_sign_out_fixture.dart';
import '../../support/product_v5_qa_fixtures.dart';

/// L12: the desktop "Profile" quick action pushed the owner's ProfileScreen
/// with whatever profile was held. It is a "your profile" link, so it opens
/// only with a live session, by the same capability rule as the mobile action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(AccountSessionFixture.end);

  Future<List<Widget>> runProfileAction(
    WidgetTester tester,
    ProfileProvider profile,
  ) async {
    final pushed = <Widget>[];
    late BuildContext captured;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
          ChangeNotifierProvider<WalletProvider>(
            create: (_) => WalletProvider(deferInit: true),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DesktopShellScope(
              pushScreen: pushed.add,
              popScreen: () {},
              navigateToRoute: (_) {},
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: false,
              child: Builder(builder: (context) {
                captured = context;
                return const SizedBox();
              }),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => HomeQuickActionExecutor.execute(
        captured,
        'profile',
        source: HomeQuickActionSurface.desktopHome,
      ),
    );
    await tester.pump();
    return pushed;
  }

  testWidgets('with a live session the Profile quick action opens the profile',
      (tester) async {
    AccountSessionFixture.start(
      accountId: qaOwner().userId!,
      wallet: qaOwner().walletAddress,
    );
    final profile = ProfileProvider()..setCurrentUser(qaOwner());
    expect(profile.isSignedIn, isTrue);

    final pushed = await runProfileAction(tester, profile);

    expect(pushed, hasLength(1));
  });

  testWidgets('after a forced sign-out the Profile quick action opens nothing',
      (tester) async {
    final held = await loadForcedSignOutProfile(tester);
    expect(held.isSignedIn, isFalse);

    final pushed = await runProfileAction(tester, held);

    expect(pushed, isEmpty);
  });
}
