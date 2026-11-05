import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService()..setAuthTokenForTesting('synthetic-token');
  });
  tearDown(() => api.setAuthTokenForTesting(null));

  for (final preferredStatus in <int>[200, 400, 404]) {
    for (final withLocation in <bool>[false, true]) {
      test(
          'encoded confirm bodies: preferred $preferredStatus, location $withLocation',
          () async {
        final requests = <http.Request>[];
        api.setHttpClient(MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"attendanceRecorded":true}',
            request.url.path == '/api/attestations/attendance/confirm'
                ? preferredStatus
                : 200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }));
        final location = withLocation
            ? <String, dynamic>{
                'lat': 1.25,
                'lng': 2.5,
                'timestampMs': 123456789,
                'accuracy': 4.0
              }
            : <String, dynamic>{};

        final result = await api.confirmAttendance(
          markerId: ' synthetic-marker ',
          challengeToken: 'synthetic-challenge',
          clientLocation: location,
        );

        expect(result['attendanceRecorded'], isTrue);
        expect(requests.map((request) => request.url.path), <String>[
          '/api/attestations/attendance/confirm',
          if (preferredStatus != 200) '/api/attendance/confirm',
        ]);
        for (final request in requests) {
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          expect(jsonDecode(request.body), <String, dynamic>{
            'markerId': 'synthetic-marker',
            'challengeToken': 'synthetic-challenge',
            if (withLocation) 'clientLocation': location,
          });
        }
      });
    }
  }
}
