import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_connect_wallet_screen.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the desktop connect-wallet composition.
///
/// The embedded [ConnectWallet] uses Expanded/SizedBox.expand internally, so the
/// desktop wrapper must always hand it a bounded height — both in the wide
/// two-column branch and the narrow single-column branch. These tests pump the
/// screen across the supported desktop/tablet widths and assert no layout
/// exception (overflow / unbounded-height) is thrown.
Widget _harness() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<WalletProvider>.value(
        value: WalletProvider(deferInit: true),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const DesktopConnectWalletScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // 768 / 840 hit the narrow single-column branch (< 880); 1024 / 1280 hit the
  // wide two-column branch (>= 880).
  for (final width in <double>[768, 840, 1024, 1280]) {
    testWidgets('renders without layout overflow at ${width.toInt()}px width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ConnectWallet), findsOneWidget);
    });
  }
}
