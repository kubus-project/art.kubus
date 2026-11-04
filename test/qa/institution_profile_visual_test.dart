import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/profile_image_http_fixture.dart';
import '../support/qa_font_loader.dart';

/// Visual QA for the institution detail screen.
///
/// Two tests:
/// - a synthetic profile that always runs (CI), and
/// - a real researched profile read at runtime from the institution research
///   workspace. It is skipped when that workspace is absent, so CI never needs
///   it. Its text and images are read at runtime and never copied into the
///   repository.
///
/// Environment:
/// - KUBUS_INSTITUTION_VISUAL_QA: directory for PNG captures (no capture if unset).
/// - KUBUS_DBOPS_ROOT: root of the research workspace (default G:/kubus-dbops).
const _testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _avatarKey = ValueKey('institution-profile-image');
const _mapKey = ValueKey('institution-open-on-map');
const _visitKey = ValueKey('institution-visit-section');

const _scenes = <({String name, Size size})>[
  (name: 'phone-390x844', size: Size(390, 844)),
  (name: 'tablet-834x1194', size: Size(834, 1194)),
  (name: 'desktop-1440x900', size: Size(1440, 900)),
];

/// Controlled discipline vocabulary (migration 117), keyed by English label.
const _disciplineLabelsSl = <String, String>{
  'contemporary art': 'Sodobna umetnost',
  'modern art': 'Moderna umetnost',
  'painting': 'Slikarstvo',
  'sculpture': 'Kiparstvo',
  'photography': 'Fotografija',
  'media art': 'Medijska umetnost',
  'digital art': 'Digitalna umetnost',
  'installation': 'Instalacija',
  'performance art': 'Performans',
  'design': 'Oblikovanje',
  'architecture': 'Arhitektura',
  'applied arts': 'Uporabna umetnost',
  'historical art': 'Zgodovinska umetnost',
  'archaeology': 'Arheologija',
  'cultural heritage': 'Kulturna dediščina',
  'natural history': 'Naravoslovje',
  'science and technology': 'Znanost in tehnologija',
};

final RegExp _notAName = RegExp(
    r"\b(not identified|unknown|unidentified|anonym\w*|neznan\w*)\b",
    caseSensitive: false);
final RegExp _lifeDates =
    RegExp(r"\s*\(\s*(?:c\.\s*)?\d{3,4}\s*[-–]\s*\d{0,4}\s*\)\s*$");

final String _dbopsRoot =
    Platform.environment['KUBUS_DBOPS_ROOT'] ?? 'G:/kubus-dbops';

File _dbopsFile(String relative) => File('$_dbopsRoot/$relative');

/// A real researched profile and the two images it references.
class _RealFixture {
  _RealFixture(this.profile, this.coverBytes, this.logoBytes);

  final Map<String, Object?> profile;
  final Uint8List coverBytes;
  final Uint8List logoBytes;

  Map<String, Object?> get _media => profile['media']! as Map<String, Object?>;
  Map<String, Object?> get coverMedia =>
      _media['cover']! as Map<String, Object?>;
  Map<String, Object?> get logoMedia =>
      _media['profile']! as Map<String, Object?>;

  String get name => profile['name']! as String;
  String get address => profile['address']! as String;
  String get website => profile['website']! as String;
  String get kind => profile['kind']! as String;

  String get description => (profile['descriptionClaims']! as List<Object?>)
      .map((claim) => (claim! as Map<String, Object?>)['text']! as String)
      .join(' ');

  List<String> get disciplines =>
      (profile['disciplines']! as List<Object?>).cast<String>();
}

_RealFixture? _loadRealFixture() {
  final file = _dbopsFile(
    // The assembled research profile (research + media records), not editorially approved.
    'data/institutions/orchestration-20261104/e2e/final/profiles/narodna-galerija.profile.json',
  );
  if (!file.existsSync()) return null;
  final profile = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final media = profile['media'] as Map<String, Object?>?;
  final coverPath = (media?['cover'] as Map<String, Object?>?)?['localFile'];
  final logoPath = (media?['profile'] as Map<String, Object?>?)?['localFile'];
  if (coverPath is! String || logoPath is! String) return null;
  final cover = _dbopsFile(coverPath);
  final logo = _dbopsFile(logoPath);
  if (!cover.existsSync() || !logo.existsSync()) return null;
  return _RealFixture(profile, cover.readAsBytesSync(), logo.readAsBytesSync());
}

