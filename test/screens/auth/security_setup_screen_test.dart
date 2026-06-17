import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/security_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SecuritySetupWalletProvider extends WalletProvider {
  _SecuritySetupWalletProvider({
    required this.hasPinValue,
    required this.canUseBiometricsValue,
    required this.hasEncryptedWalletBackupValue,
    required this.mnemonicBackupRequiredValue,
  }) : super(deferInit: true);

  bool hasPinValue;
  bool canUseBiometricsValue;
  bool hasEncryptedWalletBackupValue;
  bool mnemonicBackupRequiredValue;

  @override
  Future<bool> hasPin() async => hasPinValue;

  @override
  Future<bool> canUseBiometrics() async => canUseBiometricsValue;

  @override
  bool get hasEncryptedWalletBackup => hasEncryptedWalletBackupValue;

  @override
  Future<bool> isMnemonicBackupRequired({String? walletAddress}) async {
    return mnemonicBackupRequiredValue;
  }
}

Widget _buildSecuritySetupApp(_SecuritySetupWalletProvider walletProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<GlassCapabilitiesProvider>(
        create: (_) => GlassCapabilitiesProvider(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SecuritySetupScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders compact mobile security setup hub', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSecuritySetupApp(
        _SecuritySetupWalletProvider(
          hasPinValue: false,
          canUseBiometricsValue: true,
          hasEncryptedWalletBackupValue: false,
          mnemonicBackupRequiredValue: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('security-setup-mobile-layout')),
      findsOneWidget,
    );
    expect(find.text('Security status'), findsOneWidget);
    expect(find.text('PIN / local lock'), findsOneWidget);
    expect(find.text('Passkey sign-in'), findsOneWidget);
    expect(find.text('Wallet recovery'), findsOneWidget);
    expect(find.text('Backup phrase'), findsOneWidget);
    expect(find.text('Registered passkeys'), findsOneWidget);
    expect(find.text('Secure this device'), findsOneWidget);
  });

  testWidgets('renders two-column desktop security setup hub', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSecuritySetupApp(
        _SecuritySetupWalletProvider(
          hasPinValue: true,
          canUseBiometricsValue: false,
          hasEncryptedWalletBackupValue: true,
          mnemonicBackupRequiredValue: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('security-setup-desktop-layout')),
      findsOneWidget,
    );
    expect(find.text('Security status'), findsOneWidget);
    expect(find.text('Secure this device'), findsOneWidget);
    expect(find.text('PIN / local lock'), findsOneWidget);
    expect(find.text('Wallet recovery'), findsOneWidget);
    expect(find.textContaining('protections active'), findsOneWidget);
  });
}
