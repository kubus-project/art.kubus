import 'dart:convert';

import 'package:art_kubus/services/browser_session/browser_session_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _base = 'https://api.example.invalid/api/auth/browser-session';

Uri _endpoint(String name) => Uri.parse('$_base/$name');

HttpBrowserSessionApi _api(http.Client client) => HttpBrowserSessionApi(
      client: client,
      endpointUri: _endpoint,
    );

http.Response _json(int status, Map<String, Object?> body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  group('request shape', () {
    test('issue posts the login token as bearer with the CSRF header and JSON',
        () async {
      late http.Request seen;
      final api = _api(MockClient((request) async {
        seen = request;
        return _json(201, {
          'success': true,
          'data': {'token': 'session-bearer', 'user': {}},
        });
      }));

      final result = await api.issue(loginToken: ' login-token ');

      expect(result.isSuccess, isTrue);
      expect(result.payload?['token'], 'session-bearer');
      expect(seen.method, 'POST');
      expect(seen.url, _endpoint('issue'));
      expect(seen.headers['Authorization'], 'Bearer login-token');
      expect(seen.headers['Content-Type'], 'application/json');
      expect(seen.headers[HttpBrowserSessionApi.sessionHeader], '1');
      expect(seen.body, '{}');
      // Origin is set by the browser, never by the app.
      expect(seen.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('origin')));
    });

    test('restore sends no Authorization header (cookie only)', () async {
      late http.Request seen;
      final api = _api(MockClient((request) async {
        seen = request;
        return _json(200, {
          'success': true,
          'data': {'token': 'rotated-bearer'},
        });
      }));

      final result = await api.restore();

      expect(result.isSuccess, isTrue);
      expect(seen.url, _endpoint('restore'));
      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(seen.headers[HttpBrowserSessionApi.sessionHeader], '1');
    });

    test('logout is a credential-free 200 with no session in the body',
        () async {
      final api = _api(MockClient((request) async {
        expect(request.url, _endpoint('logout'));
        return _json(200, {'success': true, 'message': 'Signed out'});
      }));

      final result = await api.logout();

      expect(result.isSuccess, isTrue);
      expect(result.body, containsPair('message', 'Signed out'));
    });
  });

  group('outcomes', () {
    Future<BrowserSessionResult> restoreWith(http.Response response) {
      return _api(MockClient((_) async => response)).restore();
    }

    test('404 is a disabled feature and is not a session', () async {
      final result = await restoreWith(
          _json(404, {'success': false, 'errorCode': 'NOT_FOUND'}));
      expect(result.outcome, BrowserSessionOutcome.disabled);
      expect(result.isSuccess, isFalse);
    });

    test('401 BROWSER_SESSION_INVALID is invalid', () async {
      final result = await restoreWith(_json(401, {
        'success': false,
        'errorCode': 'BROWSER_SESSION_INVALID',
      }));
      expect(result.outcome, BrowserSessionOutcome.invalid);
      expect(result.errorCode, 'BROWSER_SESSION_INVALID');
    });

    test('403 NOT_ELIGIBLE is not eligible; other 403 and 415 are rejected',
        () async {
      expect(
        (await restoreWith(_json(403, {
          'success': false,
          'errorCode': 'BROWSER_SESSION_NOT_ELIGIBLE',
        })))
            .outcome,
        BrowserSessionOutcome.notEligible,
      );
      expect(
        (await restoreWith(_json(403, {
          'success': false,
          'errorCode': 'BROWSER_SESSION_ORIGIN_FORBIDDEN',
        })))
            .outcome,
        BrowserSessionOutcome.rejected,
      );
      expect(
        (await restoreWith(http.Response('', 415))).outcome,
        BrowserSessionOutcome.rejected,
      );
    });

    test('429 is rate limited; 503 fails closed as unavailable', () async {
      expect((await restoreWith(http.Response('', 429))).outcome,
          BrowserSessionOutcome.rateLimited);
      expect((await restoreWith(http.Response('', 503))).outcome,
          BrowserSessionOutcome.unavailable);
    });

    test('a transport failure is unavailable, never a throw', () async {
      final api =
          _api(MockClient((_) async => throw http.ClientException('x')));
      final result = await api.restore();
      expect(result.outcome, BrowserSessionOutcome.unavailable);
    });

    test('a success status without a token is unavailable, not a session',
        () async {
      final result = await restoreWith(_json(200, {
        'success': true,
        'data': {'user': {}},
      }));
      expect(result.outcome, BrowserSessionOutcome.unavailable);
      expect(result.body, isNull);
    });

    test('an unparseable success body is unavailable', () async {
      final result = await restoreWith(http.Response('<html>', 200));
      expect(result.outcome, BrowserSessionOutcome.unavailable);
    });
  });
}
