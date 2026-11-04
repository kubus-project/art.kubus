import 'dart:convert';

import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:art_kubus/widgets/profile/profile_cover_field.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

// The shared ProfileIdentityHero owns the cover; the institution screen does
// not key its own cover widget.
const _coverKey = ValueKey('profile-identity-hero-cover');
const _avatarKey = ValueKey('institution-profile-image');
const _mapKey = ValueKey('institution-open-on-map');

Map<String, Object?> _payload({
  String type = 'museum',
  Object? kind = 'museum',
  String description = 'A synthetic profile for layout checks.',
  String address = 'Main Street 1, 1000 Ljubljana',
  double latitude = 46.0511,
  double longitude = 14.5051,
  String website = 'https://example.test',
  String? coverImageUrl,
  String? logoUrl,
  Map<String, Object?>? coverAttribution,
  Map<String, Object?>? logoAttribution,
  Map<String, Object?>? visitorAccess,
  int activeEvents = 0,
}) {
  return {
    'id': 'inst-layout',
    'name': 'Layout Museum',
    'description': description,
    'type': type,
    if (kind != null) 'kind': kind,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'contactEmail': '',
    'website': website,
    'disciplines': [
      {'code': 'painting', 'labelEn': 'Painting', 'labelSl': 'Slikarstvo'},
      {
        'code': 'cultural_heritage',
        'labelEn': 'Cultural heritage',
        'labelSl': 'Kulturna dediščina',
      },
    ],
    if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    if (logoUrl != null) 'logoUrl': logoUrl,
    if (coverAttribution != null) 'coverAttribution': coverAttribution,
    if (logoAttribution != null) 'logoAttribution': logoAttribution,
    if (visitorAccess != null) 'visitorAccess': visitorAccess,
    'stats': {
      'totalVisitors': 0,
      'activeEvents': activeEvents,
      'artworkViews': 0,
      'revenue': 0,
      'visitorGrowth': 0,
      'revenueGrowth': 0,
    },
    'isVerified': false,
    'createdAt': '2026-07-01T10:00:00.000Z',
  };
}

void _serve(Map<String, Object?> institution) {
  BackendApiService().setHttpClient(MockClient((request) async {
    final data = request.url.path == '/api/institutions'
        ? {
            'success': true,
            'institutions': [institution],
          }
        : {
            'success': true,
            'data': {'events': <Object>[]},
          };
    return http.Response(jsonEncode(data), 200,
        headers: const {'content-type': 'application/json'});
  }));
}

