import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/institution.dart';
import 'package:art_kubus/models/institution_claim.dart';
import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';
import '../../helpers/secure_storage_absent.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _institutionId = '75af266c-2605-41e9-a508-49529c419116';
const _claimButton = ValueKey('institution-claim-button');
const _noticeTitle = 'Not an official profile';

Map<String, Object?> _payload({
  String? listingOrigin = 'imported',
  String? claimState = 'unclaimed',
  bool isVerified = false,
}) {
  return {
    'id': _institutionId,
    'name': 'Umetnostna galerija Maribor',
    'description': 'A regional museum of contemporary visual art.',
    'type': 'museum',
    'kind': 'museum',
    'address': 'Strossmayerjeva ulica 6, 2000 Maribor, Slovenia',
    'latitude': 46.558688,
    'longitude': 15.6419673,
    'contactEmail': '',
    'website': 'https://www.ugm.si/',
    'disciplines': const <Object>[],
    'stats': {
      'totalVisitors': 0,
      'activeEvents': 0,
      'artworkViews': 0,
      'revenue': 0,
      'visitorGrowth': 0,
      'revenueGrowth': 0,
    },
    'isVerified': isVerified,
    'createdAt': '2026-11-05T17:05:53.222Z',
    if (listingOrigin != null) 'listingOrigin': listingOrigin,
    if (claimState != null) 'claimState': claimState,
  };
}

Map<String, Object?> _claimJson({String status = 'submitted'}) => {
      'id': '11111111-1111-4111-8111-111111111111',
      'institutionId': _institutionId,
      'kind': 'claim',
      'status': status,
      'requestedRole': 'owner',
    };

class _Backend {
  _Backend(
    this.institution, {
    this.myClaims = const [],
    this.postStatus = 201,
    this.claimsStatus,
    this.holdMine,
  });

  final Map<String, Object?> institution;
  final List<Map<String, Object?>> myClaims;
  final int postStatus;

  /// Forces every claims read to this status (503 = feature off, 502 = outage).
  /// Null behaves like the real backend with claims on: 401 anonymous, 200 signed in.
  final int? claimsStatus;

  /// When set, the signed-in claims read waits for this before answering.
  final Completer<void>? holdMine;
  final List<http.Request> posts = [];
  final List<http.Request> anonymousProbes = [];
  final List<http.Request> signedInReads = [];

  http.Client client() => MockClient((request) async {
        final path = request.url.path;
        Object data;
        var status = 200;
        if (request.method == 'POST' && path.endsWith('/claims')) {
          posts.add(request);
          status = postStatus;
          data = postStatus == 201
              ? {
                  'success': true,
                  'data': {
                    'claim': _claimJson(),
                    'verificationToken': 'redacted',
                  },
                }
              : {'success': false, 'error': 'claim_already_open'};
        } else if (path == '/api/institutions/claims/mine') {
          final signedIn = request.headers.containsKey('Authorization');
          if (!signedIn) anonymousProbes.add(request);
          if (signedIn) signedInReads.add(request);
          if (claimsStatus != null) {
            status = claimsStatus!;
            data = {
              'success': false,
              'error': 'Feature temporarily unavailable'
            };
          } else if (!signedIn) {
            status = 401;
            data = {'success': false, 'error': 'unauthorized'};
          } else {
            await holdMine?.future;
            data = {
              'success': true,
              'data': {'claims': myClaims},
            };
          }
        } else if (path == '/api/institutions') {
          data = {
            'success': true,
            'institutions': [institution],
          };
        } else {
          data = {
            'success': true,
            'data': {'events': <Object>[]},
          };
        }
        return http.Response(jsonEncode(data), status,
            headers: const {'content-type': 'application/json'});
      });
}

Future<List<String>> _pump(
  WidgetTester tester,
  _Backend backend, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool embedded = false,
}) async {
  BackendApiService().setHttpClient(backend.client());
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    size: size,
    locale: locale,
    brightness: brightness,
    child: InstitutionDetailScreen(
      institutionId: _institutionId,
      embedded: embedded,
    ),
  );
  FlutterError.onError = prior;
  await tester.pump();
  return errors;
}

