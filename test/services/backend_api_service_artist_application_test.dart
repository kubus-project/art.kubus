import 'dart:convert';

import 'package:art_kubus/models/artist_application.dart';
import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwtFor(String userId) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode(<String, Object?>{
        'id': userId,
        'sub': userId,
        'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      })))
      .replaceAll('=', '');
  return 'e30.$payload.';
}

Map<String, dynamic> _applicationJson(String status, {String? notes}) => {
      'id': 'app-1',
      'portfolioUrl': 'https://example.com/work',
      'medium': 'Painting',
      'statement': 'A statement of at least twenty characters.',
      'status': status,
      'reviewerNotes': notes,
      'createdAt': '2026-11-06T10:00:00.000Z',
      'updatedAt': '2026-11-06T10:00:00.000Z',
      'history': <Map<String, dynamic>>[],
    };

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.resetCredentialStoreForTesting(store: AuthCredentialStore(web: true));
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
  });

  test('submitArtistApplication posts with the account token and no wallet',
      () async {
    final token = _jwtFor('account-1');
    api.setAuthTokenForTesting(token);
    http.Request? captured;
    api.setHttpClient(MockClient((request) async {
      captured = request;
      return _json({'success': true, 'data': _applicationJson('pending')}, 201);
    }));

    final application = await api.submitArtistApplication(
      portfolioUrl: ' https://example.com/work ',
      medium: 'Painting',
      statement: 'A statement of at least twenty characters.',
    );

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/api/dao/artist-applications');
    expect(captured!.headers['Authorization'], 'Bearer $token');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body.keys, unorderedEquals(['portfolioUrl', 'medium', 'statement']),
        reason: 'the account contract carries no wallet field');
    expect(body['portfolioUrl'], 'https://example.com/work');
    expect(application.id, 'app-1');
    expect(application.isPending, isTrue);
  });

  test('getMyArtistApplication returns null when the account has not applied',
      () async {
    api.setAuthTokenForTesting(_jwtFor('account-1'));
    api.setHttpClient(MockClient((request) async {
      expect(request.url.path, '/api/dao/artist-applications/mine');
      return _json(
        {'success': false, 'error': 'Artist application not found'},
        404,
      );
    }));

    expect(await api.getMyArtistApplication(), isNull);
  });

  test('getMyArtistApplication parses an approved application with notes',
      () async {
    api.setAuthTokenForTesting(_jwtFor('account-1'));
    api.setHttpClient(MockClient((_) async => _json(
          {
            'success': true,
            'data': _applicationJson('approved', notes: 'Welcome aboard'),
          },
          200,
        )));

    final application = await api.getMyArtistApplication();
    expect(application, isNotNull);
    expect(application!.isApproved, isTrue);
    expect(application.reviewerNotes, 'Welcome aboard');
  });

  test(
      'getMyArtistApplication rethrows a 404 from a backend without the route, '
      'so the UI can show unavailable instead of "no application"', () async {
    api.setAuthTokenForTesting(_jwtFor('account-1'));
    api.setHttpClient(MockClient(
      (_) async =>
          http.Response('Cannot GET /api/dao/artist-applications/mine', 404),
    ));

    await expectLater(
      api.getMyArtistApplication(),
      throwsA(isA<BackendApiRequestException>()
          .having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('submitArtistApplication surfaces a conflict instead of a false success',
      () async {
    api.setAuthTokenForTesting(_jwtFor('account-1'));
    api.setHttpClient(MockClient((_) async => _json(
          {
            'success': false,
            'error': 'An artist application already exists for this account',
          },
          409,
        )));

    await expectLater(
      api.submitArtistApplication(
        portfolioUrl: 'https://example.com/work',
        medium: 'Painting',
        statement: 'A statement of at least twenty characters.',
      ),
      throwsA(isA<BackendApiRequestException>()
          .having((e) => e.statusCode, 'statusCode', 409)),
    );
  });

  test('ArtistApplicationSummary.tryParse treats a body without an id as none',
      () {
    expect(ArtistApplicationSummary.tryParse(<String, dynamic>{}), isNull);
    expect(ArtistApplicationSummary.tryParse('not a map'), isNull);
    final parsed =
        ArtistApplicationSummary.tryParse(_applicationJson('REJECTED'));
    expect(parsed?.isRejected, isTrue, reason: 'status is normalised');
  });
}
