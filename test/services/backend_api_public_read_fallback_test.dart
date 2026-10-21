import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The public-read failure matrix for a mirror-enabled read (`getArtwork`):
/// which failures may reach the Orbit mirror, the secondary backend and the
/// public snapshot, and what the caller sees when everything is down.
///
/// The defect these cover: when the primary API and its Orbit mirror both
/// answered with an outage status, the error text (`Orbit fallback failed:
/// 502`) was not recognised as an outage, so the secondary backend and the
/// snapshot were skipped and a raw exception reached the page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var sequence = 0;
  late String id;
  final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
  final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

  late List<http.Request> requests;

  setUpAll(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PublicFallbackService().resetForTesting();
    // The public snapshot is unreachable too: no test touches the network.
    PublicFallbackService().bindHttpClient(
      MockClient((_) async => http.Response('down', 503)),
    );
    BackendApiService().setAuthTokenForTesting(null);
    requests = <http.Request>[];
    // The rate-limit window is per path and process-wide: one path per test.
    id = 'artwork-${++sequence}';
  });

  Map<String, Object?> artworkJson() => <String, Object?>{
        'id': id,
        'walletAddress': '0xabc',
        'title': 'Mirror title',
        'artist': 'Artist',
        'description': 'd',
        'latitude': 46.05,
        'longitude': 14.5,
        'rewards': 0,
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

  http.Response ok() => http.Response(
        jsonEncode({
          'success': true,
          'data': {'artwork': artworkJson()},
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );

  bool isOrbit(http.Request r) => r.url.queryParameters['source'] == 'orbit';

  /// [answer] receives (host, isOrbitRequest).
  void backend(
      FutureOr<http.Response> Function(String host, bool orbit) answer) {
    BackendApiService().setHttpClient(
      MockClient((request) async {
        requests.add(request);
        return answer(request.url.host, isOrbit(request));
      }),
    );
  }

  Future<Object?> read() async {
    try {
      return await BackendApiService().getArtwork(id);
    } catch (e) {
      return e;
    }
  }

  List<String> trace() => requests
      .map((r) =>
          '${r.url.host == primaryHost ? 'primary' : r.url.host == standbyHost ? 'standby' : r.url.host}'
          '${isOrbit(r) ? '+orbit' : ''}')
      .toList();

  http.Response status(int code) => http.Response('{"error":"x"}', code);

  group('a healthy primary', () {
    test('answers directly with no mirror request', () async {
      backend((host, orbit) => ok());
      final result = await read();
      expect(result, isNot(isA<Exception>()));
      expect(trace(), ['primary']);
    });
  });

  group('outage statuses reach the mirror, then the secondary backend', () {
    for (final code in <int>[502, 503, 504]) {
      test('$code: the mirror answers', () async {
        backend((host, orbit) => orbit ? ok() : status(code));
        final result = await read();
        expect(result, isNot(isA<Exception>()));
        expect(trace(), ['primary', 'primary+orbit']);
      });

      test(
          '$code on the primary AND its mirror: the secondary backend answers '
          '(was: a raw "Orbit fallback failed" exception)', () async {
        backend((host, orbit) =>
            host == standbyHost && !orbit ? ok() : status(code));
        final result = await read();
        expect(result, isNot(isA<Exception>()),
            reason: 'both primary routes are down; the standby is up');
        expect(trace(), ['primary', 'primary+orbit', 'standby']);
      });
    }

    test('everything down: one bounded pass, then a typed outage error',
        () async {
      backend((host, orbit) => status(503));
      final result = await read();
      expect(result, isA<Exception>());
      expect(result.toString(), contains('Request failed: 503'));
      expect(
          trace(),
          [
            'primary',
            'primary+orbit',
            'standby',
            'standby+orbit',
          ],
          reason: 'no retry loop');
    });

    test('a timeout reaches the mirror', () async {
      backend((host, orbit) {
        if (orbit) return ok();
        throw TimeoutException('slow');
      });
      expect(await read(), isNot(isA<Exception>()));
      expect(trace(), ['primary', 'primary+orbit']);
    });

    test('offline: transport errors move on to the secondary backend',
        () async {
      backend((host, orbit) {
        if (host == standbyHost && !orbit) return ok();
        throw const SocketException('Failed host lookup');
      });
      expect(await read(), isNot(isA<Exception>()));
      expect(trace(), ['primary', 'primary+orbit', 'standby']);
    });

    test('offline everywhere: an exception, never an uncaught error', () async {
      backend((host, orbit) => throw const SocketException('offline'));
      final result = await read();
      expect(result, isA<Exception>());
      expect(requests.length, 4);
    });

    test('a 200 that is not JSON (a gateway page) is an outage, not a crash',
        () async {
      backend((host, orbit) =>
          host == standbyHost && !orbit ? ok() : http.Response('<html>', 200));
      final result = await read();
      expect(result, isNot(isA<FormatException>()));
      expect(result, isNot(isA<Exception>()));
      expect(trace(), ['primary', 'primary+orbit', 'standby']);
    });

    test('an invalid mirror body is reported with the primary failure',
        () async {
      backend((host, orbit) =>
          orbit ? http.Response('not json', 200) : status(502));
      final result = await read();
      expect(result.toString(), contains('Request failed: 502'));
    });
  });

  group('answers are never overruled by the mirror or another backend', () {
    for (final code in <int>[400, 401, 403, 404, 422]) {
      test('$code: no mirror, no secondary backend', () async {
        backend((host, orbit) => status(code));
        final result = await read();
        expect(result.toString(), contains('Request failed: $code'));
        expect(trace(), ['primary']);
      });
    }

    test('429: rate limit surfaces, no mirror, no secondary backend', () async {
      backend((host, orbit) =>
          http.Response('{}', 429, headers: const {'retry-after': '1'}));
      final result = await read();
      expect(result, isA<Exception>());
      expect(trace(), ['primary']);
    });

    test(
        'an authentication failure is surfaced as 401 and never reaches '
        'the mirror', () async {
      final coordinator = _SettlingCoordinator();
      BackendApiService().bindAuthCoordinator(coordinator);
      addTearDown(() => coordinator.resolving = false);
      backend((host, orbit) => ok());
      Object? result;
      try {
        result = await BackendApiService().getArtworks(
          walletAddress: '0xabc$id',
          includePrivateForWallet: true,
        );
      } catch (e) {
        result = e;
      }
      expect(
        result,
        isA<BackendApiRequestException>()
            .having((e) => e.statusCode, 'statusCode', 401),
      );
      expect(trace().where((t) => t.endsWith('+orbit')), isEmpty);
    });

    test(
        '500: the mirror is tried but a plain server error does not '
        'leave the primary API', () async {
      backend((host, orbit) => status(500));
      final result = await read();
      expect(result.toString(), contains('Request failed: 500'));
      expect(trace(), ['primary', 'primary+orbit']);
    });
  });
}

/// An auth layer whose in-flight re-authentication settles as failed.
class _SettlingCoordinator implements AuthSessionCoordinator {
  bool resolving = true;

  @override
  bool get isResolving => resolving;

  @override
  Future<AuthReauthResult> handleAuthFailure(
          AuthFailureContext context) async =>
      const AuthReauthResult(AuthReauthOutcome.failed);

  @override
  Future<AuthReauthResult?> waitForResolution() async =>
      const AuthReauthResult(AuthReauthOutcome.failed, message: 'expired');

  @override
  void reset() {}
}
