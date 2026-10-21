import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/widgets/security_gate_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> hasPinOrThrow() async => true;

  @override
  Future<bool> canUseBiometrics() async => false;
}

const _childKey = ValueKey('app-child');
const _coverKey = ValueKey('security_deciding');

Future<SecurityGateProvider> _pump(
  WidgetTester tester, {
  required bool requirePin,
  required void Function() onChildTap,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'requirePin': requirePin,
    'autoLockSeconds': 60,
  });
  final wallet = _Wallet();
  final gate = SecurityGateProvider(promptCooldown: Duration.zero);
  gate.bindDependencies(
    profileProvider: ProfileProvider(),
    walletProvider: wallet,
    notificationProvider: NotificationProvider(),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<WalletProvider>.value(value: wallet),
        ChangeNotifierProvider<SecurityGateProvider>.value(value: gate),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SecurityGateOverlay(
          child: Center(
            child: GestureDetector(
              key: _childKey,
              onTap: onChildTap,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ),
    ),
  );
  return gate;
}

/// The cover's absorbing pointer blocks the child. Structural check: a hit
/// test cannot be trusted here because the Navigator adds its own absorber.
bool _coverAbsorbs(WidgetTester tester) {
  final absorber = find.descendant(
    of: find.byKey(_coverKey),
    matching: find.byType(AbsorbPointer),
  );
  if (absorber.evaluate().isEmpty) return false;
  return tester.widget<AbsorbPointer>(absorber).absorbing;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('covers the app while the decision is pending and blocks taps',
      (tester) async {
    var taps = 0;
    final gate =
        await _pump(tester, requirePin: true, onChildTap: () => taps++);
    await tester.pump();

    expect(gate.isLockDecisionPending, isTrue);
    expect(gate.isLocked, isFalse);
    expect(find.byKey(_coverKey), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    expect(_coverAbsorbs(tester), isTrue);
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the cover disappears when the gate decides no lock',
      (tester) async {
    var taps = 0;
    final gate =
        await _pump(tester, requirePin: false, onChildTap: () => taps++);
    await gate.initialize();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gate.isLockDecisionPending, isFalse);
    expect(gate.isLocked, isFalse);
    expect(find.byKey(_coverKey), findsNothing);

    expect(_coverAbsorbs(tester), isFalse);
    expect(taps, 0);
  });
}
