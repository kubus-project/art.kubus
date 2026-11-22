import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/forced_sign_out_fixture.dart';
import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart';
import 'identity_test_wallets.dart';

List<SingleChildWidget> _settingsProviders(String wallet) => [
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

/// L1: the desktop Settings header shows the avatar, display name, bio, counts
/// and role badge of the held account. Without a session it shows the guest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('with a live session the header shows the account',
      (tester) async {
    final prior = FlutterError.onError;
    final owner = qaOwner(isArtist: true);
    await pumpProductSurface(
      tester,
      child: const DesktopSettingsScreen(),
      size: const Size(1600, 1200),
      signedInProfile: owner,
      extraProviders: _settingsProviders(owner.walletAddress),
    );
    FlutterError.onError = prior;
    expect(find.text(owner.displayName), findsWidgets);
    expect(find.text(owner.bio), findsWidgets);
    expect(find.text(l10n.settingsGuestUserName), findsNothing);
  });

  testWidgets(
      'after a forced sign-out the header shows the guest, not the '
      'held account', (tester) async {
    final prior = FlutterError.onError;
    final held = await loadForcedSignOutProfile(tester);
    await pumpProductSurface(
      tester,
      child: const DesktopSettingsScreen(),
      size: const Size(1600, 1200),
      profileProvider: held,
      extraProviders: _settingsProviders(forcedSignOutWallet),
    );
    FlutterError.onError = prior;
    expect(held.isSignedIn, isFalse);
    expect(find.text(forcedSignOutDisplayName), findsNothing);
    expect(find.textContaining('Held bio'), findsNothing);
    expect(find.text(l10n.settingsGuestUserName), findsWidgets);
  });

  test(
      'L2: account toggles read defaults, not the survived prefs mirrors, '
      'without a session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': forcedSignOutWallet,
      'private_profile': true,
      'show_activity_status': false,
    });
    final held = ProfileProvider(
      apiService: WalletProfileApi(forcedSignOutProfileJson()),
    );
    await held.initialize();
    expect(held.isSignedIn, isFalse);
    expect(held.preferences.privacy.toLowerCase(), isNot('private'),
        reason: 'privacy toggle must not show the survived mirror');
    expect(held.preferences.showActivityStatus, isTrue,
        reason: 'activity status toggle must not show the survived mirror');
  });
}
