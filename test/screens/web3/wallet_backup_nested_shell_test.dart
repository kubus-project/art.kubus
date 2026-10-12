import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/web3/wallet/mnemonic_reveal_screen.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_backup_protection_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/security/security_hub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

  final String walletAddress = '7YgP1dXwz9exampleWallet111111111111111111';

  @override
  String? get currentWalletAddress => walletAddress;

  @override
  bool get hasLocalSigner => true;

  @override
  bool get hasSigner => true;

  @override
  WalletAuthoritySnapshot get authority => WalletAuthoritySnapshot(
        state: WalletAuthorityState.localSignerReady,
        signerSource: WalletSignerSource.local,
        accountSignedIn: true,
        signInMethod: AuthSignInMethod.email,
        accountEmail: 'tester@example.com',
        walletAddress: walletAddress,
        hasLocalSigner: true,
        hasExternalSigner: false,
        externalWalletConnected: false,
        externalWalletName: null,
        hasEncryptedBackup: false,
        encryptedBackupStatusKnown: true,
        hasPasskeyProtection: false,
        mnemonicBackupRequired: true,
        recoveryNeeded: false,
      );

  @override
  Future<bool> hasPin() async => false;

  @override
  Future<bool> canUseBiometrics() async => false;

  @override
  Future<bool> isMnemonicBackupRequired({String? walletAddress}) async => true;

  // Deliberately fake: never a real recovery phrase.
  @override
  Future<String?> readCachedMnemonic() async =>
      'test words only not a real phrase at all';
}

/// A stand-in for the desktop shell: a permanent sidebar plus the content
/// column that shows only the top of the pushed-screen stack, as the real
/// shell does.
class _ShellHost extends StatefulWidget {
  const _ShellHost({required this.onStateChanged});

  final VoidCallback onStateChanged;

  @override
  State<_ShellHost> createState() => _ShellHostState();
}

class _ShellHostState extends State<_ShellHost> {
  final List<Widget> stack = <Widget>[];

  @override
  Widget build(BuildContext context) {
    return DesktopShellScope(
      pushScreen: (screen) => setState(() => stack.add(screen)),
      popScreen: () => setState(() => stack.removeLast()),
      navigateToRoute: (_) {},
      openNotifications: () {},
      openFunctionsPanel: (_, {content}) {},
      setFunctionsPanelContent: (_) {},
      closeFunctionsPanel: () {},
      canPop: stack.isNotEmpty,
      child: Row(
        children: [
          const SizedBox(
            key: ValueKey('shell-sidebar'),
            width: 80,
            child: Text('sidebar'),
          ),
          Expanded(
            child: stack.isNotEmpty
                ? stack.last
                : Builder(
                    builder: (context) => TextButton(
                      onPressed: () => openWalletBackupProtection(
                        context,
                        onBackupStateChanged: () async =>
                            widget.onStateChanged(),
                      ),
                      child: const Text('open backup'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _app(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<GlassCapabilitiesProvider>(
          create: (_) => GlassCapabilitiesProvider(),
        ),
        ChangeNotifierProvider<WalletProvider>.value(value: _Wallet()),
        ChangeNotifierProvider<SecurityGateProvider>(
          create: (_) => SecurityGateProvider(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
      'Show phrase stays inside the desktop shell and Back returns to backup',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    var backupStateChanges = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: _ShellHost(onStateChanged: () => backupStateChanges++),
        ),
      ),
    );

    // 1. Backup protection opens in the shell.
    await tester.tap(find.text('open backup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SecurityHubView), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-sidebar')), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse, reason: 'no full-screen route yet');

    // 2. Show phrase: still inside the shell, no route pushed.
    await tester.ensureVisible(find.text('Show phrase'));
    await tester.pump();
    await tester.tap(find.text('Show phrase'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MnemonicRevealScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-sidebar')), findsOneWidget,
        reason: 'the sidebar must survive the nested recovery step');
    expect(navigator.canPop(), isFalse,
        reason: 'the phrase must not open as a full-screen route');

    // 3. Closing returns to the backup screen, still in the shell, and
    //    reports that the backup state may have changed.
    final reveal = tester.widget<MnemonicRevealScreen>(
      find.byType(MnemonicRevealScreen),
    );
    reveal.onShellExit!(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MnemonicRevealScreen), findsNothing);
    expect(find.byType(SecurityHubView), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-sidebar')), findsOneWidget);
    expect(backupStateChanges, 1);
  });

  testWidgets('without a shell the phrase is still an ordinary route',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(const WalletBackupProtectionScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Show phrase'));
    await tester.pump();
    await tester.tap(find.text('Show phrase'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MnemonicRevealScreen), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);
  });
}
