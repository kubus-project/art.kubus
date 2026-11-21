import 'dart:convert';

import 'package:art_kubus/screens/events/event_detail_screen.dart';
import 'package:art_kubus/screens/events/exhibition_detail_screen.dart';
import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/public_entity_load_outcome.dart';
import 'package:art_kubus/widgets/unavailable_entity_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

const _missing = '00000000-0000-4000-8000-000000000000';

/// Every route answers [status]; a 404 carries the API's own JSON body.
void _answerEverythingWith(int status) {
  BackendApiService().setHttpClient(MockClient((request) async {
    if (request.url.path == '/health' ||
        request.url.path.startsWith('/health/')) {
      return http.Response('{}', 200);
    }
    return http.Response(
      jsonEncode({'success': false, 'error': 'not available'}),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }));
}

/// Each BackendApiService call chains several 800 ms secure-storage timeouts in
/// the fake-async zone; the window must cover all of them.
Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 850));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('only a 404 or 410 answer is "not found"', () {
    expect(isEntityNotFoundError(Exception('Request failed: 404')), isTrue);
    expect(isEntityNotFoundError(Exception('Request failed: 410')), isTrue);
    expect(
      isEntityNotFoundError(
          const BackendApiRequestException(statusCode: 404, path: '/x')),
      isTrue,
    );
    expect(isEntityNotFoundError(Exception('Request failed: 500')), isFalse);
    expect(isEntityNotFoundError(Exception('Request failed: 429')), isFalse);
    expect(isEntityNotFoundError(Exception('Failed host lookup')), isFalse);
  });

  group('D4 a missing entity is not a connection error', () {
    testWidgets('exhibition deep link: 404 says it is gone', (tester) async {
      _answerEverythingWith(404);
      await pumpProductSurface(tester,
          child: const ExhibitionDetailScreen(exhibitionId: _missing),
          settle: Duration.zero);
      await _settleNetwork(tester);

      expect(find.byType(UnavailableEntityScaffold), findsOneWidget);
      expect(find.textContaining('removed or made private'), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsNothing);
    });

    testWidgets('exhibition deep link: a server error stays a load failure',
        (tester) async {
      _answerEverythingWith(500);
      await pumpProductSurface(tester,
          child: const ExhibitionDetailScreen(exhibitionId: _missing),
          settle: Duration.zero);
      await _settleNetwork(tester);

      expect(find.byType(UnavailableEntityScaffold), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('removed'), findsNothing);
    });

    testWidgets('event deep link: 404 says it is gone', (tester) async {
      _answerEverythingWith(404);
      await pumpProductSurface(tester,
          child: const EventDetailScreen(eventId: _missing),
          settle: Duration.zero);
      await _settleNetwork(tester);

      expect(find.byType(UnavailableEntityScaffold), findsOneWidget);
      expect(find.textContaining('removed or made private'), findsOneWidget);
    });

    testWidgets('institution deep link: 404 says not found', (tester) async {
      _answerEverythingWith(404);
      await pumpProductSurface(tester,
          child: const InstitutionDetailScreen(institutionId: _missing),
          settle: Duration.zero);
      await _settleNetwork(tester);

      expect(find.text('Institution not found'), findsOneWidget);
      expect(find.text('Unable to load institution'), findsNothing);
    });

    testWidgets('institution deep link: a server error is a load error',
        (tester) async {
      _answerEverythingWith(500);
      await pumpProductSurface(tester,
          child: const InstitutionDetailScreen(institutionId: _missing),
          settle: Duration.zero);
      await _settleNetwork(tester);

      // The institution may exist: a failed lookup must not claim it does not.
      expect(find.text('Unable to load institution'), findsOneWidget);
      expect(find.text('Institution not found'), findsNothing);
    });
  });
}
