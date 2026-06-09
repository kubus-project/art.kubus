import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHarness({
  required Widget child,
  required double width,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openWalletEntryMenuIfNeeded(WidgetTester tester) async {
    final l10n = AppLocalizationsEn();
    final walletEntryLabels = <String>{
      l10n.authUseWalletInstead,
      l10n.authConnectWalletButton,
    };

    for (final label in walletEntryLabels) {
      final button = find.text(label);
      if (button.evaluate().isNotEmpty) {
        await tester.tap(button.first);
        await tester.pumpAndSettle();
        return;
      }
    }

    final showOtherOptions = find.text(l10n.authShowOtherOptions);
    if (showOtherOptions.evaluate().isNotEmpty) {
      await tester.tap(showOtherOptions.first);
      await tester.pumpAndSettle();
    }

    Finder? revealedWalletEntry;
    for (final label in walletEntryLabels) {
      final button = find.text(label);
      if (button.evaluate().isNotEmpty) {
        revealedWalletEntry = button;
        break;
      }
    }
    expect(revealedWalletEntry, isNotNull);
    await tester.tap(revealedWalletEntry!.first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'sign-in wallet menu shows the three wallet entry options on mobile',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: const SignInScreen(embedded: true),
        width: 500,
      ),
    );
    await tester.pumpAndSettle();

    await openWalletEntryMenuIfNeeded(tester);

    final l10n = AppLocalizationsEn();
    expect(
        find.text(l10n.connectWalletOptionWalletConnectTitle), findsOneWidget);
    expect(find.text(l10n.connectWalletCreateTitle), findsOneWidget);
    expect(find.text(l10n.connectWalletLinkExistingTitle), findsOneWidget);
    expect(find.text(l10n.connectWalletAdvancedBadge), findsNWidgets(2));
  });

  testWidgets(
      'registration wallet menu shows the same wallet entry options on desktop',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: const AuthMethodsPanel(embedded: true),
        width: 1100,
      ),
    );
    await tester.pumpAndSettle();

    await openWalletEntryMenuIfNeeded(tester);

    final l10n = AppLocalizationsEn();
    expect(
        find.text(l10n.connectWalletOptionWalletConnectTitle), findsOneWidget);
    expect(find.text(l10n.connectWalletCreateTitle), findsOneWidget);
    expect(find.text(l10n.connectWalletLinkExistingTitle), findsOneWidget);
    expect(find.text(l10n.connectWalletAdvancedBadge), findsNWidgets(2));
  });
}
