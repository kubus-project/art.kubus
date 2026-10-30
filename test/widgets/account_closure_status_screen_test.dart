import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:art_kubus/models/account_closure.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/account_closure_status_screen.dart';
import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/qa_font_loader.dart';

final receipt = AccountClosureReceipt(
    operationId: '00000000-0000-4000-8000-000000000001', statusToken: 'a' * 64);
const proofKey = Key('closure-proof');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(QaFontLoader.ensureLoaded);
  late BackendApiService api;
  setUp(() {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues({});
    api.resetCredentialStoreForTesting(store: AuthCredentialStore(web: true));
    api.setAuthTokenForTesting(null);
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  Future<void> show(WidgetTester tester, String locale,
      {Size size = const Size(360, 900)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = ThemeProvider();
    addTearDown(theme.dispose);
    await tester.pumpWidget(RepaintBoundary(
        key: proofKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountClosureStatusScreen(),
        )));
    await tester.pumpAndSettle();
  }

  for (final locale in ['en', 'sl']) {
    final l10n = locale == 'sl' ? AppLocalizationsSl() : AppLocalizationsEn();
    for (final state in [
      'received',
      'processing',
      'review_required',
      'completed_managed'
    ]) {
      testWidgets(
          '$locale renders confirmed $state after logout without overflow',
          (tester) async {
        await api.saveAccountClosureReceipt(receipt);
        api.setHttpClient(MockClient((request) async {
          expect(request.headers['Authorization'],
              'Bearer ${receipt.statusToken}');
          return http.Response(
              '{"data":{"state":"$state","lawfulRetention":true}}', 200);
        }));
        await show(tester, locale);
        final label = switch (state) {
          'received' => l10n.accountClosureReceived,
          'processing' => l10n.accountClosureProcessing,
          'review_required' => l10n.accountClosureReviewRequired,
          _ => l10n.accountClosureCompletedManaged,
        };
        expect(find.text(label), findsOneWidget);
        expect(find.text(l10n.accountClosureLawfulRetention), findsOneWidget);
        expect(find.text(l10n.accountClosureLimitations), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('missing receipt offers private import without issuing a request',
      (tester) async {
    var requests = 0;
    api.setHttpClient(MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }));
    await show(tester, 'en');
    expect(find.text(AppLocalizationsEn().accountClosurePasteReceipt),
        findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('unavailable status never displays completed', (tester) async {
    await api.saveAccountClosureReceipt(receipt);
    api.setHttpClient(
        MockClient((_) async => http.Response('{"error":"unavailable"}', 503)));
    await show(tester, 'en');
    expect(find.text(AppLocalizationsEn().accountClosureStatusUnavailable),
        findsOneWidget);
    expect(find.text(AppLocalizationsEn().accountClosureCompletedManaged),
        findsNothing);
  });

  for (final size in [const Size(360, 1000), const Size(1200, 900)]) {
    testWidgets('responsive visual proof ${size.width}', (tester) async {
      await api.saveAccountClosureReceipt(receipt);
      api.setHttpClient(MockClient((_) async => http.Response(
          '{"data":{"state":"review_required","lawfulRetention":true}}', 200)));
      await show(tester, 'sl', size: size);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('B03_VISUAL_PROOF')) {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(proofKey));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory(
              'G:/WorkingDATA/art.kubus/output/compliance-completion-20261027/B03-FINAL');
          await directory.create(recursive: true);
          await File(
                  '${directory.path}/flutter-status-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
