import 'package:flutter/services.dart';
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
  _Wallet({required this.pinStoreThrows}) : super(deferInit: true);

  final bool pinStoreThrows;

  /// Mirrors the swallowing variant: an unreadable store reads as "no PIN".
  @override
  Future<bool> hasPin() async => false;

  @override
  Future<bool> hasPinOrThrow() async {
    if (pinStoreThrows) throw StateError('secure storage unavailable');
    return true;
  }

  @override
  Future<bool> canUseBiometrics() async => false;
}

Future<void> _pumpLockedOverlay(
  WidgetTester tester, {
  required _Wallet wallet,
}) async {
  final gate = SecurityGateProvider(promptCooldown: Duration.zero);
  gate.bindDependencies(
    profileProvider: ProfileProvider(),
    walletProvider: wallet,
    notificationProvider: NotificationProvider(),
  );
  await gate.lock(SecurityLockReason.sensitiveAction);
  expect(gate.isLocked, isTrue);

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
        home: const SecurityGateOverlay(child: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The overlay reads the PIN lockout from secure storage as soon as it opens.
/// Without a platform answer that read stays in flight, and the bounded
/// queue timeout in PinAuthService is still armed when the test ends. An empty
/// store answers immediately, so no timer outlives the test.
const MethodChannel _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  testWidgets('an unreadable PIN store still offers the PIN field',
      (tester) async {
    await _pumpLockedOverlay(
      tester,
      wallet: _Wallet(pinStoreThrows: true),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a readable store with a PIN shows the PIN field',
      (tester) async {
    await _pumpLockedOverlay(
      tester,
      wallet: _Wallet(pinStoreThrows: false),
    );

    expect(find.byType(TextField), findsOneWidget);
  });
}