Future<List<String>> _pump(
  WidgetTester tester, {
  required Map<String, Object?> institution,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
}) async {
  _serve(institution);
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    size: size,
    locale: locale,
    child: const InstitutionDetailScreen(institutionId: 'inst-layout'),
  );
  FlutterError.onError = prior;
  await tester.pump();
  return errors;
}

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

  testWidgets('kind chip shows a localized English label, not the raw code',
      (tester) async {
    final errors = await _pump(tester, institution: _payload());
    expect(errors, isEmpty);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsNothing);
  });

  testWidgets('kind chip shows the Slovene label in sl', (tester) async {
    final errors = await _pump(
      tester,
      institution: _payload(kind: 'arts_centre'),
      locale: const Locale('sl'),
    );
    expect(errors, isEmpty);
    expect(find.text('Umetniški center'), findsOneWidget);
    expect(find.text('arts_centre'), findsNothing);
  });

  testWidgets('every kind code has a label, including other', (tester) async {
    for (final entry in {
      'gallery': 'Gallery',
      'exhibition_space': 'Exhibition space',
      'cultural_centre': 'Cultural centre',
      'other': 'Other venue',
    }.entries) {
      final errors = await _pump(
        tester,
        institution: _payload(kind: entry.key),
      );
      expect(errors, isEmpty, reason: entry.key);
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('payloads without kind fall back to the legacy type guess',
      (tester) async {
    final errors = await _pump(
      tester,
      institution: _payload(type: 'gallery', kind: null),
    );
    expect(errors, isEmpty);
    expect(find.text('Gallery'), findsOneWidget);
  });

  testWidgets('credit line names author, licence and source as links',
      (tester) async {
    final handle = tester.ensureSemantics();
    final errors = await _pump(
      tester,
      institution: _payload(
        coverImageUrl: 'https://example.test/cover.jpg',
        coverAttribution: {
          'credit': 'Synthetic photographer',
          'sourceUrl': 'https://example.test/source',
          'licenseUrl': 'https://creativecommons.org/licenses/by-sa/4.0/',
        },
      ),
    );
    expect(errors, isEmpty);
    expect(find.text('Cover photo: Synthetic photographer'), findsOneWidget);
    expect(find.text('CC BY-SA 4.0'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Photo licence CC BY-SA 4.0, opens in browser'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Photo source, opens in browser'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('institution-image-credits')),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('credit without a known licence URL still offers a licence link',
      (tester) async {
    final errors = await _pump(
      tester,
      institution: _payload(
        coverImageUrl: 'https://example.test/cover.jpg',
        coverAttribution: {
          'credit': 'Archive',
          'licenseUrl': 'https://example.test/license',
        },
      ),
    );
    expect(errors, isEmpty);
    expect(find.text('Cover photo: Archive'), findsOneWidget);
    expect(find.text('Licence'), findsOneWidget);
    expect(find.text('Source'), findsNothing);
  });

  testWidgets('profile image is a 88 dp avatar that overlaps the cover edge',
      (tester) async {
    final errors = await _pump(
      tester,
      institution: _payload(
        coverImageUrl: 'https://example.test/cover.jpg',
        logoUrl: 'https://example.test/logo.jpg',
      ),
    );
    expect(errors, isEmpty);
    final avatar = tester.getRect(find.byKey(_avatarKey));
    final cover = tester.getRect(find.byKey(_coverKey));
    // The hero's avatar is the 42 dp radius mark, bare: no frame or padding.
    expect(avatar.size, const Size(84, 84));
    // The shared hero lifts the identity row by plateOverlap into the cover,
    // so the avatar's top sits that far below the cover top and overlaps the
    // cover's lower edge.
    expect(
      avatar.top - cover.top,
      ProfileIdentityHero.coverHeightWithImage -
          ProfileIdentityHero.plateOverlap,
    );
    expect(avatar.top, lessThan(cover.bottom));
    // The avatar mounts its logo as a plain network image, cropped to cover.
    final image = tester.widget<Image>(find.descendant(
      of: find.byKey(_avatarKey),
      matching: find.byType(Image),
    ));
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('a logo identical to the cover is not repeated as an avatar',
      (tester) async {
    final errors = await _pump(
      tester,
      institution: _payload(
        coverImageUrl: 'https://example.test/same.jpg',
        logoUrl: 'https://example.test/same.jpg',
      ),
    );
    expect(errors, isEmpty);
    // The avatar slot stays for the identity row; it carries no second copy
    // of the cover file, so it falls back to the neutral mark.
    final avatar = tester.widget<AvatarWidget>(find.byKey(_avatarKey));
    expect(avatar.avatarUrl, isNull);
  });

  testWidgets('without images the hero falls back without a broken icon',
      (tester) async {
    final errors = await _pump(tester, institution: _payload());
    expect(errors, isEmpty);
    expect(find.byKey(_coverKey), findsOneWidget);
    final avatar = tester.widget<AvatarWidget>(find.byKey(_avatarKey));
    expect(avatar.avatarUrl, isNull);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    // With no approved cover the hero paints its authored role field, not an
    // icon, so the cover is a designed surface rather than a broken image.
    expect(find.byType(ProfileCoverField), findsOneWidget);
    expect(
        find.byKey(const ValueKey('institution-image-credits')), findsNothing);
  });

  testWidgets(
      'approved visitor information renders hours, admission and booking',
      (tester) async {
    final errors = await _pump(
      tester,
      institution: _payload(visitorAccess: {
        'status': 'approved',
        'sourceUrl': 'https://example.test/visit',
        'verifiedAt': '2026-11-02T12:00:00.000Z',
        'visitorInfo': {
          'openingHoursText': 'Tue-Sun 10:00-18:00',
          'admission': 'mixed',
          'accessibilityNote': 'Step-free entrance.',
        },
        'bookingUrl': 'https://example.test/book',
      }),
    );
    expect(errors, isEmpty);
    expect(find.byKey(const ValueKey('institution-visit-section')),
        findsOneWidget);
    expect(find.text('Visit'), findsOneWidget);
    expect(find.text('Opening hours'), findsOneWidget);
    expect(find.text('Tue-Sun 10:00-18:00'), findsOneWidget);
    expect(find.text('Free and paid'), findsOneWidget);
    expect(find.text('Step-free entrance.'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('institution-booking-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('institution-visitor-source-link')),
        findsOneWidget);
  });

  testWidgets('no approved visitor information hides the visit section',
      (tester) async {
    final errors = await _pump(tester, institution: _payload());
    expect(errors, isEmpty);
    expect(
        find.byKey(const ValueKey('institution-visit-section')), findsNothing);
    expect(find.text('Opening hours'), findsNothing);
  });

  testWidgets('missing optional fields remove their rows', (tester) async {
    final errors = await _pump(
      tester,
      institution: _payload(
        description: '',
        address: '',
        website: '',
        latitude: 0,
        longitude: 0,
        kind: null,
        type: 'institution',
      ),
    );
    expect(errors, isEmpty);
    expect(find.byKey(_mapKey), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.text('Painting'), findsOneWidget);
  });

  testWidgets('stats appear only when at least one value is non-zero',
      (tester) async {
    var errors = await _pump(tester, institution: _payload());
    expect(errors, isEmpty);
    expect(find.text('Active events'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    errors = await _pump(tester, institution: _payload(activeEvents: 2));
    expect(errors, isEmpty);
    expect(find.text('Active events'), findsOneWidget);
  });

  testWidgets('a long description wraps without overflow', (tester) async {
    final sentence = 'This sentence keeps the reading column honest. ';
    final errors = await _pump(
      tester,
      institution: _payload(description: sentence * 20),
    );
    expect(errors, isEmpty);
    expect(find.textContaining('reading column honest'), findsOneWidget);
  });
}
