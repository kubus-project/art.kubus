import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/gallery_presentation.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/detail/gallery_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const host = '11111111-1111-4111-8111-111111111111';
const allowed = '22222222-2222-4222-8222-222222222222';
const denied = '33333333-3333-4333-8333-333333333333';

http.Response _json(Map<String, dynamic> data, [int status = 200]) {
  return http.Response(jsonEncode(data), status, headers: {
    'content-type': 'application/json',
    'cache-control': 'private, no-store'
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;

  setUp(() {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues({});
    api.setAuthTokenForTesting(null);
  });
  tearDown(() => api.setHttpClient(http.Client()));

  Future<void> render(
    WidgetTester tester, {
    required Size extent,
    required Brightness brightness,
    required Locale locale,
  }) async {
    tester.view.physicalSize = extent;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GalleryHostScope(
              type: GalleryHostType.profile,
              hostId: host,
              builder: (_) => const GalleryPanel(fallback: Text('Legacy work')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final cases = [
    (
      GalleryMode.wall,
      const Size(320, 720),
      Brightness.light,
      const Locale('en')
    ),
    (
      GalleryMode.rooms,
      const Size(393, 844),
      Brightness.dark,
      const Locale('sl')
    ),
    (
      GalleryMode.field,
      const Size(1440, 900),
      Brightness.dark,
      const Locale('en')
    ),
  ];
  for (final (mode, size, brightness, locale) in cases) {
    testWidgets('${mode.name} renders public content without overflow',
        (tester) async {
      final paths = <String>[];
      api.setHttpClient(MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains('authorization')));
        if (request.url.path.endsWith('/gallery')) {
          return _json({
            'success': true,
            'data': {
              'source': 'postgresql',
              'publishedRevision': 4,
              'layout': GalleryLayout(
                mode: mode,
                artworkOrder: const [allowed, denied],
                artworkSizes: const {},
                leadArtworkId: allowed,
                sectionOrder: const [
                  'identity',
                  'work',
                  'stats',
                  'activity',
                  'recognition',
                  'publicArt'
                ],
                hiddenSections: const [],
              ).toJson(),
              'items': [
                {'type': 'artwork', 'id': allowed},
                {'type': 'artwork', 'id': denied},
              ],
            },
          });
        }
        final id = request.url.pathSegments.last;
        expect(request.url.queryParameters['currentMedia'], 'true');
        return _json({
          'success': true,
          'source': 'postgresql',
          'mode': 'current-media',
          'current': true,
          'publicMediaAllowed': id == allowed,
          'data': {
            'id': id,
            'title': id == allowed
                ? 'An intentionally long artwork title for narrow screens'
                : 'Held artwork',
            'artist': 'Synthetic artist',
            'description': 'Documentation for the gallery.',
            'latitude': 46.0,
            'longitude': 14.0,
          },
        });
      }));
      await render(tester,
          extent: size, brightness: brightness, locale: locale);
      expect(find.textContaining('An intentionally long artwork title'),
          findsOneWidget);
      expect(find.text('Held artwork'), findsNothing);
      expect(find.text('Legacy work'), findsNothing);
      expect(find.byType(GalleryCurateButton), findsNothing);
      expect(paths.where((path) => path.endsWith('/draft')), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('current host denial never falls back to legacy artwork',
      (tester) async {
    api.setHttpClient(MockClient((_) async => _json({
          'success': false,
          'errorCode': 'GALLERY_NOT_FOUND',
        }, 404)));
    await render(
      tester,
      extent: const Size(320, 720),
      brightness: Brightness.light,
      locale: const Locale('en'),
    );
    expect(find.text('Legacy work'), findsNothing);
    expect(find.text('Gallery unavailable.'), findsOneWidget);
  });
}
