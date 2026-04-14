import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _jsonHeaders = <String, String>{'content-type': 'application/json'};
const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PublicFallbackService().resetForTesting();
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
  });

  test('loginWithEmail fails over to standby when primary is transiently down',
      () async {
    final api = BackendApiService();
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        requestHosts.add(request.url.host);
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/login/email');

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'primary unavailable',
            }),
            503,
            headers: _jsonHeaders,
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'token': 'standby-token',
                'user': <String, Object?>{
                  'id': 'user-1',
                  'email': 'person@example.com',
                },
              },
            }),
            200,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final result = await api.loginWithEmail(
      email: 'person@example.com',
      password: 'Password123',
    );

    expect(result['success'], isTrue);
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason: 'Expected auth request to retry on standby after primary 503.',
    );
  });

  test(
      'getEmailVerificationStatus retries on standby after primary network error',
      () async {
    final api = BackendApiService();
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        requestHosts.add(request.url.host);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/auth/email-status');

        if (request.url.host == primaryHost) {
          throw Exception('primary offline');
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{'verified': true},
            }),
            200,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final status = await api.getEmailVerificationStatus(
      email: 'person@example.com',
    );

    expect(status['verified'], isTrue);
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason: 'Expected standby retry after primary network exception.',
    );
  });

  test('getAccountSecurityStatus fails over with authenticated request',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(_validAuthToken);

    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        requestHosts.add(request.url.host);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/auth/account-security-status');
        expect(request.headers['Authorization'], 'Bearer $_validAuthToken');

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'service unavailable',
            }),
            503,
            headers: _jsonHeaders,
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'hasEmail': true,
                'hasPassword': true,
                'email': 'person@example.com',
                'emailVerified': true,
                'emailAuthEnabled': true,
              },
            }),
            200,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final status = await api.getAccountSecurityStatus();

    expect(status['hasEmail'], isTrue);
    expect(status['email'], 'person@example.com');
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason:
          'Expected authenticated auth-read to retry on standby after primary 503.',
    );
  });

  test('fetchConversations retries on standby when primary is unavailable',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(_validAuthToken);

    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/messages') {
          return http.Response('unexpected path', 500);
        }
        requestHosts.add(request.url.host);

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'primary unavailable',
            }),
            503,
            headers: _jsonHeaders,
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <Object?>[],
            }),
            200,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final result = await api.fetchConversations();

    expect(result['success'], isTrue);
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason:
          'Expected messages read path to retry on standby after primary 503.',
    );
  });

  test('issueDebugTokenForWallet retries on standby when primary returns 503',
      () async {
    final api = BackendApiService();
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/profiles/issue-token') {
          return http.Response('unexpected path', 500);
        }
        requestHosts.add(request.url.host);

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'primary unavailable',
            }),
            503,
            headers: _jsonHeaders,
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'token': 'standby-issued-token',
            }),
            201,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final success = await api.issueDebugTokenForWallet(
      'WalletTest111111111111111111111111111111111',
    );

    expect(success, isTrue);
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason:
          'Expected issue-token write path to retry on standby after primary 503.',
    );
  });

  test('getTrendingCommunityTags retries on standby after primary 503',
      () async {
    final api = BackendApiService();
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/community/tags/trending') {
          return http.Response('unexpected path', 500);
        }
        requestHosts.add(request.url.host);

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'primary unavailable',
            }),
            503,
            headers: _jsonHeaders,
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <Map<String, Object?>>[
                <String, Object?>{'tag': 'art', 'count': 7},
              ],
            }),
            200,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final tags = await api.getTrendingCommunityTags(limit: 8, timeframeDays: 7);

    expect(tags, hasLength(1));
    expect(tags.first['tag'], 'art');
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason:
          'Expected _fetchJson read path to retry on standby after primary 503.',
    );
  });

  test('uploadMessageAttachment retries on standby when primary returns 503',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(_validAuthToken);

    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/messages/conversation-1/messages') {
          return http.Response('unexpected path', 500);
        }
        requestHosts.add(request.url.host);

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'primary unavailable',
            }),
            503,
            headers: _jsonHeaders,
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{'id': 'msg-1'},
            }),
            201,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final result = await api.uploadMessageAttachment(
      'conversation-1',
      <int>[1, 2, 3, 4],
      'image.png',
      'image/png',
    );

    expect(result['success'], isTrue);
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason:
          'Expected multipart message upload to retry on standby after primary 503.',
    );
  });

  test('uploadArMarker retries on standby when primary returns 503', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(_validAuthToken);

    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/ar/artwork-1/marker/upload') {
          return http.Response('unexpected path', 500);
        }
        requestHosts.add(request.url.host);

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'primary unavailable',
            }),
            503,
            headers: _jsonHeaders,
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{'markerUrl': '/uploads/marker.png'},
            }),
            200,
            headers: _jsonHeaders,
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final result = await api.uploadArMarker(
      artworkId: 'artwork-1',
      walletAddress: 'WalletTest111111111111111111111111111111111',
      fileBytes: <int>[1, 2, 3],
      fileName: 'marker.png',
    );

    expect(result, isNotNull);
    expect(
      requestHosts,
      <String>[primaryHost, standbyHost],
      reason:
          'Expected manual AR marker upload path to retry on standby after primary 503.',
    );
  });
}