void main() {
  installEmptySecureStorage();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  group('Institution model', () {
    test('reads listingOrigin and claimState lower-cased', () {
      final institution = Institution.fromJson(
        _payload(listingOrigin: ' Imported ', claimState: 'UNCLAIMED'),
      );
      expect(institution.listingOrigin, 'imported');
      expect(institution.claimState, 'unclaimed');
      expect(institution.isImportedUnclaimed, isTrue);
      expect(Institution.fromJson(institution.toJson()).isImportedUnclaimed,
          isTrue);
    });

    test('only an imported, unclaimed, unverified listing is claimable', () {
      bool claimable(Map<String, Object?> payload) =>
          Institution.fromJson(payload).isImportedUnclaimed;
      expect(claimable(_payload()), isTrue);
      expect(claimable(_payload(claimState: 'claimed')), isFalse);
      expect(claimable(_payload(claimState: 'disputed')), isFalse);
      expect(claimable(_payload(listingOrigin: 'user_created')), isFalse);
      expect(claimable(_payload(isVerified: true)), isFalse);
      // Payloads that predate the fields never show the notice.
      expect(
          claimable(_payload(listingOrigin: null, claimState: null)), isFalse);
    });

    test('a claim is open until an administrator decides', () {
      InstitutionClaimSummary claim(String status) =>
          InstitutionClaimSummary.tryParse(_claimJson(status: status))!;
      expect(claim('submitted').isOpen, isTrue);
      expect(claim('under_review').isOpen, isTrue);
      expect(claim('approved').isOpen, isFalse);
      expect(claim('rejected').isOpen, isFalse);
      expect(claim('withdrawn').isOpen, isFalse);
      expect(InstitutionClaimSummary.tryParse({'id': 'x'}), isNull);
    });
  });

  group('notice and claim button', () {
    testWidgets('imported unclaimed profile shows the notice and the button',
        (tester) async {
      final errors = await _pump(tester, _Backend(_payload()));
      expect(errors, isEmpty);
      expect(find.text(_noticeTitle), findsOneWidget);
      expect(
          find.textContaining('compiled from public sources'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap, Wikidata'), findsOneWidget);
      expect(find.byKey(_claimButton), findsOneWidget);
      expect(find.text('Claim this profile'), findsOneWidget);
    });

    testWidgets('claimed profile shows neither', (tester) async {
      final errors = await _pump(
        tester,
        _Backend(_payload(claimState: 'claimed')),
      );
      expect(errors, isEmpty);
      expect(find.text(_noticeTitle), findsNothing);
      expect(find.byKey(_claimButton), findsNothing);
    });

    testWidgets('self-created and verified profiles show neither',
        (tester) async {
      for (final payload in [
        _payload(listingOrigin: 'user_created'),
        _payload(isVerified: true),
        _payload(listingOrigin: null, claimState: null),
      ]) {
        final errors = await _pump(tester, _Backend(payload));
        expect(errors, isEmpty);
        expect(find.text(_noticeTitle), findsNothing);
        expect(find.byKey(_claimButton), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('Slovene copy', (tester) async {
      final errors = await _pump(
        tester,
        _Backend(_payload()),
        locale: const Locale('sl'),
      );
      expect(errors, isEmpty);
      expect(find.text('Ni uradni profil'), findsOneWidget);
      expect(find.textContaining('ni uraden'), findsOneWidget);
      expect(find.text('Prevzemi ta profil'), findsOneWidget);
    });

    testWidgets('fits phone and desktop, light and dark, embedded or not',
        (tester) async {
      for (final size in const [Size(390, 844), Size(1440, 900)]) {
        for (final brightness in Brightness.values) {
          for (final embedded in const [false, true]) {
            final errors = await _pump(
              tester,
              _Backend(_payload()),
              size: size,
              brightness: brightness,
              embedded: embedded,
            );
            final label = '$size $brightness embedded=$embedded';
            expect(errors, isEmpty, reason: label);
            expect(find.text(_noticeTitle), findsOneWidget, reason: label);
            expect(find.byKey(_claimButton), findsOneWidget, reason: label);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    });

    testWidgets('button has a semantics label and is a button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Backend(_payload()));
      expect(
        tester.getSemantics(find.byKey(_claimButton)),
        matchesSemantics(
          label: 'Claim this institution profile',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('an open claim of this account replaces the button',
        (tester) async {
      final errors = await _pump(
        tester,
        _Backend(_payload(), myClaims: [_claimJson(status: 'under_review')]),
      );
      await tester.pumpAndSettle();
      expect(errors, isEmpty);
      expect(find.text(_noticeTitle), findsOneWidget);
      expect(find.text('Claim request under review'), findsOneWidget);
      expect(find.byKey(_claimButton), findsNothing);
    });

    testWidgets('a decided claim does not hide the button', (tester) async {
      await _pump(
        tester,
        _Backend(_payload(), myClaims: [_claimJson(status: 'rejected')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Claim request under review'), findsNothing);
      expect(find.byKey(_claimButton), findsOneWidget);
    });
  });

  group('claims availability', () {
    testWidgets('claims switched off: notice stays, no button, says so',
        (tester) async {
      final backend = _Backend(_payload(), claimsStatus: 503);
      final errors = await _pump(tester, backend);
      await tester.pumpAndSettle();
      expect(errors, isEmpty);
      expect(find.text(_noticeTitle), findsOneWidget);
      expect(find.byKey(_claimButton), findsNothing);
      expect(find.text('Claiming is not open yet'), findsOneWidget);
      expect(backend.posts, isEmpty);
    });

    testWidgets('a backend without the feature (404) is treated as off',
        (tester) async {
      await _pump(tester, _Backend(_payload(), claimsStatus: 404));
      await tester.pumpAndSettle();
      expect(find.byKey(_claimButton), findsNothing);
      expect(find.text('Claiming is not open yet'), findsOneWidget);
    });

    testWidgets('an outage is not reported as closed and offers nothing',
        (tester) async {
      await _pump(tester, _Backend(_payload(), claimsStatus: 502));
      await tester.pumpAndSettle();
      expect(find.text(_noticeTitle), findsOneWidget);
      expect(find.byKey(_claimButton), findsNothing);
      expect(find.text('Claiming is not open yet'), findsNothing);
    });

    testWidgets('the probe is anonymous and only imported listings ask',
        (tester) async {
      final imported = _Backend(_payload());
      await _pump(tester, imported);
      await tester.pumpAndSettle();
      expect(imported.anonymousProbes, hasLength(1));
      expect(
          imported.anonymousProbes.single.headers.containsKey('Authorization'),
          isFalse);
      await tester.pumpWidget(const SizedBox.shrink());

      final claimed = _Backend(_payload(claimState: 'claimed'));
      await _pump(tester, claimed);
      await tester.pumpAndSettle();
      expect(claimed.anonymousProbes, isEmpty);
      expect(claimed.signedInReads, isEmpty);
    });

    testWidgets(
        'signed out: button shows once claims are on, no own-claims read',
        (tester) async {
      BackendApiService().setAuthTokenForTesting(null);
      final backend = _Backend(_payload());
      await _pump(tester, backend);
      await tester.pumpAndSettle();
      expect(find.byKey(_claimButton), findsOneWidget);
      expect(backend.signedInReads, isEmpty);
    });

    testWidgets('a claims list that arrives after submitting cannot undo it',
        (tester) async {
      final hold = Completer<void>();
      final backend = _Backend(_payload(), holdMine: hold);
      await _pump(tester, backend);
      await tester.pumpAndSettle();
      // The signed-in read is still waiting; the button is already usable.
      expect(backend.signedInReads, hasLength(1));
      expect(find.byKey(_claimButton), findsOneWidget);

      await tester.tap(find.byKey(_claimButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-message')),
          'I work at the gallery.');
      await tester.tap(find.byKey(const ValueKey('institution-claim-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Claim request under review'), findsOneWidget);

      // The earlier read now answers with an empty list: it predates the request.
      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text('Claim request under review'), findsOneWidget);
      expect(find.byKey(_claimButton), findsNothing);
    });
  });

  group('claim flow', () {
    testWidgets('signed out: asks for an account instead of the form',
        (tester) async {
      BackendApiService().setAuthTokenForTesting(null);
      final backend = _Backend(_payload());
      await _pump(tester, backend);
      await tester.tap(find.byKey(_claimButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('institution-claim-message')),
          findsNothing);
      expect(backend.posts, isEmpty);
    });

    testWidgets('signed in: the form validates, then posts the exact payload',
        (tester) async {
      final backend = _Backend(_payload());
      await _pump(tester, backend);
      await tester.tap(find.byKey(_claimButton));
      await tester.pumpAndSettle();

      // Too short: nothing is sent.
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-message')), 'short');
      await tester.tap(find.byKey(const ValueKey('institution-claim-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Please write at least 10 characters.'), findsOneWidget);
      expect(backend.posts, isEmpty);

      // A link without https is refused.
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-message')),
          'I am the curator of the gallery.');
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-evidence')),
          'http://insecure.example');
      await tester.tap(find.byKey(const ValueKey('institution-claim-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a full web address starting with https://'),
          findsOneWidget);
      expect(backend.posts, isEmpty);

      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-title')), ' Curator ');
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-evidence')),
          'https://www.ugm.si/o-nas');
      await tester.tap(find.byKey(const ValueKey('institution-claim-submit')));
      await tester.pumpAndSettle();

      expect(backend.posts, hasLength(1));
      final request = backend.posts.single;
      expect(request.url.path, '/api/institutions/$_institutionId/claims');
      expect(jsonDecode(request.body), {
        'kind': 'claim',
        'requestedRole': 'owner',
        'claimantTitle': 'Curator',
        'message': 'I am the curator of the gallery.',
        'evidence': [
          {'type': 'document_url', 'value': 'https://www.ugm.si/o-nas'},
        ],
      });

      // The sheet closed, the button gave way to the status notice.
      expect(find.byKey(const ValueKey('institution-claim-message')),
          findsNothing);
      expect(find.text('Claim request under review'), findsOneWidget);
      expect(find.byKey(_claimButton), findsNothing);
      expect(find.text('Claim request sent. An administrator will review it.'),
          findsOneWidget);
    });

    testWidgets('optional fields are left out of the request when blank',
        (tester) async {
      final backend = _Backend(_payload());
      await _pump(tester, backend);
      await tester.tap(find.byKey(_claimButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-message')),
          'I work at the gallery.');
      await tester.tap(find.byKey(const ValueKey('institution-claim-submit')));
      await tester.pumpAndSettle();
      expect(jsonDecode(backend.posts.single.body), {
        'kind': 'claim',
        'requestedRole': 'owner',
        'message': 'I work at the gallery.',
      });
    });

    testWidgets('409 means a request is already open', (tester) async {
      final backend = _Backend(_payload(), postStatus: 409);
      await _pump(tester, backend);
      await tester.tap(find.byKey(_claimButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-message')),
          'I work at the gallery.');
      await tester.tap(find.byKey(const ValueKey('institution-claim-submit')));
      await tester.pumpAndSettle();
      expect(
          find.text('You already have an open claim request for this profile.'),
          findsOneWidget);
      expect(find.text('Claim request under review'), findsOneWidget);
    });

    testWidgets('503 (claims not switched on) keeps the form and says so',
        (tester) async {
      final backend = _Backend(_payload(), postStatus: 503);
      await _pump(tester, backend);
      await tester.tap(find.byKey(_claimButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('institution-claim-message')),
          'I work at the gallery.');
      await tester.tap(find.byKey(const ValueKey('institution-claim-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('institution-claim-error')),
          findsOneWidget);
      expect(
          find.text('Claim requests are not open yet. Please try again later.'),
          findsOneWidget);
      // What the person typed is still there, and the button is still offered.
      expect(find.text('I work at the gallery.'), findsOneWidget);
      expect(find.byKey(const ValueKey('institution-claim-submit')),
          findsOneWidget);
    });
  });
}
