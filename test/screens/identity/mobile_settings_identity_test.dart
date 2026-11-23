import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/forced_sign_out_fixture.dart';
import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart';
import 'identity_test_wallets.dart';

/// Mobile Settings already gates its account panel on a live session; this
/// pins it so the consolidation keeps it identical when signed in and neutral
/// after a forced sign-out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  List<SingleChildWidget> providers(String wallet) => [
        ...heldWalletProviders(wallet),
        ChangeNotifierProvider<PlatformProvider>(
            create: (_) => PlatformProvider()),
        ChangeNotifierProvider<SecurityGateProvider>(
            create: (_) => SecurityGateProvider()),
        ChangeNotifierProvider<EmailPreferencesProvider>(
            create: (_) => EmailPreferencesProvider()),
        ChangeNotifierProvider<SupportCenterProvider>(
            create: (_) => SupportCenterProvider(supportEnabled: true)),
      ];

  testWidgets('signed in: the account panel shows the account', (tester) async {
    final prior = FlutterError.onError;
    final owner = qaOwner(isArtist: true);
    await pumpProductSurface(
      tester,
      child: const SettingsScreen(),
      signedInProfile: owner,
      extraProviders: providers(owner.walletAddress),
    );
    FlutterError.onError = prior;
    expect(find.text(owner.displayName), findsWidgets);
  });

  testWidgets('after a forced sign-out: no held account in the panel',
      (tester) async {
    final prior = FlutterError.onError;
    final held = await loadForcedSignOutProfile(tester);
    await pumpProductSurface(
      tester,
      child: const SettingsScreen(),
      profileProvider: held,
      extraProviders: providers(forcedSignOutWallet),
    );
    FlutterError.onError = prior;
    expect(held.isSignedIn, isFalse);
    expect(find.text(forcedSignOutDisplayName), findsNothing);
    expect(find.textContaining('@$forcedSignOutUsername'), findsNothing);
  });
}
