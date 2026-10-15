import 'dart:convert';

import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _institutionName = 'Kubus Gallery';

Map<String, Object?> _institutionPayload() => {
      'id': 'inst-1',
      'name': _institutionName,
      'description': 'A gallery for one-title checks.',
      'type': 'gallery',
      'address': 'Main Street',
      'latitude': 46.0511,
      'longitude': 14.5051,
      'contactEmail': 'hello@example.com',
      'website': 'https://example.com',
      'imageUrls': <String>[],
      'stats': {
        'totalVisitors': 0,
        'activeEvents': 0,
        'artworkViews': 0,
        'revenue': 0,
        'visitorGrowth': 0,
        'revenueGrowth': 0,
      },
      'isVerified': true,
      'createdAt': '2026-07-01T10:00:00.000Z',
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

DesktopShellScope _shell(Widget child) => DesktopShellScope(
      pushScreen: (_) {},
      popScreen: () {},
      navigateToRoute: (_) {},
      openNotifications: () {},
      openFunctionsPanel: (_, {Widget? content}) {},
      setFunctionsPanelContent: (_) {},
      closeFunctionsPanel: () {},
      canPop: true,
      child: child,
    );

Future<List<String>> _pump(
  WidgetTester tester, {
  required Size size,
  required Widget child,
}) async {
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(tester, size: size, child: child);
  FlutterError.onError = prior;
  return errors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == '/api/institutions') {
        return _json({
          'success': true,
          'institutions': [_institutionPayload()],
        });
      }
      if (request.url.path == '/api/events') {
        return _json({
          'success': true,
          'data': {'events': <Object>[]},
        });
      }
      return _json({'success': true, 'data': <String, Object?>{}});
    }));
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets('standalone (phone): the institution name is the one title',
      (tester) async {
    final renderErrors = await _pump(
      tester,
      size: const Size(390, 844),
      child: const InstitutionDetailScreen(institutionId: 'inst-1'),
    );
    await tester.pumpAndSettle();
    expect(renderErrors, isEmpty);

    expect(
      find.text(_institutionName),
      findsOneWidget,
      reason: 'the AppBar carries the name; the card does not repeat it',
    );
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets(
      'embedded under a sub-screen with the same title: one title, from the shell',
      (tester) async {
    final renderErrors = await _pump(
      tester,
      size: const Size(1440, 900),
      child: _shell(
        const DesktopSubScreen(
          title: _institutionName,
          child: InstitutionDetailScreen(
            institutionId: 'inst-1',
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderErrors, isEmpty);

    expect(
      find.text(_institutionName),
      findsOneWidget,
      reason:
          'the sub-screen header owns the name; the body does not repeat it',
    );
  });

  testWidgets(
      'embedded under a differently labelled sub-screen: the body keeps the name',
      (tester) async {
    final renderErrors = await _pump(
      tester,
      size: const Size(1440, 900),
      child: _shell(
        const DesktopSubScreen(
          title: 'Institution',
          child: InstitutionDetailScreen(
            institutionId: 'inst-1',
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderErrors, isEmpty);

    expect(
      find.descendant(
        of: find.byType(DesktopSubScreen),
        matching: find.text(_institutionName),
      ),
      findsOneWidget,
      reason: 'no header carries the name, so the body keeps it',
    );
  });
}
