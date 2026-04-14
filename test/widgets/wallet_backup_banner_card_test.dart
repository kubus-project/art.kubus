import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/widgets/wallet_backup_banner_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({
  required WalletProvider walletProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(
        value: walletProvider,
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: WalletBackupBannerCard(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows wallet backup banner when backup is required',
      (tester) async {
    const walletAddress = '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': walletAddress,
      '${PreferenceKeys.walletMnemonicBackupRequiredV1Prefix}:$walletAddress':
          true,
    });

    final walletProvider = WalletProvider(deferInit: true);
    walletProvider.setCurrentWalletAddressForTesting(walletAddress);

    await tester.pumpWidget(_buildHarness(walletProvider: walletProvider));
    await tester.pumpAndSettle();

    expect(find.text('Back up your recovery phrase'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);
  });

  testWidgets('hides wallet backup banner when backup is not required',
      (tester) async {
    const walletAddress = '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': walletAddress,
      '${PreferenceKeys.walletMnemonicBackupRequiredV1Prefix}:$walletAddress':
          false,
    });

    final walletProvider = WalletProvider(deferInit: true);
    walletProvider.setCurrentWalletAddressForTesting(walletAddress);

    await tester.pumpWidget(_buildHarness(walletProvider: walletProvider));
    await tester.pumpAndSettle();

    expect(find.byType(WalletBackupBannerCard), findsOneWidget);
    expect(find.text('Back up your recovery phrase'), findsNothing);
  });

  testWidgets('updates visibility when active wallet changes', (tester) async {
    const walletA = '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF';
    const walletB = '8Jd7n2yQ4pRt6uVwX9zAbCdEfGhIjKlMnOpQrStUvWxY';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': walletA,
      '${PreferenceKeys.walletMnemonicBackupRequiredV1Prefix}:$walletA': false,
      '${PreferenceKeys.walletMnemonicBackupRequiredV1Prefix}:$walletB': true,
    });

    final walletProvider = WalletProvider(deferInit: true);
    walletProvider.setCurrentWalletAddressForTesting(walletA);

    await tester.pumpWidget(_buildHarness(walletProvider: walletProvider));
    await tester.pumpAndSettle();

    expect(find.text('Back up your recovery phrase'), findsNothing);

    walletProvider.setCurrentWalletAddressForTesting(walletB);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Back up your recovery phrase'), findsOneWidget);
  });
}
