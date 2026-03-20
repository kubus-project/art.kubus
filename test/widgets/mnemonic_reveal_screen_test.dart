import 'dart:collection';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/wallet/mnemonic_reveal_screen.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QueuedSecurityGateProvider extends SecurityGateProvider {
  _QueuedSecurityGateProvider(List<bool> results)
      : _results = Queue<bool>.from(results);

  final Queue<bool> _results;

  @override
  Future<bool> requireSensitiveActionVerification() async {
    if (_results.isEmpty) return true;
    return _results.removeFirst();
  }
}

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider({required this.mnemonic}) : super(deferInit: true);

  final String mnemonic;
  bool markedBackedUp = false;

  @override
  Future<String?> readCachedMnemonic() async => mnemonic;

  @override
  Future<void> markMnemonicBackedUp({String? walletAddress}) async {
    markedBackedUp = true;
  }
}

Widget _buildApp({
  required SecurityGateProvider gate,
  required WalletProvider wallet,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>.value(value: gate),
      ChangeNotifierProvider<WalletProvider>.value(value: wallet),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MnemonicRevealScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic = 'alpha beta gamma delta epsilon zeta eta theta';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'allows reveal and copy when sensitive verification does not block access',
      (tester) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final gate = _QueuedSecurityGateProvider(<bool>[true, true]);
    final wallet = _FakeWalletProvider(mnemonic: mnemonic);

    await tester.pumpWidget(_buildApp(gate: gate, wallet: wallet));
    await tester.pumpAndSettle();

    expect(find.byType(LiquidGlassCard), findsWidgets);
    expect(find.text('alpha'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(clipboardText, mnemonic);
    expect(find.text('Mnemonic copied to clipboard'), findsOneWidget);
  });

  testWidgets('keeps the mnemonic masked when verification fails',
      (tester) async {
    final gate = _QueuedSecurityGateProvider(<bool>[true, false]);
    final wallet = _FakeWalletProvider(mnemonic: mnemonic);

    await tester.pumpWidget(_buildApp(gate: gate, wallet: wallet));
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsNothing);
    expect(find.text('Authentication failed'), findsOneWidget);
  });
}
