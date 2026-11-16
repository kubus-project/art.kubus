import 'dart:convert';

import 'package:art_kubus/providers/account_verification_provider.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/screens/web3/institution/event_creator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';
import '../../support/verification_fixtures.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

/// Ownership phrasing the event creator must never use: the backend stores no
/// institution-event relation, so an event cannot "belong to" an institution.
final _ownershipClaim = RegExp(
  r'belong|pripad|institution events|dogodke institucije',
  caseSensitive: false,
);

Map<String, Object?> _institution() => {
      'id': 'inst-x',
      'name': 'Kubus Gallery',
      'description': 'Institution',
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

Future<List<String>> _pump(
  WidgetTester tester, {
  required Locale locale,
  required bool withMembership,
  bool embedded = false,
}) async {
  BackendApiService().setHttpClient(MockClient((request) async {
    final data = request.url.path == '/api/institutions'
        ? {
            'success': true,
            'institutions': [_institution()],
          }
        : {
            'success': true,
            'data': {'events': <Object>[]},
          };
    return http.Response(jsonEncode(data), 200,
        headers: const {'content-type': 'application/json'});
  }));

  final institutions = InstitutionProvider();
  await institutions.initialize();
  final AccountVerificationProvider verification =
      await readyVerificationProvider(
    withMembership ? verificationState(institutionIds: ['inst-x']) : null,
  );

  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    size: embedded ? const Size(1400, 900) : const Size(390, 844),
    locale: locale,
    extraProviders: [
      ChangeNotifierProvider<InstitutionProvider>.value(value: institutions),
      ChangeNotifierProvider<AccountVerificationProvider>.value(
        value: verification,
      ),
    ],
    child: Scaffold(body: EventCreator(embedded: embedded)),
  );
  FlutterError.onError = prior;
  await tester.pump();
  return errors;
}

Iterable<String> _visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .where((t) => t.isNotEmpty);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets(
      'without a membership the creator names a location context, '
      'not an institution owner (EN)', (tester) async {
    final errors = await _pump(
      tester,
      locale: const Locale('en'),
      withMembership: false,
    );
    expect(errors, isEmpty);
    expect(
      find.text('No location context is available for this event yet.'),
      findsOneWidget,
    );
    expect(_visibleTexts(tester).where(_ownershipClaim.hasMatch), isEmpty);
  });

  testWidgets('without a membership the creator is truthful in Slovenian',
      (tester) async {
    final errors = await _pump(
      tester,
      locale: const Locale('sl'),
      withMembership: false,
    );
    expect(errors, isEmpty);
    expect(
      find.text('Za ta dogodek še ni na voljo lokacijskega konteksta.'),
      findsOneWidget,
    );
    expect(_visibleTexts(tester).where(_ownershipClaim.hasMatch), isEmpty);
  });

  testWidgets('a membership offers a location context selector (EN)',
      (tester) async {
    final errors = await _pump(
      tester,
      locale: const Locale('en'),
      withMembership: true,
    );
    expect(errors, isEmpty);
    expect(find.text('Location context'), findsWidgets);
    expect(find.text('Institution'), findsNothing);
    expect(_visibleTexts(tester).where(_ownershipClaim.hasMatch), isEmpty);
  });

  testWidgets(
      'the readiness note says where coordinates come from and that '
      'no institution link is stored (EN)', (tester) async {
    final errors = await _pump(
      tester,
      locale: const Locale('en'),
      withMembership: true,
      embedded: true,
    );
    expect(errors, isEmpty);
    expect(
      find.text(
        'Coordinates are taken from Kubus Gallery. The event is saved under '
        'your account; linking events to institutions is not supported yet.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('will belong'), findsNothing);
    expect(_visibleTexts(tester).where(_ownershipClaim.hasMatch), isEmpty);
  });

  testWidgets('the readiness note is truthful in Slovenian', (tester) async {
    final errors = await _pump(
      tester,
      locale: const Locale('sl'),
      withMembership: true,
      embedded: true,
    );
    expect(errors, isEmpty);
    expect(
      find.text(
        'Koordinate so povzete po ustanovi Kubus Gallery. Dogodek se shrani '
        'pod tvojim računom; povezovanje dogodkov z ustanovami še ni podprto.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('bo pripadal'), findsNothing);
    expect(_visibleTexts(tester).where(_ownershipClaim.hasMatch), isEmpty);
  });
}
