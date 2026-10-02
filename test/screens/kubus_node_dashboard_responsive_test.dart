import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/availability_operator_provider.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/settings/availability_node_operator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
              create: (_) => WalletProvider(deferInit: true)),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => AvailabilityOperatorProvider()),
          ChangeNotifierProvider(create: (_) => KubusNodeProvider()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AvailabilityNodeOperatorScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('kubus Node dashboard renders at mobile width', (tester) async {
    await pumpDashboard(tester, const Size(390, 844));

    expect(find.text('kubus Node'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kubus Node dashboard renders at desktop width', (tester) async {
    await pumpDashboard(tester, const Size(1440, 900));

    expect(find.text('kubus Node'), findsWidgets);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