final _RealFixture? _real = _loadRealFixture();

/// A candidate preview: the payload shape the backend serves for an approved
/// institution, filled from a real research profile that is NOT approved. It
/// previews layout with real text and images; it is not API output.
Map<String, Object?> _apiPayloadFromRealProfile(_RealFixture real) {
  Map<String, Object?> attribution(Map<String, Object?> media) => {
        'credit': media['credit'],
        'author': media['author'],
        'depictedWorks': [
          for (final w in ((((media['rights'] as Map?)?['underlyingWork']
                      as Map?)?['works'] as List?) ??
                  const [])
              .whereType<Map>()
              // Mirrors the backend: placeholders for unidentified creators
              // are not names, and life dates are not part of the name.
              .where((w) =>
                  w['author'] is String &&
                  !_notAName.hasMatch(w['author'] as String)))
            {
              'type': w['type'],
              'author':
                  (w['author'] as String).replaceAll(_lifeDates, '').trim()
            },
        ],
        'sourceUrl': media['sourceUrl'],
        'licenseUrl': media['licenseUrl'],
      };
  final visitor = real.profile['visitorAccess'] as Map<String, Object?>?;
  return {
    'id': 'inst-visual',
    'name': real.name,
    'description': real.description,
    'kind': real.kind,
    // The backend's legacy type guess: museum stays museum.
    'type': real.kind == 'museum' ? 'museum' : 'institution',
    'address': real.address,
    'latitude': (real.profile['latitude']! as num).toDouble(),
    'longitude': (real.profile['longitude']! as num).toDouble(),
    'contactEmail': '',
    'website': real.website,
    'disciplines': [
      for (final label in real.disciplines)
        {
          'code': label.replaceAll(' ', '_'),
          'labelEn': label[0].toUpperCase() + label.substring(1),
          'labelSl': _disciplineLabelsSl[label] ?? '',
        },
    ],
    'coverImageUrl': 'https://profile-fixture.invalid/real-cover.jpg',
    'logoUrl': 'https://profile-fixture.invalid/real-profile.jpg',
    'coverAttribution': attribution(real.coverMedia),
    'logoAttribution': attribution(real.logoMedia),
    if (visitor != null)
      'visitorAccess': {
        'status': 'approved',
        'sourceUrl': (real.profile['evidence']!
                as Map<String, Object?>)['visitorAccess'] is Map
            ? ((real.profile['evidence']!
                    as Map<String, Object?>)['visitorAccess']!
                as Map<String, Object?>)['url']
            : null,
        'verifiedAt': '2026-11-04T00:00:00.000Z',
        'visitorInfo': {
          for (final key in const [
            'classification',
            'openingHoursText',
            'admission',
            'accessibilityNote'
          ])
            if (visitor[key] is String) key: visitor[key],
        },
        'bookingUrl': visitor['bookingUrl'],
      },
    'stats': {
      'totalVisitors': 0,
      'activeEvents': 0,
      'artworkViews': 0,
      'revenue': 0,
      'visitorGrowth': 0,
      'revenueGrowth': 0,
    },
    'isVerified': false,
    'createdAt': '2026-11-03T15:00:00.000Z',
  };
}

/// Serves exact image bytes for fixed paths. Unknown paths answer 404.
class _BytesHttpClient implements HttpClient {
  _BytesHttpClient(this._images);

