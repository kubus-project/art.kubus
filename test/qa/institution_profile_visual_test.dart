import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/profile_image_http_fixture.dart';
import '../support/qa_font_loader.dart';

const _testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture synthetic institution profile across breakpoints',
      (tester) async {
    final output = Platform.environment['KUBUS_INSTITUTION_VISUAL_QA'];
    if (output == null || output.isEmpty) {
      markTestSkipped('visual output directory not set');
      return;
    }
    Directory(output).createSync(recursive: true);
    await tester.runAsync(QaFontLoader.ensureLoaded);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_testToken);
    final payload = <String, Object?>{
      'id': 'inst-visual',
      'name': 'Synthetic Museum of Cultural Heritage',
      'description':
          'This synthetic institution profile is used to inspect the layout of a long description. It presents a collection of cultural heritage and visual art through exhibitions, research and public programmes. Visitors can explore the permanent collection and changing displays, and the profile contains separate cover and institutional imagery for this layout check.',
      'type': 'museum',
      'address': 'Prešernova cesta 24, 1000 Ljubljana',
      'latitude': 46.05,
      'longitude': 14.5,
      'contactEmail': '',
      'website': 'https://example.test',
      'coverImageUrl': 'https://profile-fixture.invalid/wide.png',
      'logoUrl': 'https://profile-fixture.invalid/tall.png',
      'coverAttribution': {
        'credit': 'Synthetic cover photographer',
        'sourceUrl': 'https://example.test/cover',
        'licenseUrl': 'https://example.test/cover-license',
      },
      'logoAttribution': {
        'credit': 'Synthetic institution archive',
        'sourceUrl': 'https://example.test/logo',
        'licenseUrl': 'https://example.test/logo-license',
      },
      'disciplines': [
        {'code': 'painting', 'labelEn': 'Painting', 'labelSl': 'Slikarstvo'},
        {
          'code': 'cultural_heritage',
          'labelEn': 'Cultural heritage',
          'labelSl': 'Kulturna dediščina'
        }
      ],
      'stats': {
        'totalVisitors': 0,
        'activeEvents': 0,
        'artworkViews': 0,
        'revenue': 0,
        'visitorGrowth': 0,
        'revenueGrowth': 0
      },
      'isVerified': false,
      'createdAt': '2026-07-01T10:00:00.000Z',
    };
    BackendApiService().setHttpClient(MockClient((request) async {
      final data = request.url.path == '/api/institutions'
          ? {
              'success': true,
              'institutions': [payload]
            }
          : {
              'success': true,
              'data': {'events': <Object>[]}
            };
      return http.Response(jsonEncode(data), 200,
          headers: {'content-type': 'application/json'});
    }));
    final fixture = ProfileImageHttpFixture();
    await tester.runAsync(fixture.prepare);
    final previous = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => fixture.createHttpClient(null);
    try {
      for (final scene in [
        (name: 'phone', size: const Size(390, 844)),
        (name: 'tablet', size: const Size(800, 1100)),
        (name: 'desktop', size: const Size(1440, 900))
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final originalOnError = FlutterError.onError;
        final errors = await pumpProductSurface(tester,
            size: scene.size,
            child: const InstitutionDetailScreen(institutionId: 'inst-visual'));
        FlutterError.onError = originalOnError;
        await tester.pump();
        for (final element in find.byType(Image).evaluate()) {
          final widget = element.widget as Image;
          await tester.runAsync(() => precacheImage(widget.image, element));
        }
        await tester.pump();
        expect(errors, isEmpty);
        expect(find.text('Painting'), findsOneWidget);
        expect(find.textContaining('Synthetic cover photographer'),
            findsOneWidget);
        expect(find.textContaining('Synthetic institution archive'),
            findsOneWidget);
        expect(find.byKey(const ValueKey('institution-open-on-map')),
            findsOneWidget);
        final bytes = await tester.runAsync(() async {
          final root = tester.binding.rootElement!.renderObject!;
          final layer = root.debugLayer! as OffsetLayer;
          final image = await layer.toImage(root.paintBounds);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        File('$output/institution-${scene.name}.png').writeAsBytesSync(bytes!);
      }
    } finally {
      debugNetworkImageHttpClientProvider = previous;
      BackendApiService().setAuthTokenForTesting(null);
      BackendApiService().setHttpClient(createPlatformHttpClient());
    }
  });
}
