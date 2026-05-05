import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/telemetry/kubus_client_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

String? _headerValue(http.Request request, String name) {
  final normalized = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
    KubusClientContext.instance.setEnabled(true);
    KubusClientContext.instance.update(
      sessionId: 'session-1',
      screenName: 'Community',
      screenRoute: '/community',
      flowStage: 'submit',
    );
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
    KubusClientContext.instance.setEnabled(false);
  });

  test('JSON POST retries once to preferred write base and preserves request',
      () async {
    final requestHosts = <String>[];
    final requestBodies = <Map<String, dynamic>>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        requestHosts.add(request.url.host);
        expect(request.method, 'POST');
        expect(request.url.path, '/api/community/posts');
        expect(
          _headerValue(request, 'Authorization'),
          'Bearer $_validAuthToken',
        );
        expect(
          _headerValue(request, 'Content-Type'),
          contains('application/json'),
        );
        expect(_headerValue(request, 'x-kubus-session-id'), 'session-1');
        expect(_headerValue(request, 'x-kubus-screen-name'), 'Community');
        expect(_headerValue(request, 'x-kubus-screen-route'), '/community');
        expect(_headerValue(request, 'x-kubus-flow-stage'), 'submit');
        requestBodies.add(
          jsonDecode(request.body) as Map<String, dynamic>,
        );

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'Node is not writable',
              'code': 'NODE_NOT_WRITABLE',
              'databaseRole': 'standby',
              'preferredWriteBaseUrl': AppConfig.standbyApiUrl,
              'switchRecommended': true,
            }),
            503,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'id': 'post-1',
                'content': 'hello kubus',
                'authorId': 'WalletTest111111111111111111111111111111111',
                'walletAddress':
                    'WalletTest111111111111111111111111111111111',
                'author': <String, Object?>{
                  'walletAddress':
                      'WalletTest111111111111111111111111111111111',
                  'username': 'tester',
                  'displayName': 'Tester',
                },
                'createdAt': '2026-05-05T10:00:00.000Z',
                'tags': <String>[],
                'likes': 0,
                'comments': 0,
                'shares': 0,
              },
            }),
            201,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final post = await BackendApiService().createCommunityPost(
      content: 'hello kubus',
      tags: const <String>['art'],
    );

    expect(post.id, 'post-1');
    expect(requestHosts, <String>[primaryHost, standbyHost]);
    expect(requestBodies, hasLength(2));
    expect(requestBodies.first, requestBodies.last);
    expect(requestBodies.first['content'], 'hello kubus');
  });

  test('JSON POST same-origin preferred write base fails fast', () async {
    var attempts = 0;
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        attempts++;
        expect(request.url.host, primaryHost);
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Node is not writable',
            'code': 'NODE_NOT_WRITABLE',
            'databaseRole': 'standby',
            'preferredWriteBaseUrl': AppConfig.baseApiUrl,
            'switchRecommended': true,
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await expectLater(
      BackendApiService().createCommunityPost(content: 'hello kubus'),
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.body,
              'body',
              contains('same backend'),
            ),
      ),
    );
    expect(attempts, 1);
  });

  test('JSON POST missing preferred write base fails fast', () async {
    var attempts = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Node is not writable',
            'code': 'NODE_NOT_WRITABLE',
            'databaseRole': 'standby',
            'switchRecommended': true,
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await expectLater(
      BackendApiService().createCommunityPost(content: 'hello kubus'),
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.body,
              'body',
              contains('did not provide a preferred write base URL'),
            ),
      ),
    );
    expect(attempts, 1);
  });

  test('JSON POST invalid preferred write base fails fast', () async {
    var attempts = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Node is not writable',
            'code': 'NODE_NOT_WRITABLE',
            'databaseRole': 'standby',
            'preferredWriteBaseUrl': 'not a url',
            'switchRecommended': true,
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await expectLater(
      BackendApiService().createCommunityPost(content: 'hello kubus'),
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.body,
              'body',
              contains('did not provide a preferred write base URL'),
            ),
      ),
    );
    expect(attempts, 1);
  });
}