  final Map<String, Uint8List> _images;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final bytes = _images[url.path];
    return _BytesRequest(bytes ?? Uint8List(0), bytes == null ? 404 : 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BytesRequest implements HttpClientRequest {
  _BytesRequest(this._bytes, this._status);

  final Uint8List _bytes;
  final int _status;

  @override
  HttpHeaders get headers => _NoHeaders();

  @override
  Future<HttpClientResponse> close() async => _BytesResponse(_bytes, _status);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BytesResponse extends Stream<List<int>> implements HttpClientResponse {
  _BytesResponse(this._bytes, this._status);

  final Uint8List _bytes;
  final int _status;

  @override
  int get statusCode => _status;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _serveInstitution(Map<String, Object?> payload) {
  BackendApiService().setHttpClient(MockClient((request) async {
    final data = request.url.path == '/api/institutions'
        ? {
            'success': true,
            'institutions': [payload],
          }
        : {
            'success': true,
            'data': {'events': <Object>[]},
          };
    return http.Response(jsonEncode(data), 200,
        headers: const {'content-type': 'application/json'});
  }));
}

/// Renders one scene. Render errors are returned, not swallowed, so the test
/// can assert on them after the global error handler is restored.
Future<List<String>> _renderScene(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final originalOnError = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    size: size,
    brightness: brightness,
    child: const InstitutionDetailScreen(institutionId: 'inst-visual'),
  );
  FlutterError.onError = originalOnError;
  await tester.pump();
  for (final element in find.byType(Image).evaluate()) {
    final widget = element.widget as Image;
    await tester.runAsync(() => precacheImage(widget.image, element));
  }
  await tester.pump();
  return errors;
}

Future<void> _capture(WidgetTester tester, String path) async {
  final bytes = await tester.runAsync(() async {
    final root = tester.binding.rootElement!.renderObject!;
    final layer = root.debugLayer! as OffsetLayer;
    final image = await layer.toImage(root.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  File(path).writeAsBytesSync(bytes!);
}

Map<String, Object?> _syntheticPayload() => {
      'id': 'inst-visual',
      'name': 'Synthetic Museum of Cultural Heritage',
      'description':
          'This synthetic institution profile is used to inspect the layout of a long description. It presents a collection of cultural heritage and visual art through exhibitions, research and public programmes. Visitors can explore the permanent collection and changing displays, and the profile contains separate cover and institutional imagery for this layout check.',
      'kind': 'museum',
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
        'licenseUrl': 'https://creativecommons.org/licenses/by-sa/4.0/',
      },
      'logoAttribution': {
        'credit': 'Synthetic institution archive',
        'sourceUrl': 'https://example.test/logo',
        'licenseUrl': 'https://creativecommons.org/licenses/by/2.0/',
      },
      'disciplines': [
        {'code': 'painting', 'labelEn': 'Painting', 'labelSl': 'Slikarstvo'},
        {
          'code': 'cultural_heritage',
          'labelEn': 'Cultural heritage',
          'labelSl': 'Kulturna dediščina'
        }
      ],
      'visitorAccess': {
        'status': 'approved',
        'sourceUrl': 'https://example.test/visit',
        'verifiedAt': '2026-11-02T12:00:00.000Z',
        'visitorInfo': {
          'openingHoursText': 'Tue-Sun 10:00-18:00',
          'admission': 'mixed',
          'accessibilityNote': 'Step-free access to the main floor.',
        },
        'bookingUrl': 'https://example.test/book',
      },
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final output = Platform.environment['KUBUS_INSTITUTION_VISUAL_QA'];
  final captureDir = output == null || output.isEmpty ? null : output;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_testToken);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets('institution identity remains visible without approved images',
      (tester) async {
    final payload = _syntheticPayload()
      ..remove('coverImageUrl')
      ..remove('logoUrl')
      ..remove('coverAttribution')
      ..remove('logoAttribution');
    _serveInstitution(payload);
    expect(
        await _renderScene(tester,
            size: const Size(390, 844), brightness: Brightness.light),
        isEmpty);
    expect(
        find.text('Synthetic Museum of Cultural Heritage'), findsNWidgets(2));
    expect(find.byKey(_avatarKey), findsOneWidget);
    expect(find.byType(ProfileIdentityHero), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-identity-hero-cover')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('institution-image-credits')), findsNothing);
  });

  testWidgets('synthetic institution profile renders approved sections (CI)',
      (tester) async {
    await tester.runAsync(QaFontLoader.ensureLoaded);
    _serveInstitution(_syntheticPayload());
    final fixture = ProfileImageHttpFixture();
    await tester.runAsync(fixture.prepare);
    final previous = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => fixture.createHttpClient(null);
    try {
      final errors = await _renderScene(
        tester,
        size: const Size(390, 844),
        brightness: Brightness.light,
      );
      expect(errors, isEmpty);
      expect(find.text('Museum'), findsOneWidget);
      expect(find.text('Painting'), findsOneWidget);
      expect(find.text('Cover photo: Synthetic cover photographer'),
          findsOneWidget);
      expect(find.text('CC BY-SA 4.0'), findsOneWidget);
      expect(find.text('CC BY 2.0'), findsOneWidget);
      expect(find.byKey(_avatarKey), findsOneWidget);
      expect(find.byKey(_mapKey), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      // The visit section follows the header card in a lazy list: scroll it into view first.
      await tester.scrollUntilVisible(find.byKey(_visitKey), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.byKey(_visitKey), findsOneWidget);
      expect(find.text('Free and paid'), findsOneWidget);

      if (captureDir != null) {
        Directory(captureDir).createSync(recursive: true);
        await _capture(tester, '$captureDir/synthetic-phone-light.png');
      }
    } finally {
      debugNetworkImageHttpClientProvider = previous;
    }
  });

  testWidgets(
      'the cover credit button is a 44 dp target that scrolls to the credits, and is absent without a credit',
      (tester) async {
    await tester.runAsync(QaFontLoader.ensureLoaded);
    final fixture = ProfileImageHttpFixture();
    await tester.runAsync(fixture.prepare);
    final previous = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => fixture.createHttpClient(null);
    const button = ValueKey('institution-cover-credit-button');
    const credits = ValueKey('institution-image-credits');
    try {
      _serveInstitution(_syntheticPayload());
      expect(
          await _renderScene(tester,
              size: const Size(390, 560), brightness: Brightness.light),
          isEmpty);
      expect(find.byKey(button), findsOneWidget);
      final target = tester.getSize(find.byKey(button));
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));
      expect(find.byTooltip('Photo credits'), findsWidgets);
      final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
          tester.getRect(find.byKey(credits)).top, greaterThan(viewport.height),
          reason: 'on a phone the credits start below the first screen');
      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byKey(credits));
      expect(after.top, lessThan(viewport.height));
      expect(after.top, greaterThanOrEqualTo(0));

      final noCredit = _syntheticPayload()..remove('coverAttribution');
      _serveInstitution(noCredit);
      expect(
          await _renderScene(tester,
              size: const Size(390, 560), brightness: Brightness.light),
          isEmpty);
      expect(find.byKey(button), findsNothing);
    } finally {
      debugNetworkImageHttpClientProvider = previous;
    }
  });

  testWidgets(
      'real researched profile renders at phone, tablet and desktop, light and dark',
      (tester) async {
    final real = _real!;
    await tester.runAsync(QaFontLoader.ensureLoaded);
    _serveInstitution(_apiPayloadFromRealProfile(real));
    final previous = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => _BytesHttpClient({
          '/real-cover.jpg': real.coverBytes,
          '/real-profile.jpg': real.logoBytes,
        });
    try {
      if (captureDir != null) {
        Directory(captureDir).createSync(recursive: true);
      }
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final scene in _scenes) {
          final label = '${scene.name}-${brightness.name}';
          final errors = await _renderScene(
            tester,
            size: scene.size,
            brightness: brightness,
          );
          expect(errors, isEmpty, reason: label);

          // Navigation and the profile identity each show the institution name.
          expect(find.text(real.name), findsNWidgets(2), reason: label);
          expect(find.text('Museum'), findsOneWidget, reason: label);
          for (final discipline in const [
            'Historical art',
            'Painting',
            'Sculpture',
            'Modern art',
          ]) {
            expect(find.text(discipline), findsOneWidget, reason: label);
          }
          expect(find.text(real.address), findsOneWidget, reason: label);
          expect(find.text(real.description), findsOneWidget, reason: label);
          expect(
            find.text('Cover photo: ${real.coverMedia['author']}'),
            findsOneWidget,
            reason: label,
          );
          expect(
            find.text('Profile photo: ${real.logoMedia['author']}'),
            findsOneWidget,
            reason: label,
          );
          // Licence labels come from the profile's own media records.
          for (final media in [real.coverMedia, real.logoMedia]) {
            expect(find.text(media['license']! as String), findsWidgets,
                reason: label);
          }
          expect(find.byKey(_avatarKey), findsOneWidget, reason: label);
          expect(find.byKey(_mapKey), findsOneWidget, reason: label);
          expect(find.byIcon(Icons.image_outlined), findsNothing,
              reason: label);

          if (captureDir != null) {
            await _capture(tester, '$captureDir/real-$label.png');
          }
        }
      }
    } finally {
      debugNetworkImageHttpClientProvider = previous;
    }
  }, skip: _real == null);
}
