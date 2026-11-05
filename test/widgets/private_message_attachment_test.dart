import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import '../support/qa_font_loader.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/messaging/private_message_attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const route =
    '/api/messages/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/messages/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/attachments/cccccccc-cccc-4ccc-8ccc-cccccccccccc';
void main() {
  for (final width in [390.0, 1280.0]) {
    for (final locale in ['en', 'sl']) {
      for (final dark in [false, true]) {
        testWidgets(
            'authenticated attachment $width $locale dark=$dark clears on account change',
            (tester) async {
          await tester.runAsync(QaFontLoader.ensureLoaded);
          SharedPreferences.setMockInitialValues({});
          final theme = ThemeProvider();
          addTearDown(theme.dispose);
          final api = BackendApiService();
          api.setAuthTokenForTesting('synthetic-only');
          api.setHttpClient(MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer synthetic-only');
            return http.Response.bytes(
                base64Decode(
                    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5q5nQAAAAASUVORK5CYII='),
                200);
          }));
          tester.view.resetPhysicalSize();
          tester.view.physicalSize = Size(width, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: dark ? theme.darkTheme : theme.lightTheme,
            home: RepaintBoundary(
                key: boundaryKey,
                child: const Scaffold(
                    body: Center(
                        child: PrivateMessageAttachment(
                  url: route,
                  filename: 'synthetic-private-image.png',
                  mimeType: 'image/png',
                )))),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(Image), findsOneWidget);
          expect(find.byType(TextButton), findsOneWidget);
          final evidence = Platform.environment['KUBUS_TEST_EVIDENCE_DIR'];
          if (evidence != null) {
            await tester.runAsync(() async {
              final boundary = boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final data =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '$evidence/attachment-${width.toInt()}-$locale-${dark ? 'dark' : 'light'}.png')
                  .writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await AccountIdentity.notifyChanged();
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsNothing);
          expect(find.byType(TextButton), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          api.setAuthTokenForTesting(null);
        });
      }
    }
  }
}
