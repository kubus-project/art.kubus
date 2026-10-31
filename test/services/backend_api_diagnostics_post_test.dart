import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiJkaWFnbm9zdGljcy10ZXN0Iiwicm9sZSI6InVzZXIifQ.'
    'c2lnbmF0dXJl';

const _diagnosticsPath = '/api/diagnostics/error';

String _diagnosticsBody() => jsonEncode(<String, Object?>{
      'eventId': 'diagnostics-test',
      'message': 'test',
      'metadata': <String, Object?>{'path': '/api/profiles/x'},
    });

Future<void> _settle() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = false;
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('diagnostics POST never carries an Authorization header', () async {
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
    final seen = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      seen.add(request);
      return http.Response('{"success":true}', 202);
    }));

    await BackendApiService().postClientDiagnostics(_diagnosticsBody());

    final diagnostics =
        seen.where((r) => r.url.path == _diagnosticsPath).toList();
    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.headers.containsKey('Authorization'), isFalse);
    expect(diagnostics.single.headers.containsKey('authorization'), isFalse);
  });

  test('diagnostics POST makes a single attempt on failure', () async {
    var diagnosticsAttempts = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == _diagnosticsPath) {
        diagnosticsAttempts += 1;
        return http.Response('unavailable', 503);
      }
      return http.Response('unexpected', 500);
    }));

    final response =
        await BackendApiService().postClientDiagnostics(_diagnosticsBody());

    expect(response?.statusCode, 503);
    expect(diagnosticsAttempts, 1);
  });

  test('repeat failures on different profile ids produce one diagnostics post',
      () async {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = false;
    const firstId = '6f1c2a3e-1111-4b2c-9d3e-aaaaaaaaaaa1';
    const secondId = '6f1c2a3e-2222-4b2c-9d3e-aaaaaaaaaaa2';
    final diagnosticsBodies = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == _diagnosticsPath) {
        diagnosticsBodies.add(request.body);
        return http.Response('{"success":true}', 202);
      }
      return http.Response('SYNTHETIC_PRIVATE_RESPONSE_BODY_SENTINEL', 500);
    }));

    await expectLater(
      BackendApiService().getProfileByWallet(firstId),
      throwsA(isA<Object>()),
    );
    await expectLater(
      BackendApiService().getProfileByWallet(secondId),
      throwsA(isA<Object>()),
    );
    await _settle();

    expect(diagnosticsBodies, hasLength(1));
    final payload =
        jsonDecode(diagnosticsBodies.single) as Map<String, dynamic>;
    final metadata = payload['metadata'] as Map<String, dynamic>;
    expect(metadata.containsKey('response_preview'), isFalse);
    expect(diagnosticsBodies.single,
        isNot(contains('SYNTHETIC_PRIVATE_RESPONSE_BODY_SENTINEL')));
    expect(metadata['status_code'], 500);
    expect(metadata['path'], '/api/profiles/$firstId');
    expect(metadata['path'].toString().contains('?'), isFalse);
  });
}
