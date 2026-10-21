import 'dart:async';
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

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: _jsonHeaders);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
  final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

  setUpAll(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PublicFallbackService().resetForTesting();
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
  });

  group('mayRepeatOnAnotherBackend', () {
    bool may(String method,
            {bool replaySafe = false, int? status, Object? error}) =>
        BackendApiService.mayRepeatOnAnotherBackend(
          method: method,
          replaySafe: replaySafe,
          statusCode: status,
          error: error,
        );

    test('reads may always be repeated elsewhere', () {
      for (final method in ['GET', 'get', 'HEAD', 'OPTIONS']) {
        expect(may(method, status: 504), isTrue);
        expect(may(method, error: TimeoutException('t')), isTrue);
      }
    });

    test('a write that may already have committed is never repeated', () {
      for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        for (final status in [500, 502, 504, 524]) {
          expect(may(method, status: status), isFalse,
              reason: '$method after $status');
        }
        expect(may(method, error: TimeoutException('t')), isFalse);
        expect(may(method, error: http.ClientException('Connection closed')),
            isFalse);
        expect(
            may(method, error: http.ClientException('XMLHttpRequest error.')),
            isFalse);
        expect(
          may(method,
              error: const BackendApiRequestException(
                  statusCode: 504, path: '/api/x')),
          isFalse,
        );
        expect(may(method), isFalse);
      }
    });

    test('a write moves only when the failure proves it was not applied', () {
      for (final status in [503, 522, 523, 530]) {
        expect(may('POST', status: status), isTrue, reason: '$status');
      }
      expect(
        may('POST',
            error: const BackendApiRequestException(
              statusCode: 503,
              path: '/api/x',
              body: '{"code":"NODE_NOT_WRITABLE"}',
            )),
        isTrue,
      );
      expect(
          may('POST',
              error: http.ClientException(
                  'SocketException: Connection refused (OS Error: Connection refused, errno = 111)')),
          isTrue);
      expect(
          may('POST',
              error:
                  http.ClientException("Failed host lookup: 'api.kubus.site'")),
          isTrue);
    });

    test('authorization and conflict answers never count as availability', () {
      for (final status in [400, 401, 403, 404, 409, 422, 429]) {
        expect(may('POST', status: status), isFalse, reason: '$status');
      }
    });

    test('a replay-safe write may move after any failure', () {
      expect(may('POST', replaySafe: true, status: 504), isTrue);
      expect(
          may('POST', replaySafe: true, error: TimeoutException('t')), isTrue);
    });
  });

  group('writes against two backends', () {
    late List<String> hosts;

    void twoBackends({
      required FutureOr<http.Response> Function(http.Request) primary,
      FutureOr<http.Response> Function(http.Request)? standby,
    }) {
      hosts = <String>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.host == primaryHost) return primary(request);
        if (request.url.host == standbyHost) {
          if (standby != null) return standby(request);
          return _json(<String, Object?>{'success': true, 'data': {}}, 201);
        }
        return http.Response('unexpected host', 500);
      }));
    }

    Future<void> attempt(Future<Object?> Function() write) async {
      try {
        await write();
      } catch (_) {
        // Whether and how the failure is shown is the caller's concern; the
        // assertion is that no second backend received the write.
      }
    }

    final writes = <String, Future<Object?> Function()>{
      'comment': () => BackendApiService()
          .createComment(postId: 'post-1', content: 'once only'),
      'marker': () => BackendApiService().createArtMarker(
            title: 'Marker',
            description: 'd',
            latitude: 46.05,
            longitude: 14.5,
            modelCID: 'QmTestCid',
          ),
    };

    for (final entry in writes.entries) {
      for (final status in [500, 502, 504]) {
        test('a ${entry.key} the primary answers $status for is not resent',
            () async {
          twoBackends(primary: (_) => _json(<String, Object?>{}, status));
          await attempt(entry.value);
          expect(hosts, <String>[primaryHost]);
        });
      }

      test('a ${entry.key} whose connection drops is not resent', () async {
        twoBackends(
            primary: (_) => throw http.ClientException('Connection closed'));
        await attempt(entry.value);
        expect(hosts, <String>[primaryHost]);
      });

      test('a ${entry.key} whose primary times out is not resent', () async {
        twoBackends(primary: (_) => throw TimeoutException('no answer'));
        await attempt(entry.value);
        expect(hosts, <String>[primaryHost]);
      });

      test('a ${entry.key} the primary refuses as unavailable (503) moves once',
          () async {
        twoBackends(primary: (_) => _json(<String, Object?>{}, 503));
        await attempt(entry.value);
        expect(hosts, <String>[primaryHost, standbyHost]);
      });

      for (final status in [401, 403, 409]) {
        test('a ${entry.key} answered $status never reaches the standby',
            () async {
          twoBackends(
              primary: (_) => _json(
                  <String, Object?>{'success': false, 'error': 'no'}, status));
          await attempt(entry.value);
          expect(hosts.where((h) => h == standbyHost), isEmpty);
        });
      }
    }

    test('a message attachment upload is not resent after a primary 504',
        () async {
      twoBackends(primary: (_) => _json(<String, Object?>{}, 504));
      await attempt(() => BackendApiService().uploadMessageAttachment(
            'conversation-1',
            <int>[1, 2, 3, 4],
            'image.png',
            'image/png',
          ));
      expect(hosts, <String>[primaryHost]);
    });

    test('an email login (replay-safe) moves to the standby after a 504',
        () async {
      BackendApiService().setAuthTokenForTesting(null);
      twoBackends(
        primary: (_) => _json(<String, Object?>{'success': false}, 504),
        standby: (_) => _json(<String, Object?>{
          'success': true,
          'data': <String, Object?>{
            'token': 'standby-token',
            'user': <String, Object?>{
              'id': 'user-1',
              'email': 'person@example.com'
            },
          },
        }, 200),
      );
      final result = await BackendApiService()
          .loginWithEmail(email: 'person@example.com', password: 'Password123');
      expect(result['success'], isTrue);
      expect(hosts, <String>[primaryHost, standbyHost]);
    });

    test('a wallet login (replay-safe) moves to the standby after a 504',
        () async {
      BackendApiService().setAuthTokenForTesting(null);
      twoBackends(
        primary: (_) => _json(<String, Object?>{'success': false}, 504),
        standby: (_) => _json(<String, Object?>{
          'success': true,
          'data': <String, Object?>{'token': 'standby-token'},
        }, 200),
      );
      await attempt(() => BackendApiService().loginWithWallet(
            walletAddress: 'WalletTest111111111111111111111111111111111',
            signature: 'sig',
            message: 'msg',
          ));
      expect(hosts, <String>[primaryHost, standbyHost]);
    });

    test('reads still move to the standby after a primary 504', () async {
      twoBackends(primary: (_) => _json(<String, Object?>{}, 504));
      await attempt(() => BackendApiService().getArtwork('artwork-1'));
      expect(hosts, contains(standbyHost));
    });
  });
}
