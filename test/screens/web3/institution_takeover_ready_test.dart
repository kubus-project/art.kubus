import 'dart:convert';

import 'package:art_kubus/core/public_entry_navigation.dart';
import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/institution_navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _recordId = '3f2b6c1e-8a40-4c6e-9a39-0b9f4f1a2d77';

Map<String, Object?> _institutionPayload(String id) => {
      'id': id,
      'name': 'Kubus Gallery',
      'description': 'A gallery for takeover checks.',
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

PublicEntityTakeoverProvider _seeded(String id, {String locale = 'en'}) {
  final provider = PublicEntityTakeoverProvider();
  final segment = locale == 'sl' ? 'institucije' : 'institutions';
  provider.seed(
    initialUri: Uri.parse('/$locale/$segment/$id'),
    target: ShareDeepLinkTarget(
      type: ShareEntityType.institution,
      id: id,
      localeCode: locale,
    ),
  );
  return provider;
}

/// Bounded frames: the screen keeps ambient animations running, so a settle
/// that waits for none would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// pumpProductSurface collects render errors through FlutterError.onError; a
/// failing expect() under it hangs the test, so restore it before expecting.
Future<List<String>> _pump(
  WidgetTester tester, {
  required Widget child,
  required PublicEntityTakeoverProvider takeover,
}) async {
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    child: child,
    extraProviders: [
      ChangeNotifierProvider<PublicEntityTakeoverProvider>.value(
          value: takeover),
    ],
  );
  await _settle(tester);
  FlutterError.onError = prior;
  return errors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void serve({required bool found}) {
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == '/api/institutions') {
        return _json({
          'success': true,
          'institutions': found
              ? [_institutionPayload(_recordId)]
              : <Map<String, Object?>>[],
        });
      }
      if (request.url.path == '/api/institutions/$_recordId') {
        return found
            ? _json({'success': true, 'data': _institutionPayload(_recordId)})
            : http.Response('{"success":false}', 404);
      }
      if (request.url.path == '/api/events') {
        return _json({
          'success': true,
          'data': {'events': <Object>[]},
        });
      }
      return _json({'success': true, 'data': <String, Object?>{}});
    }));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
    PublicEntryNavigation.instance.resetForTest();
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    PublicEntryNavigation.instance.resetForTest();
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('a venue record id is recognised and an account-backed id is not', () {
    expect(
        InstitutionNavigation.looksLikeInstitutionRecordId(_recordId), isTrue);
    expect(
        InstitutionNavigation.looksLikeInstitutionRecordId('WalletAccount111'),
        isFalse);
  });

  testWidgets('a loaded institution record tells the takeover it is ready',
      (tester) async {
    serve(found: true);
    final takeover = _seeded(_recordId);
    expect(takeover.target?.type, 'institution');
    expect(takeover.target?.path, '/en/institutions/$_recordId');
    expect(takeover.isReady, isFalse);

    final errors = await _pump(
      tester,
      child: const InstitutionDetailScreen(institutionId: _recordId),
      takeover: takeover,
    );
    expect(errors, isEmpty);

    expect(find.text('Kubus Gallery'), findsWidgets);
    expect(takeover.isReady, isTrue);
  });

  testWidgets('a record that cannot be found never signals readiness',
      (tester) async {
    serve(found: false);
    final takeover = _seeded(_recordId);

    final errors = await _pump(
      tester,
      child: const InstitutionDetailScreen(institutionId: _recordId),
      takeover: takeover,
    );
    expect(errors, isEmpty);

    expect(find.text('Kubus Gallery'), findsNothing);
    expect(takeover.isReady, isFalse);
  });
}
